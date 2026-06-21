// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/BarutSRB/OmniWM

import SwiftUI

struct ReportIssueSettingsTab: View {
    @State private var model: ReportIssueViewModel
    private let crashPrefill: FatalCapture.PendingCrashReport?

    init(controller: WMController) {
        crashPrefill = controller.pendingCrashReport
        _model = State(initialValue: ReportIssueViewModel(
            makeDiagnosticsBundle: { try controller.writeDiagnosticsBundle() },
            hotkeyContextProvider: { text in
                IssueHotkeyContext.resolve(text: text, bindings: controller.settings.hotkeyBindings)
            }
        ))
    }

    var body: some View {
        Form {
            switch model.phase {
            case let .submitted(outcome):
                submittedSection(outcome)
            default:
                contentSections
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: applyCrashPrefillIfNeeded)
    }

    private func applyCrashPrefillIfNeeded() {
        guard let crashPrefill, model.title.isEmpty, model.body.isEmpty else { return }
        model.title = "Crash: \(crashPrefill.reason)"
        model.body = "OmniWM recovered from a crash (log: \(crashPrefill.url.lastPathComponent)).\n\n"
            + "Reason: \(crashPrefill.reason)\n\nSteps to reproduce:\n"
    }

    @ViewBuilder
    private var contentSections: some View {
        availabilityNotice
        draftSection
        rewriteSection
        submitSection
    }

    @ViewBuilder
    private var availabilityNotice: some View {
        if let message = model.availability.message {
            Section {
                Label(message, systemImage: "info.circle")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var draftSection: some View {
        Section("Issue") {
            TextField("Title", text: $model.title)
                .textFieldStyle(.roundedBorder)
            TextEditor(text: $model.body)
                .frame(minHeight: 180)
                .font(.body.monospaced())
            if let errorMessage = model.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private var rewriteSection: some View {
        let aiAvailable = model.availability == .available
        Section {
            HStack {
                Button(aiAvailable ? "Rewrite & Format with AI" : "Format") {
                    Task { await model.requestRewrite() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canRequestRewrite)
                if model.phase == .rewriting {
                    ProgressView().controlSize(.small)
                }
            }
            if let suggestion = model.suggestion {
                suggestionPreview(suggestion)
            }
            SettingsCaption(
                aiAvailable
                    ? "On-device AI rewrites your title and message into a clear, template-shaped issue. "
                    + "Review it, then apply. Nothing leaves your Mac."
                    : "Shapes your message into the issue template so you can fill in the sections. "
                    + "Review it, then apply."
            )
        }
    }

    @ViewBuilder
    private func suggestionPreview(_ suggestion: RewrittenIssue) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Suggested rewrite")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(suggestion.title)
                .font(.callout.weight(.semibold))
                .textSelection(.enabled)
            Text(suggestion.body)
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            HStack {
                Button("Apply") {
                    model.applyRewrite()
                }
                .buttonStyle(.borderedProminent)
                Button("Dismiss") {
                    model.dismissSuggestion()
                }
            }
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private var submitSection: some View {
        Section {
            SettingsCaption(
                "A diagnostics .zip (logs, your settings.toml, and system info) is created automatically and "
                    + "revealed in Finder. Review it before dragging it into a public issue — it includes your raw "
                    + "configuration."
            )
            Button("Submit to GitHub") {
                model.submit()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.canSubmit)
            SettingsCaption(
                "Opens a pre-filled new-issue page in your browser; you review and post it with your own "
                    + "GitHub account. OmniWM never sees your GitHub login."
            )
        }
    }

    @ViewBuilder
    private func submittedSection(_ outcome: ReportIssueViewModel.SubmissionOutcome) -> some View {
        Section {
            switch outcome {
            case .openedBrowser:
                Label(
                    "Opened GitHub in your browser. Review it, then click \"Submit new issue\".",
                    systemImage: "checkmark.circle.fill"
                )
                .foregroundStyle(.green)
            case .copiedToClipboard:
                Label(
                    "The issue was too long for a link, so it was copied to your clipboard. "
                        + "Paste it into the GitHub page that just opened.",
                    systemImage: "doc.on.clipboard"
                )
                .foregroundStyle(.secondary)
            }
            bundleStatus
            Button("Report another issue") {
                model.startOver()
            }
        }
    }

    @ViewBuilder
    private var bundleStatus: some View {
        if let url = model.lastBundleURL {
            Label(
                "Diagnostics bundle revealed in Finder — drag \(url.lastPathComponent) into the issue to attach it.",
                systemImage: "paperclip"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            Button("Reveal Bundle Again") {
                model.revealLastBundle()
            }
            .controlSize(.small)
        }
        if let bundleError = model.lastBundleError {
            Label(
                "Couldn't create the diagnostics bundle: \(bundleError). Your issue still opened.",
                systemImage: "exclamationmark.triangle.fill"
            )
            .font(.caption)
            .foregroundStyle(.orange)
        }
    }
}
