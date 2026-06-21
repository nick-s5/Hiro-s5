// SPDX-License-Identifier: GPL-2.0-only
// Copyright (C) 2026 BarutSRB — https://github.com/BarutSRB/OmniWM

import ApplicationServices
import CoreGraphics
import Foundation

struct AXDumpNode: Codable, Equatable, Sendable {
    var attributes: [String: AXDumpValue]
    var writable: [String]
    var failed: [String]
    var ignored: [String]
}

indirect enum AXDumpValue: Codable, Equatable, Sendable {
    case string(String)
    case int(Int)
    case bool(Bool)
    case double(Double)
    case array([AXDumpValue])
    case element(AXDumpNode)
    case elementRef(String)
    case null

    private enum Tag: String, Codable {
        case array
        case bool
        case double
        case element
        case elementRef
        case int
        case null
        case string
    }

    private enum CodingKeys: String, CodingKey {
        case children
        case node
        case type
        case value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .array(items):
            try container.encode(Tag.array, forKey: .type)
            try container.encode(items, forKey: .children)
        case let .bool(value):
            try container.encode(Tag.bool, forKey: .type)
            try container.encode(value, forKey: .value)
        case let .double(value):
            try container.encode(Tag.double, forKey: .type)
            try container.encode(value, forKey: .value)
        case let .element(node):
            try container.encode(Tag.element, forKey: .type)
            try container.encode(node, forKey: .node)
        case let .elementRef(value):
            try container.encode(Tag.elementRef, forKey: .type)
            try container.encode(value, forKey: .value)
        case let .int(value):
            try container.encode(Tag.int, forKey: .type)
            try container.encode(value, forKey: .value)
        case .null:
            try container.encode(Tag.null, forKey: .type)
        case let .string(value):
            try container.encode(Tag.string, forKey: .type)
            try container.encode(value, forKey: .value)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Tag.self, forKey: .type) {
        case .array:
            self = .array(try container.decode([AXDumpValue].self, forKey: .children))
        case .bool:
            self = .bool(try container.decode(Bool.self, forKey: .value))
        case .double:
            self = .double(try container.decode(Double.self, forKey: .value))
        case .element:
            self = .element(try container.decode(AXDumpNode.self, forKey: .node))
        case .elementRef:
            self = .elementRef(try container.decode(String.self, forKey: .value))
        case .int:
            self = .int(try container.decode(Int.self, forKey: .value))
        case .null:
            self = .null
        case .string:
            self = .string(try container.decode(String.self, forKey: .value))
        }
    }
}

struct AXWindowAXTreeDump: Codable, Equatable, Sendable {
    var window: AXDumpNode
    var app: AXDumpNode
}

enum AXWindowDump {
    enum NodeKind {
        case app
        case child
        case window
    }

    static let maxDepth = 5
    private static let messagingTimeoutSeconds: Float = 2

    static func tree(window: AXUIElement, app: AXUIElement) -> AXWindowAXTreeDump {
        AXUIElementSetMessagingTimeout(app, messagingTimeoutSeconds)
        defer { AXUIElementSetMessagingTimeout(app, 0) }
        return AXWindowAXTreeDump(
            window: dump(element: window, kind: .window, depth: 0),
            app: dump(element: app, kind: .app, depth: 0)
        )
    }

    private static let skipAttributes: Set<String> = [
        "AXChildren",
        "AXChildrenInNavigationOrder",
        "AXFocusableAncestor",
        "AXHelp",
        "AXRoleDescription"
    ]

    private static let refOnlyAttributes: Set<String> = [
        "AXColumns",
        "AXContents",
        "AXLinkedUIElements",
        "AXParent",
        "AXRows",
        "AXSelectedChildren",
        "AXServesAsTitleForUIElements",
        "AXSharedFocusElements",
        "AXTabs",
        "AXTopLevelUIElement",
        "AXVisibleChildren",
        "AXWindow"
    ]

