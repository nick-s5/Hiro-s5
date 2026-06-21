// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/BarutSRB/OmniWM

import Foundation

enum SettingsConfigDiagnostics {
    static func issues() -> [DiagnosticsIssue] {
        var issues: [DiagnosticsIssue] = []

        if let data = try? Data(contentsOf: SettingsFilePersistence.fileURL) {
            let unknown = SettingsTOMLCodec.unknownKeyPaths(in: data)
            if !unknown.isEmpty {
                issues.append(DiagnosticsIssue(kind: .unknownConfigKeys(keyPaths: unknown)))
            }
        }

        let corruptURL = SettingsFilePersistence.defaultDirectoryURL
            .appendingPathComponent(SettingsFilePersistence.corruptFileName, isDirectory: false)
        if FileManager.default.fileExists(atPath: corruptURL.path) {
            issues.append(DiagnosticsIssue(kind: .settingsFileCorrupt))
        }

        return issues
    }
}
