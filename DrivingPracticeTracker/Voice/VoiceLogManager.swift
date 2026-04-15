import Foundation
import Speech
import AVFoundation
import Combine

/// Manages microphone capture and speech-to-text transcription,
/// then parses natural language into a driving session.
@MainActor
class VoiceLogManager: NSObject, ObservableObject {

    // MARK: - Published state

    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    @Published var errorMessage: String?
    @Published var parsedSession: ParsedSession?

    // Timer mode
    @Published var timerMode: Bool = false
    @Published var sessionInProgress: Bool = false
    @Published var sessionStartTime: Date?
    @Published var sessionElapsedText: String = "00:00"

    // MARK: - Parsed output

    struct ParsedSession {
        var durationMinutes: Int
        var conditions: [DrivingCondition]
        var supervisor: String
    }

    // MARK: - Private audio/speech properties

    private let speechRecognizer: SFSpeechRecognizer? = {
        // Prefer device locale; fall back to en-AU then en-US
        let locales = [Locale.current, Locale(identifier: "en-AU"), Locale(identifier: "en-US")]
        return locales.compactMap { SFSpeechRecognizer(locale: $0) }.first
    }()

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var elapsedTimer: Timer?

    // MARK: - Start / Stop

    func startRecording() async {
        guard await requestPermissions() else {
            errorMessage = "Microphone or Speech Recognition permission denied. Enable both in Settings."
            return
        }
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognition is not available on this device."
            return
        }

        errorMessage = nil
        transcript = ""
        parsedSession = nil

        do {
            try beginAudioSession()
            isRecording = true
        } catch {
            isRecording = false
            errorMessage = "Could not start recording: \(error.localizedDescription)"
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        isRecording = false

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        // Only auto-parse in describe mode (not timer mode, which handles its own end)
        if !timerMode && !transcript.isEmpty {
            parsedSession = parseTranscript(transcript)
        }
    }

    // MARK: - Permission helpers

    private func requestPermissions() async -> Bool {
        // Microphone
        let micGranted: Bool
        if #available(iOS 17, *) {
            micGranted = await AVAudioApplication.requestRecordPermission()
        } else {
            micGranted = await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    cont.resume(returning: granted)
                }
            }
        }
        guard micGranted else { return false }

        // Speech recognition
        return await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
    }

    // MARK: - Audio engine

    private func beginAudioSession() throws {
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true
        request.taskHint = .dictation

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    if self.timerMode {
                        self.checkForStartStopCommands(in: result.bestTranscription.formattedString)
                    }
                }
                if error != nil || result?.isFinal == true {
                    if !self.timerMode {
                        self.stopRecording()
                    }
                }
            }
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    // MARK: - Timer Mode Commands

    private func checkForStartStopCommands(in text: String) {
        let lower = text.lowercased()
        let startPhrases = ["start driving", "start log", "begin drive", "begin driving", "log started"]
        let stopPhrases = ["stop driving", "stop log", "end drive", "end driving", "log stopped", "finish driving"]

        if !sessionInProgress && startPhrases.contains(where: { lower.contains($0) }) {
            sessionStartTime = Date()
            sessionInProgress = true
            transcript = "Session started — say \"stop driving\" when done."
            startElapsedTimer()
        } else if sessionInProgress && stopPhrases.contains(where: { lower.contains($0) }) {
            endTimedSession()
        }
    }

    private func startElapsedTimer() {
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.updateElapsed() }
        }
    }

    private func updateElapsed() {
        guard let start = sessionStartTime else { return }
        let elapsed = Int(Date().timeIntervalSince(start))
        let m = elapsed / 60
        let s = elapsed % 60
        sessionElapsedText = String(format: "%02d:%02d", m, s)
    }

    private func endTimedSession() {
        guard let start = sessionStartTime else { return }
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        let durationMinutes = max(Int(Date().timeIntervalSince(start) / 60), 1)
        let hour = Calendar.current.component(.hour, from: start)
        let conditions: [DrivingCondition] = [hour >= 18 || hour < 6 ? .night : .day]
        parsedSession = ParsedSession(durationMinutes: durationMinutes, conditions: conditions, supervisor: "")
        sessionInProgress = false
        stopRecording()
    }

    // MARK: - Natural Language Parsing

    func parseTranscript(_ text: String) -> ParsedSession {
        let lower = text.lowercased()

        let durationMinutes = parseDuration(from: lower)
        let conditions      = parseConditions(from: lower)
        let supervisor      = parseSupervisor(from: text) // keep original casing for names

        return ParsedSession(
            durationMinutes: max(durationMinutes, 5),
            conditions: conditions,
            supervisor: supervisor
        )
    }

    // MARK: Duration parsing

    private func parseDuration(from text: String) -> Int {
        var hours = 0
        var minutes = 0

        // "X hours" / "X hrs"
        if let h = firstInt(matching: #"(\d+)\s*(?:hours?|hrs?)"#, in: text) { hours = h }
        // "X minutes" / "X mins"
        if let m = firstInt(matching: #"(\d+)\s*(?:minutes?|mins?)"#, in: text) { minutes = m }

        // Written forms with no digits
        if hours == 0 && minutes == 0 {
            if text.contains("two hours")     { hours = 2 }
            else if text.contains("one hour") || text.contains("an hour") { hours = 1 }
            else if text.contains("half hour") || text.contains("half an hour") { minutes = 30 }
            else if text.contains("quarter hour") { minutes = 15 }
        }

        return hours * 60 + minutes
    }

    private func firstInt(matching pattern: String, in text: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return Int(text[range])
    }

    // MARK: Condition parsing

    private func parseConditions(from lower: String) -> [DrivingCondition] {
        var result: [DrivingCondition] = []

        let isNight = lower.contains("night") || lower.contains("dark") || lower.contains("evening")
        result.append(isNight ? .night : .day)

        let conditionKeywords: [(DrivingCondition, [String])] = [
            (.highway, ["highway", "motorway", "freeway", "expressway", "dual carriageway"]),
            (.rain,    ["rain", "raining", "wet", "drizzl", "shower"]),
            (.urban,   ["urban", "city", "town", "suburb", "street"]),
            (.rural,   ["rural", "country", "countryside", "backroad", "back road"]),
        ]

        for (condition, keywords) in conditionKeywords {
            if keywords.contains(where: { lower.contains($0) }) {
                result.append(condition)
            }
        }

        return result
    }

    // MARK: Supervisor parsing

    private func parseSupervisor(from text: String) -> String {
        // e.g. "with my mum Sarah", "with John", "with instructor Dave"
        let pattern = #"(?i)\bwith\s+(?:my\s+)?(?:mum|mom|dad|father|mother|instructor|supervisor|teacher|friend\s+)?([A-Z][a-z]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let nameRange = Range(match.range(at: 1), in: text) else { return "" }
        return String(text[nameRange])
    }
}
