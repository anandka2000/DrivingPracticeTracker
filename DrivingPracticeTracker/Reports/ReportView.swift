import SwiftUI

struct ReportView: View {
    @EnvironmentObject var store: SessionStore
    @State private var selectedFormat = 0   // 0 = PDF, 1 = CSV
    @State private var pdfURL: URL?
    @State private var csvURL: URL?
    @State private var isGenerating = true

    var body: some View {
        VStack(spacing: 0) {
            Picker("Format", selection: $selectedFormat) {
                Text("PDF").tag(0)
                Text("CSV").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            if isGenerating {
                Spacer()
                ProgressView("Generating report…")
                    .progressViewStyle(.circular)
                Spacer()
            } else if selectedFormat == 0 {
                pdfSection
            } else {
                csvSection
            }
        }
        .navigationTitle("Report & Export")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Regenerate", systemImage: "arrow.clockwise") {
                    generateReports()
                }
                .disabled(isGenerating)
            }
        }
        .onAppear { generateReports() }
    }

    // MARK: - PDF section

    private var pdfSection: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 20)

            // Preview card
            VStack(spacing: 14) {
                Image(systemName: "doc.richtext.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.red.gradient)

                VStack(spacing: 4) {
                    Text("PDF Report")
                        .font(.title3.bold())
                    Text("\(store.sessions.count) sessions · \(store.profile.displayTitle)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if !store.driverName.isEmpty {
                        Text("Driver: \(store.driverName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            summaryStats

            if let url = pdfURL {
                ShareLink(
                    item: url,
                    subject: Text("Driving Practice Report"),
                    message: Text("My driving practice log — \(store.profile.displayTitle)")
                ) {
                    Label("Share PDF", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)
            }

            Spacer()
        }
        .padding(.vertical)
    }

    // MARK: - CSV section

    private var csvSection: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CSV Spreadsheet")
                        .font(.subheadline.bold())
                    Text("\(store.sessions.count) rows · comma-separated")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let url = csvURL {
                    ShareLink(
                        item: url,
                        subject: Text("Driving Log CSV"),
                        message: Text("My driving practice sessions")
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.subheadline.bold())
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()

            Divider()

            // Preview first ~30 lines
            ScrollView {
                let csv = buildCSVPreview()
                Text(csv)
                    .font(.system(.caption2, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: - Summary stats card

    private var summaryStats: some View {
        let totalH   = store.totalHours
        let nightH   = store.nightHours
        let req      = store.profile.totalRequiredHours
        let pct      = req > 0 ? min(totalH / req, 1.0) : 0.0

        return VStack(spacing: 12) {
            HStack(spacing: 16) {
                statCell(label: "Total", value: String(format: "%.1fh", totalH), sub: "/ \(Int(req))h req.")
                Divider().frame(height: 36)
                statCell(label: "Night", value: String(format: "%.1fh", nightH),
                         sub: "/ \(Int(store.profile.nightRequiredHours))h req.")
                Divider().frame(height: 36)
                statCell(label: "Sessions", value: "\(store.sessions.count)", sub: "logged")
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "%.0f%% complete", pct * 100))
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(Color.blue.opacity(0.15))
                        RoundedRectangle(cornerRadius: 4).fill(Color.blue)
                            .frame(width: geo.size.width * pct)
                    }
                }
                .frame(height: 8)
            }
            .padding(.horizontal)
        }
        .padding(.horizontal)
    }

    private func statCell(label: String, value: String, sub: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.bold())
            Text(label).font(.caption.bold()).foregroundStyle(.secondary)
            Text(sub).font(.system(size: 9)).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Generation

    private func generateReports() {
        isGenerating = true
        let sessions   = store.sessions
        let profile    = store.profile
        let driverName = store.driverName

        // Build CSV synchronously (it's fast)
        let csvString = ReportGenerator.buildCSV(sessions: sessions)
        csvURL = ReportGenerator.csvURL(csv: csvString, driverName: driverName)

        // Build PDF on a background thread (UIGraphicsPDFRenderer is fine off main)
        Task.detached(priority: .userInitiated) {
            let data = ReportGenerator.buildPDF(sessions: sessions, profile: profile, driverName: driverName)
            let url  = ReportGenerator.pdfURL(data: data, driverName: driverName)
            await MainActor.run {
                self.pdfURL = url
                self.isGenerating = false
            }
        }
    }

    private func buildCSVPreview() -> String {
        let full = ReportGenerator.buildCSV(sessions: store.sessions)
        let lines = full.split(separator: "\n", omittingEmptySubsequences: false)
        return lines.prefix(40).joined(separator: "\n")
            + (lines.count > 40 ? "\n…(\(lines.count - 40) more rows)" : "")
    }
}
