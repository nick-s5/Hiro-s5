// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/BarutSRB/OmniWM

import Foundation

@MainActor
extension WMController {
    func refreshDiagnosticsIssues() {
        diagnosticsIssues = DiagnosticsIssueAggregator.applicableIssues(controller: self)
    }

    func diagnosticsReportText(traceLimit: Int = 200) -> String {
        RuntimeDiagnosticsReport.build(self, traceLimit: traceLimit)
    }

    @discardableResult
    func writeDiagnosticsReport(traceLimit: Int = 200) throws -> URL {
        let directory = diagnosticsDirectory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = "omniwm-diagnostics-\(Int(Date().timeIntervalSince1970 * 1000)).log"
        let url = directory.appendingPathComponent(filename, isDirectory: false)
        try diagnosticsReportText(traceLimit: traceLimit).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func writeDiagnosticsBundle() throws -> URL {
        let reportURL = try writeDiagnosticsReport()
        var committed = false
        defer {
            if !committed { try? FileManager.default.removeItem(at: reportURL) }
        }
        let directory = diagnosticsDirectory
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let destination = directory.appendingPathComponent("omniwm-bundle-\(timestamp).zip", isDirectory: false)

        let sources = [reportURL]
            + recentCrashLogs(in: directory)
            + recentTraceLogs(in: directory)
            + recentWindowDumps(in: directory)
        let staging = directory.appendingPathComponent("omniwm-support-\(timestamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: staging) }
        for source in sources {
            try FileManager.default.copyItem(
                at: source,
                to: staging.appendingPathComponent(source.lastPathComponent, isDirectory: false)
            )
        }
        stageSettings(into: staging)

        var coordinatorError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(
            readingItemAt: staging,
            options: .forUploading,
            error: &coordinatorError
        ) { zippedURL in
            do {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.copyItem(at: zippedURL, to: destination)
            } catch {
                copyError = error
            }
        }
        if let coordinatorError { throw coordinatorError }
        if let copyError { throw copyError }

        committed = true
        DiagnosticsRetention.wipe(
            directory: directory,
            prefixes: ["omniwm-diagnostics-", "omniwm-bundle-"],
            except: [reportURL, destination]
        )
        return destination
    }

    private func stageSettings(into staging: URL) {
        guard let raw = try? String(contentsOf: settings.settingsFileURL, encoding: .utf8) else { return }
        try? raw.write(
            to: staging.appendingPathComponent(SettingsFilePersistence.fileName, isDirectory: false),
            atomically: true,
            encoding: .utf8
        )
    }

    private func recentCrashLogs(in directory: URL, limit: Int = 5) -> [URL] {
        recentFiles(in: directory, limit: limit) {
            $0.lastPathComponent.hasPrefix("omniwm-crash-") && $0.pathExtension == "log"
        }
    }

    private func recentTraceLogs(in directory: URL, limit: Int = 10) -> [URL] {
        recentFiles(in: directory, limit: limit) {
            $0.lastPathComponent.hasPrefix("omniwm-trace-")
                && $0.pathExtension == "log"
                && !$0.lastPathComponent.hasSuffix(".partial.log")
        }
    }

    private func recentWindowDumps(in directory: URL, limit: Int = 10) -> [URL] {
        recentFiles(in: directory, limit: limit) {
            $0.lastPathComponent.hasPrefix("omniwm-window-") && $0.pathExtension == "json"
        }
    }

    private func recentFiles(in directory: URL, limit: Int, matching: (URL) -> Bool) -> [URL] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )) ?? []
        return contents
            .filter(matching)
            .sorted { modified($0) > modified($1) }
            .prefix(limit)
            .map(\.self)
    }

    private func modified(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }
}
