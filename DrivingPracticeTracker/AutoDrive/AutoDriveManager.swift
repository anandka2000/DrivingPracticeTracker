import Foundation
import Combine
import CoreMotion
import CoreLocation
import AVFoundation
import Speech

/// Detects automotive motion, announces via TTS, listens for a voice yes/no,
/// then records the drive and presents it for confirmation when the drive ends.
@MainActor
class AutoDriveManager: NSObject, ObservableObject {
    static let shared = AutoDriveManager()

    // MARK: - Published state
    @Published var isDriving = false
    @Published var isDrivingConfirmed = false   // user said yes → persistent green pill
    @Published var showStartBanner = false
    @Published var showEndPrompt = false
    @Published var pendingSession: DetectedSession?
    @Published var isListeningForVoiceResponse = false

    struct DetectedSession {
        var date: Date
        var durationMinutes: Int
        var conditions: [DrivingCondition]
        /// true = user explicitly said yes; false = auto-detected end without prior confirmation
        var wasUserConfirmed: Bool
    }

    // MARK: - Private — motion & location
    private let activityManager = CMMotionActivityManager()
    private let locationManager = CLLocationManager()
    private var driveStartTime: Date?
    private var maxSpeedMph: Double = 0
    private var stopDebounceTask: Task<Void, Never>?

    // MARK: - Private — TTS
    private let synthesizer = AVSpeechSynthesizer()

    // MARK: - Private — voice response
    private var voiceRecognizer: SFSpeechRecognizer?
    private var voiceRequest: SFSpeechAudioBufferRecognitionRequest?
    private var voiceTask: SFSpeechRecognitionTask?
    private var voiceEngine: AVAudioEngine?
    private var voiceTapInstalled = false
    private var voiceTimeoutTask: Task<Void, Never>?

    private var userConfirmedSession = false

    // MARK: - Init
    override private init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 20
        // Bug 1 fix: allow location (and thus CMMotion piggyback) to run in background
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        synthesizer.delegate = self
        voiceRecognizer = SFSpeechRecognizer(locale: Locale.current)
            ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    // MARK: - Public: monitoring lifecycle

