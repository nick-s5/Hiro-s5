// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/BarutSRB/OmniWM

import Foundation

struct DiagnosticsFile: Identifiable, Sendable, Equatable {
    let url: URL
    let name: String
    let sizeBytes: Int64
    let modified: Date

    var id: URL {
        url
    }
}

enum DiagnosticsFileScanner {
    static func scan(_ directory: URL) -> [DiagnosticsFile] {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey]
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys
        )) ?? []
        return contents
            .filter { $0.lastPathComponent.hasPrefix("omniwm-") }
            .map { url in
                let values = try? url.resourceValues(forKeys: Set(keys))
                return DiagnosticsFile(
                    url: url,
                    name: url.lastPathComponent,
                    sizeBytes: Int64(values?.fileSize ?? 0),
                    modified: values?.contentModificationDate ?? .distantPast
                )
            }
            .sorted { $0.modified > $1.modified }
    }
}
