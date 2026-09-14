// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/BarutSRB/OmniWM

import AppKit
import SwiftUI

struct DisplayProfileDiagram: View {
    struct Display: Identifiable {
        let id: Int
        let name: String
        let isConnected: Bool
        let isBuiltIn: Bool
        let isRequired: Bool
        let workspaceNames: [String]
    }

    let displays: [Display]

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: min(max(displays.count, 1), 3)),
            spacing: 16
        ) {
            ForEach(displays) { display in
                DisplayProfileMonitorCard(
                    name: display.name,
                    isConnected: display.isConnected,
                    isBuiltIn: display.isBuiltIn,
                    isRequired: display.isRequired,
                    workspaceNames: display.workspaceNames
                )
            }
        }
        .padding(.vertical, 8)
    }
}

private struct DisplayProfileMonitorCard: View {
    let name: String
    let isConnected: Bool
    let isBuiltIn: Bool
    let isRequired: Bool
    let workspaceNames: [String]

    private var workspaceSummary: String {
        workspaceNames.isEmpty ? "0 workspaces" : "Workspaces " + workspaceNames.joined(separator: ", ")
    }

    var body: some View {
        VStack(spacing: 8) {
            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    Image(systemName: isBuiltIn ? "laptopcomputer" : "display")
                        .font(.title2)
                        .foregroundStyle(isConnected ? Color.accentColor : .secondary)
                    Text(name)
                        .font(.caption.weight(.medium))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                    Text(isRequired ? "Required to match" : "Optional display")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
                .padding(8)
                .background(Color.accentColor.opacity(isConnected ? 0.06 : 0.02), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            Color.secondary.opacity(0.3),
                            style: StrokeStyle(lineWidth: 1, dash: isConnected ? [] : [4])
                        )
                }
                Rectangle().fill(.secondary.opacity(0.4)).frame(width: 5, height: 7)
                Capsule().fill(.secondary.opacity(0.4)).frame(width: isBuiltIn ? 70 : 36, height: 3)
            }

            if workspaceNames.isEmpty {
                Text("0 workspaces")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(height: 24)
            } else {
                HStack(spacing: 4) {
                    ForEach(Array(workspaceNames.prefix(5)), id: \.self) { name in
                        Text(name)
                            .font(.caption.monospaced().weight(.semibold))
                            .lineLimit(1)
                            .frame(minWidth: 22, minHeight: 24)
                            .padding(.horizontal, 2)
                            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
                    }
                    if workspaceNames.count > 5 {
                        Text("+\(workspaceNames.count - 5)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name), \(isRequired ? "required to match" : "optional display"), \(workspaceSummary)")
    }
}