    func startMonitoring() {
        guard CMMotionActivityManager.isActivityAvailable() else { return }
        activityManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self, let activity else { return }
            Task { @MainActor in self.process(activity: activity) }
        }
        // Bug 1 fix: significant location changes relaunch the app from terminated state
        locationManager.startMonitoringSignificantLocationChanges()
    }

    func stopMonitoring() {
        activityManager.stopActivityUpdates()
        locationManager.stopUpdatingLocation()
        locationManager.stopMonitoringSignificantLocationChanges()
        stopDebounceTask?.cancel()
        stopVoiceListening()
    }

    // MARK: - Public: user actions

    func userConfirmedDriveStart() {
        userConfirmedSession = true
        isDrivingConfirmed = true
        showStartBanner = false
        stopVoiceListening()
        speak("Got it. I'll log this drive when you stop.")
    }

    func userDismissedDriveStart() {
        userConfirmedSession = false
        isDrivingConfirmed = false
        showStartBanner = false
        driveStartTime = nil
        isDriving = false
        stopVoiceListening()
        locationManager.stopUpdatingLocation()
    }

    /// Called when user taps "End Drive" manually from the persistent pill.
    func endDriveNow() {
        stopDebounceTask?.cancel()
        driveEnded()
    }

    func saveDetectedSession() -> DetectedSession? {
        let s = pendingSession
        pendingSession = nil
        showEndPrompt = false
        userConfirmedSession = false
        isDrivingConfirmed = false
        return s
    }

    func dismissEndPrompt() {
        pendingSession = nil
        showEndPrompt = false
        userConfirmedSession = false
        isDrivingConfirmed = false
    }

    // MARK: - Activity processing

    private func process(activity: CMMotionActivity) {
        if activity.automotive && activity.confidence != .low {
            driveDetected(at: activity.startDate)
        } else if isDriving && !activity.automotive {
            stopDebounceTask?.cancel()
            stopDebounceTask = Task {
                // 60-second debounce — handles traffic lights without ending the session
                try? await Task.sleep(for: .seconds(60))
                if !Task.isCancelled { await MainActor.run { self.driveEnded() } }
            }
        }
    }

    private func driveDetected(at startDate: Date) {
        stopDebounceTask?.cancel()
        guard !isDriving else { return }
        isDriving = true
        driveStartTime = startDate
        maxSpeedMph = 0
        userConfirmedSession = false
        isDrivingConfirmed = false
        // Bug 1 fix: request always authorization so detection works when app is in background
        locationManager.requestAlwaysAuthorization()
        locationManager.startUpdatingLocation()
        showStartBanner = true
        announceDetection()
    }

    private func driveEnded() {
        guard isDriving, let startTime = driveStartTime else { return }
        isDriving = false
        isDrivingConfirmed = false
        locationManager.stopUpdatingLocation()
        showStartBanner = false
        stopVoiceListening()

        let durationMinutes = max(Int(Date().timeIntervalSince(startTime) / 60), 1)
        let wasConfirmed = userConfirmedSession
        userConfirmedSession = false
        driveStartTime = nil

        // Bug 3 fix: discard only very short detections (< 2 min = likely noise / traffic stops).
        // For anything ≥ 2 min, always surface the end-prompt — even if user never said yes —
        // so no drive data is silently lost.
        guard durationMinutes >= 2 else { return }

        var conditions: [DrivingCondition] = []
        let hour = Calendar.current.component(.hour, from: startTime)
        conditions.append(hour >= 18 || hour < 6 ? .night : .day)
        if maxSpeedMph > 45 { conditions.append(.highway) }

        pendingSession = DetectedSession(
            date: startTime,
            durationMinutes: durationMinutes,
            conditions: conditions,
            wasUserConfirmed: wasConfirmed
        )
        showEndPrompt = true

        if wasConfirmed {
            speak("Drive ended. \(durationMinutes) minute\(durationMinutes == 1 ? "" : "s") detected. Please review and save your session.")
        } else {
            speak("A drive was detected. Would you like to log this session?")
        }
    }

    // MARK: - TTS

    private func announceDetection() {
        speak("Driving detected. Say yes to log this session, or no to dismiss.")
    }

    private func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        synthesizer.speak(utterance)
    }

    // MARK: - Voice response

    private func startVoiceResponseListening() {
        guard !isListeningForVoiceResponse,
              isDriving, showStartBanner,
              SFSpeechRecognizer.authorizationStatus() == .authorized else { return }

        isListeningForVoiceResponse = true

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        voiceRequest = request

        do {
            let session = AVAudioSession.sharedInstance()
            // Bug 2 fix: use playAndRecord so the mic is already warm after TTS finishes
            try session.setCategory(.playAndRecord, mode: .default,
                                    options: [.duckOthers, .defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let engine = AVAudioEngine()
            let inputNode = engine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buf, _ in
                request?.append(buf)
            }
            voiceTapInstalled = true
            engine.prepare()
            try engine.start()
            voiceEngine = engine

            voiceTask = voiceRecognizer?.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }
                if let text = result?.bestTranscription.formattedString.lowercased() {
                    let yes = ["yes", "yeah", "yep", "sure", "ok", "okay", "log it", "log", "do it", "correct", "affirmative"]
                    let no  = ["no", "nope", "cancel", "dismiss", "don't", "stop", "not now", "skip", "ignore"]
                    if yes.contains(where: { text.contains($0) }) {
                        Task { @MainActor in self.userConfirmedDriveStart() }
                    } else if no.contains(where: { text.contains($0) }) {
                        Task { @MainActor in self.userDismissedDriveStart() }
                    }
                }
                if error != nil || result?.isFinal == true {
                    Task { @MainActor in self.stopVoiceListening() }
                }
            }
        } catch {
            isListeningForVoiceResponse = false
            return
        }

        // Auto-timeout after 10 seconds of silence
        voiceTimeoutTask?.cancel()
        voiceTimeoutTask = Task {
            try? await Task.sleep(for: .seconds(10))
            if !Task.isCancelled { await MainActor.run { self.stopVoiceListening() } }
        }
    }

    private func stopVoiceListening() {
        guard isListeningForVoiceResponse else { return }
        isListeningForVoiceResponse = false
        voiceTimeoutTask?.cancel()
        voiceRequest?.endAudio()
        voiceTask?.cancel()
        voiceTask = nil
        voiceRequest = nil
        if let engine = voiceEngine {
            if voiceTapInstalled {
                engine.inputNode.removeTap(onBus: 0)
                voiceTapInstalled = false
            }
            engine.stop()
            voiceEngine = nil
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

// MARK: - CLLocationManagerDelegate

extension AutoDriveManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last, loc.speed >= 0 else { return }
        let mph = loc.speed * 2.23694
        Task { @MainActor in if mph > self.maxSpeedMph { self.maxSpeedMph = mph } }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            Task { @MainActor in if self.isDriving { self.locationManager.startUpdatingLocation() } }
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension AutoDriveManager: AVSpeechSynthesizerDelegate {
    /// After the "Driving detected" announcement finishes, wait briefly for the audio
    /// session to settle, then start listening for a yes/no voice response.
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                        didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard self.isDriving && self.showStartBanner && !self.isListeningForVoiceResponse else { return }
            // Bug 2 fix: give AVAudioSession 500 ms to fully exit playback mode
            // before we switch to playAndRecord for speech recognition.
            try? await Task.sleep(for: .milliseconds(500))
            guard self.isDriving && self.showStartBanner && !self.isListeningForVoiceResponse else { return }
            self.startVoiceResponseListening()
        }
    }
}
