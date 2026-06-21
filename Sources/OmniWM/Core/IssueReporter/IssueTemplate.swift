// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/BarutSRB/OmniWM

import Foundation

enum IssueTemplate {
    static let notProvided = "Not provided"

    static let requiredHeaders = [
        "## Summary",
        "## Steps to Reproduce",
        "## Expected Behavior",
        "## Actual Behavior",
        "## Additional Context"
    ]

    static func assemble(
        summary: String,
        stepsToReproduce: String,
        expectedBehavior: String,
        actualBehavior: String,
        additionalContext: String
    ) -> String {
        let contents = [summary, stepsToReproduce, expectedBehavior, actualBehavior, additionalContext]
        return zip(requiredHeaders, contents)
            .map { header, content in
                let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
                return "\(header)\n\(trimmed.isEmpty ? notProvided : trimmed)"
            }
            .joined(separator: "\n\n")
    }

    static let rewriteInstructions = loadPrompt("issue-rewrite-prompt")

    static let hotkeyContextPreamble = loadPrompt("issue-hotkey-context-preamble")

    private static func loadPrompt(_ name: String) -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: "md", subdirectory: "Prompts"),
              let text = try? String(contentsOf: url, encoding: .utf8)
        else {
            fatalOffMain("Missing bundled prompt resource: Prompts/\(name).md")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
