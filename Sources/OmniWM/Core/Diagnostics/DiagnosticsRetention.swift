// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/BarutSRB/OmniWM

import Foundation

enum DiagnosticsRetention {
    static func wipe(directory: URL, prefixes: [String] = ["omniwm-"], except: Set<URL> = []) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return }

        let preserved = Set(except.map { $0.standardizedFileURL.path })
        for file in files where prefixes.contains(where: { file.lastPathComponent.hasPrefix($0) }) {
            guard !preserved.contains(file.standardizedFileURL.path) else { continue }
            try? FileManager.default.removeItem(at: file)
        }
    }
}
