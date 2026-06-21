// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/BarutSRB/OmniWM

import Foundation

enum OmniWMBuildInfo {
    static var version: String {
        Bundle.main.appVersion ?? "unknown"
    }

    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
    }

    static var gitHash: String {
        Bundle.main.infoDictionary?["OMNIWMGitHash"] as? String ?? "SNAPSHOT"
    }
}