    static func dump(element: AXUIElement, kind: NodeKind, depth: Int) -> AXDumpNode {
        var attributes: [String: AXDumpValue] = [:]
        var writable: [String] = []
        var failed: [String] = []
        var ignored: [String] = []

        var namesRef: CFArray?
        let namesStatus = AXUIElementCopyAttributeNames(element, &namesRef)
        guard namesStatus == .success, let names = namesRef as? [String] else {
            return AXDumpNode(
                attributes: [:],
                writable: [],
                failed: ["AXAttributeNames(ax=\(namesStatus.rawValue))"],
                ignored: []
            )
        }

        let kindIgnored = kindIgnored(kind)
        for name in names.sorted() {
            if skipAttributes.contains(name) || kindIgnored.contains(name) {
                ignored.append(name)
                continue
            }
            var settable: DarwinBoolean = false
            if AXUIElementIsAttributeSettable(element, name as CFString, &settable) == .success, settable.boolValue {
                writable.append(name)
            }
            var raw: CFTypeRef?
            let status = AXUIElementCopyAttributeValue(element, name as CFString, &raw)
            guard status == .success, let raw else {
                failed.append("\(name)(ax=\(status.rawValue))")
                continue
            }
            attributes[name] = dumpValue(raw, elementDepth: depth, refOnly: refOnlyAttributes.contains(name))
        }

        return AXDumpNode(attributes: attributes, writable: writable, failed: failed, ignored: ignored)
    }

    private static func kindIgnored(_ kind: NodeKind) -> Set<String> {
        switch kind {
        case .app: ["AXEnhancedUserInterface", "AXPreferredLanguage"]
        case .child,
             .window: []
        }
    }

    private static func dumpValue(_ value: CFTypeRef, elementDepth: Int, refOnly: Bool) -> AXDumpValue {
        let typeId = CFGetTypeID(value)
        if typeId == CFStringGetTypeID() {
            return .string(value as? String ?? "")
        }
        if typeId == CFBooleanGetTypeID() {
            guard let flag = value as? Bool else { return .null }
            return .bool(flag)
        }
        if typeId == CFNumberGetTypeID() {
            guard let number = value as? NSNumber else { return .null }
            if CFNumberIsFloatType(number as CFNumber) {
                return .double(number.doubleValue)
            }
            return .int(number.intValue)
        }
        if typeId == AXValueGetTypeID() {
            return .string(describeAXValue(unsafeDowncast(value, to: AXValue.self)))
        }
        if typeId == AXUIElementGetTypeID() {
            let child = unsafeDowncast(value, to: AXUIElement.self)
            if refOnly || elementDepth + 1 >= maxDepth {
                return .elementRef(describeElement(child))
            }
            return .element(dump(element: child, kind: .child, depth: elementDepth + 1))
        }
        if typeId == CFArrayGetTypeID() {
            let items = (value as? [AnyObject]) ?? []
            return .array(items.map { dumpValue($0 as CFTypeRef, elementDepth: maxDepth, refOnly: true) })
        }
        return .null
    }

    private static func describeAXValue(_ value: AXValue) -> String {
        switch AXValueGetType(value) {
        case .cgPoint:
            var point = CGPoint.zero
            AXValueGetValue(value, .cgPoint, &point)
            return "point(x=\(point.x), y=\(point.y))"
        case .cgSize:
            var size = CGSize.zero
            AXValueGetValue(value, .cgSize, &size)
            return "size(w=\(size.width), h=\(size.height))"
        case .cgRect:
            var rect = CGRect.zero
            AXValueGetValue(value, .cgRect, &rect)
            return "rect(x=\(rect.minX), y=\(rect.minY), w=\(rect.width), h=\(rect.height))"
        case .cfRange:
            var range = CFRange()
            AXValueGetValue(value, .cfRange, &range)
            return "range(location=\(range.location), length=\(range.length))"
        default:
            return "axvalue"
        }
    }

    private static func describeElement(_ element: AXUIElement) -> String {
        let role = copyStringAttribute(element, "AXRole") ?? "?"
        var parts = ["role=\(role)"]
        if let subrole = copyStringAttribute(element, "AXSubrole") {
            parts.append("subrole=\(subrole)")
        }
        var windowId: CGWindowID = 0
        if _AXUIElementGetWindow(element, &windowId) == .success {
            parts.append("windowId=\(windowId)")
        }
        return "AXUIElement(\(parts.joined(separator: ", ")))"
    }

    private static func copyStringAttribute(_ element: AXUIElement, _ name: String) -> String? {
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &raw) == .success else { return nil }
        return raw as? String
    }
}
