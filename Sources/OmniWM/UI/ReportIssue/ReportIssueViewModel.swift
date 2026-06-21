// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/BarutSRB/OmniWM

import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class ReportIssueViewModel {
    enum Phase: Equatable {
        case editing
        case rewriting
        case submitted(SubmissionOutcome)
    }

    enum SubmissionOutcome: Equatable {
        case openedBrowser
        case copiedToClipboard
    }

    var title = "" {
        didSet {
            if title != oldValue {
                suggestion = nil
            }
        }
    }

    var body = "" {
        didSet {
            if body != oldValue {
                suggestion = nil
            }
        }
    }

    private(set) var phase: Phase = .editing
    private(set) var suggestion: RewrittenIssue?
    private(set) var errorMessage: String?
    private(set) var lastBundleURL: URL?
    private(set) var lastBundleError: String?

    let availability: IssueAIAvailability

    private let engine: (any IssueRewriting)?
    private let urlBuilder: GitHubIssueURLBuilder
    private let makeDiagnosticsBundle: @MainActor () throws -> URL
    private let hotkeyContextProvider: @MainActor (String) -> String
    private let revealInFinder: @MainActor (URL) -> Void
    private let openURL: @MainActor (URL) -> Void
    private let copyToClipboard: @MainActor (String) -> Void

    init(
        engine: (any IssueRewriting)? = nil,
        availability: IssueAIAvailability? = nil,
        urlBuilder: GitHubIssueURLBuilder = GitHubIssueURLBuilder(),
        makeDiagnosticsBundle: @MainActor @escaping () throws -> URL = { throw IssueReportError.unavailable },
        hotkeyContextProvider: @MainActor @escaping (String) -> String = { _ in "" },
        revealInFinder: @MainActor @escaping (URL) -> Void = { NSWorkspace.shared.activateFileViewerSelecting([$0]) },
        openURL: @MainActor @escaping (URL) -> Void = { _ = NSWorkspace.shared.open($0) },
        copyToClipboard: @MainActor @escaping (String) -> Void = { string in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(string, forType: .string)
        }
    ) {
        if engine != nil || availability != nil {
            self.engine = engine
            self.availability = availability ?? engine?.availability ?? .unsupportedOS
        } else {
            let made = IssueRewritingFactory.make()
            self.engine = made.engine
            self.availability = made.availability
        }
        self.urlBuilder = urlBuilder
        self.makeDiagnosticsBundle = makeDiagnosticsBundle
        self.hotkeyContextProvider = hotkeyContextProvider
        self.revealInFinder = revealInFinder
        self.openURL = openURL
        self.copyToClipboard = copyToClipboard
    }

    var canRequestRewrite: Bool {
        phase == .editing && !isTitleEmpty && !isBodyEmpty
    }

    var canSubmit: Bool {
        phase == .editing && !isTitleEmpty && !isBodyEmpty
    }

    func requestRewrite() async {
        guard canRequestRewrite else { return }
        phase = .rewriting
        errorMessage = nil
        if availability == .available, let engine {
            do {
                let prompt = "Title: \(title)\n\nMessage: \(body)"
                suggestion = try await engine.rewrite(prompt, hotkeyContext: hotkeyContextProvider(prompt))
            } catch {
                errorMessage = error.localizedDescription
            }
        } else {
            suggestion = RewrittenIssue(
                title: title,
                body: IssueTemplate.assemble(
                    summary: body,
                    stepsToReproduce: "",
                    expectedBehavior: "",
                    actualBehavior: "",
                    additionalContext: ""
                )
            )
        }
        phase = .editing
    }

    func applyRewrite() {
        guard let suggestion else { return }
        title = suggestion.title
        body = suggestion.body
        self.suggestion = nil
    }

    func dismissSuggestion() {
        suggestion = nil
    }

    func submit() {
        guard canSubmit else { return }
        lastBundleURL = nil
        lastBundleError = nil
        do {
            let url = try makeDiagnosticsBundle()
            lastBundleURL = url
            revealInFinder(url)
        } catch {
            lastBundleError = error.localizedDescription
        }
        switch urlBuilder.submission(title: title, body: body) {
        case let .url(url):
            openURL(url)
            phase = .submitted(.openedBrowser)
        case let .clipboard(markdown, fallbackURL):
            copyToClipboard(markdown)
            openURL(fallbackURL)
            phase = .submitted(.copiedToClipboard)
        }
    }

    func revealLastBundle() {
        guard let lastBundleURL else { return }
        revealInFinder(lastBundleURL)
    }

    func startOver() {
        title = ""
        body = ""
        suggestion = nil
        errorMessage = nil
        lastBundleURL = nil
        lastBundleError = nil
        phase = .editing
    }

    private var isTitleEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isBodyEmpty: Bool {
        body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
