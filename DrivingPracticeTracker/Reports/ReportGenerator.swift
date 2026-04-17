import UIKit

/// Generates CSV and PDF reports from a list of DrivingSession values.
struct ReportGenerator {

    // MARK: - CSV

    static func buildCSV(sessions: [DrivingSession]) -> String {
        var lines = ["Date,Duration (min),Hours,Conditions,Supervisor,Notes"]
        for s in sessions.sorted(by: { $0.date < $1.date }) {
            let fields: [String] = [
                s.date.ISO8601Format(),
                "\(s.durationMinutes)",
                String(format: "%.2f", s.durationHours),
                s.conditions.map(\.rawValue).joined(separator: "|"),
                s.supervisor.replacingOccurrences(of: ",", with: ";"),
                s.notes.replacingOccurrences(of: ",", with: ";")
                         .replacingOccurrences(of: "\n", with: " ")
            ]
            lines.append(fields.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - PDF

    static func buildPDF(
        sessions: [DrivingSession],
        profile: RequirementsProfile,
        driverName: String
    ) -> Data {
        let pageW: CGFloat  = 595.2   // A4 portrait
        let pageH: CGFloat  = 841.8
        let margin: CGFloat = 40
        let contentW        = pageW - margin * 2
        let footerH: CGFloat = 30
        let safeH            = pageH - footerH

        // Shared attributes
        let white:  [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 20), .foregroundColor: UIColor.white]
        let bold14: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 14), .foregroundColor: UIColor.label]
        let reg11:  [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11),     .foregroundColor: UIColor.secondaryLabel]
        let bold10: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 10), .foregroundColor: UIColor.white]
        let row9:   [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9),      .foregroundColor: UIColor.label]
        let stat10: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 10),     .foregroundColor: UIColor.secondaryLabel]
        let statV:  [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 16), .foregroundColor: UIColor.systemBlue]

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH)
        )

        return renderer.pdfData { ctx in
            var y: CGFloat = 0
            var pageNum = 0

            // ── Helpers ──────────────────────────────────────────────────────
            func beginPage() {
                ctx.beginPage()
                pageNum += 1
                // Footer
                let footerY = pageH - footerH
                UIColor.systemGray5.setFill()
                UIBezierPath(rect: CGRect(x: 0, y: footerY, width: pageW, height: footerH)).fill()
                let footAttr: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 8),
                    .foregroundColor: UIColor.secondaryLabel
                ]
                "DrivingPracticeTracker  ·  Page \(pageNum)".draw(
                    at: CGPoint(x: margin, y: footerY + 9), withAttributes: footAttr
                )
                Date().formatted(date: .abbreviated, time: .omitted).draw(
                    at: CGPoint(x: pageW - 120, y: footerY + 9), withAttributes: footAttr
                )
            }

            func checkBreak(height: CGFloat) {
                if y + height > safeH - margin {
                    beginPage()
                    y = margin
                }
            }

            // ── Page 1 header ────────────────────────────────────────────────
            beginPage()

            // Blue header bar
            UIColor.systemBlue.setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 0, width: pageW, height: 58)).fill()
            "Driving Practice Report".draw(at: CGPoint(x: margin, y: 16), withAttributes: white)
            y = 72

            // Driver / jurisdiction / date
            if !driverName.isEmpty {
                "Driver: \(driverName)".draw(at: CGPoint(x: margin, y: y), withAttributes: bold14)
                y += 20
            }
            let jurisdiction = profile.region.isEmpty ? profile.name
                : (profile.name == "Custom" ? profile.region : "\(profile.name) — \(profile.region)")
            "Jurisdiction: \(jurisdiction)".draw(at: CGPoint(x: margin, y: y), withAttributes: reg11)
            y += 16
            "Generated: \(Date().formatted(date: .long, time: .shortened))".draw(
                at: CGPoint(x: margin, y: y), withAttributes: reg11
            )
            y += 28

            // ── Summary stats box ────────────────────────────────────────────
            let totalH   = sessions.reduce(0.0) { $0 + $1.durationHours }
            let nightH   = sessions.filter(\.isNight).reduce(0.0) { $0 + $1.durationHours }
            let highwayH = sessions.filter(\.isHighway).reduce(0.0) { $0 + $1.durationHours }
            let totalPct = profile.totalRequiredHours > 0
                ? min(totalH / profile.totalRequiredHours * 100, 100) : 0

            let boxRect = CGRect(x: margin, y: y, width: contentW, height: 76)
            UIColor.systemBlue.withAlphaComponent(0.07).setFill()
            UIBezierPath(roundedRect: boxRect, cornerRadius: 8).fill()
            UIColor.systemBlue.withAlphaComponent(0.25).setStroke()
            UIBezierPath(roundedRect: boxRect, cornerRadius: 8).stroke()

            let statW = contentW / 4
            let stats: [(String, String)] = [
                ("Sessions",     "\(sessions.count)"),
                ("Total Hours",  String(format: "%.1f / %.0f", totalH, profile.totalRequiredHours)),
                ("Night Hours",  String(format: "%.1f / %.0f", nightH, profile.nightRequiredHours)),
                ("Progress",     String(format: "%.0f%%", totalPct))
            ]
            for (i, (label, value)) in stats.enumerated() {
                let x = margin + CGFloat(i) * statW + 10
                label.draw(at: CGPoint(x: x, y: y + 12), withAttributes: stat10)
                value.draw(at: CGPoint(x: x, y: y + 28), withAttributes: statV)
            }
            // Thin progress bar inside box
            if profile.totalRequiredHours > 0 {
                let barY = y + 58
                let fillW = contentW * CGFloat(min(totalH / profile.totalRequiredHours, 1.0))
                UIColor.systemBlue.withAlphaComponent(0.15).setFill()
                UIBezierPath(roundedRect: CGRect(x: margin + 10, y: barY, width: contentW - 20, height: 6), cornerRadius: 3).fill()
                UIColor.systemBlue.setFill()
                UIBezierPath(roundedRect: CGRect(x: margin + 10, y: barY, width: fillW - 20, height: 6), cornerRadius: 3).fill()
            }
            y += 96

            // ── Sessions table ────────────────────────────────────────────────
            checkBreak(height: 50)
            let tableTitle: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 12), .foregroundColor: UIColor.label
            ]
            "Session Log (\(sessions.count))".draw(at: CGPoint(x: margin, y: y), withAttributes: tableTitle)
            y += 18

            // Table header row
            let hdrRect = CGRect(x: margin, y: y, width: contentW, height: 20)
            UIColor.systemGray.setFill()
            UIBezierPath(roundedRect: hdrRect, cornerRadius: 3).fill()

            let colX: [(String, CGFloat)] = [
                ("Date",       0),
                ("Duration",  130),
                ("Conditions", 195),
                ("Supervisor", 330),
                ("Notes",      400)
            ]
            for (title, offset) in colX {
                title.draw(at: CGPoint(x: margin + offset + 4, y: y + 4), withAttributes: bold10)
            }
            y += 24

            // Data rows
            for (idx, s) in sessions.sorted(by: { $0.date < $1.date }).enumerated() {
                checkBreak(height: 18)
                if idx % 2 == 0 {
                    UIColor.systemGray6.setFill()
                    UIBezierPath(rect: CGRect(x: margin, y: y, width: contentW, height: 18)).fill()
                }
                let rowY = y + 3
                s.date.formatted(date: .abbreviated, time: .shortened)
                    .draw(at: CGPoint(x: margin + 4, y: rowY), withAttributes: row9)
                s.formattedDuration
                    .draw(at: CGPoint(x: margin + 134, y: rowY), withAttributes: row9)
                s.conditions.map(\.rawValue).joined(separator: ", ")
                    .draw(at: CGPoint(x: margin + 199, y: rowY), withAttributes: row9)
                s.supervisor
                    .draw(at: CGPoint(x: margin + 334, y: rowY), withAttributes: row9)
                // Truncate notes to ~18 chars
                let notePreview = s.notes.isEmpty ? "" : (s.notes.count > 20 ? String(s.notes.prefix(18)) + "…" : s.notes)
                notePreview.draw(at: CGPoint(x: margin + 404, y: rowY), withAttributes: row9)
                y += 18
            }

            // Bottom border
            y += 4
            UIColor.systemGray4.setStroke()
            let path = UIBezierPath()
            path.move(to: CGPoint(x: margin, y: y))
            path.addLine(to: CGPoint(x: margin + contentW, y: y))
            path.lineWidth = 0.5
            path.stroke()
        }
    }

    // MARK: - Helpers

    /// Saves PDF data to the temp directory and returns the URL for sharing.
    static func pdfURL(data: Data, driverName: String) -> URL {
        let name = driverName.isEmpty
            ? "DrivingPracticeReport"
            : "\(driverName.replacingOccurrences(of: " ", with: "_"))_DrivingReport"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(name)
            .appendingPathExtension("pdf")
        try? data.write(to: url)
        return url
    }

    /// Saves CSV string to the temp directory and returns the URL for sharing.
    static func csvURL(csv: String, driverName: String) -> URL {
        let name = driverName.isEmpty
            ? "DrivingPracticeLog"
            : "\(driverName.replacingOccurrences(of: " ", with: "_"))_DrivingLog"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(name)
            .appendingPathExtension("csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
