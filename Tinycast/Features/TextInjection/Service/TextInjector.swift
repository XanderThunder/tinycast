import AppKit
import Carbon.HIToolbox

/// Reads text out of the app behind the palette, for a quicklink's `{selection}` and `{argument}`.
@MainActor
final class TextInjector {
    private let clipboardManager: ClipboardManager

    init(clipboardManager: ClipboardManager) {
        self.clipboardManager = clipboardManager
    }

    func captureExpansionContext(
        target: InjectionTarget?,
        clipboardHistory: [String]
    ) -> QuicklinkTemplate.ExpansionContext {
        QuicklinkTemplate.ExpansionContext(
            clipboardHistory: clipboardHistory,
            selection: selection(in: target),
            now: Date(),
            calendar: Calendar.current,
            locale: Locale.current,
            timeZone: .current)
    }

    /// A `changeCount` that never moves means nothing was selected, not that the old clipboard won.
    func copySelection(from targetApp: NSRunningApplication?) async -> String? {
        guard await activateAndWaitForTarget(targetApp), copyIsAllowed(targetApp: targetApp) else {
            return nil
        }
        return await copySelection(from: targetApp, pasteboard: NSPasteboard.general)
    }

    /// Split for the harness, which drives a stub pasteboard rather than another app.
    func copySelection(
        from targetApp: NSRunningApplication?, pasteboard: any PasteboardAccess
    ) async -> String? {
        // A second borrow would snapshot the first's copy and read its restore as a selection.
        guard !isBorrowingCopy, let original = PasteboardSnapshot(pasteboard: pasteboard) else {
            return nil
        }
        isBorrowingCopy = true
        clipboardManager.pauseCapture()
        defer {
            restore(original, to: pasteboard)
            clipboardManager.resumeCapture()
            isBorrowingCopy = false
        }

        Paster.postCommandC(toPid: targetApp?.processIdentifier)
        for _ in 0..<Self.copyPollAttempts {
            guard await wait(for: Self.copyPollInterval) else { return nil }
            guard pasteboard.changeCount != original.changeCount else { continue }
            guard let copied = PasteboardSnapshot(pasteboard: pasteboard),
                let data = copied.firstStringData
            else { return nil }
            return String(bytes: data, encoding: .utf8)
        }
        return nil
    }

    private func restore(_ snapshot: PasteboardSnapshot, to pasteboard: any PasteboardAccess) {
        guard let items = snapshot.pasteboardItems() else { return }
        pasteboard.clearContents()
        guard pasteboard.writeObjects(items) else { return }
        clipboardManager.synchronizeAfterTinycastPasteboardMutation(
            changeCount: pasteboard.changeCount)
    }

    private var isBorrowingCopy = false

    /// A copy lands well inside a second; past that the app was never going to answer.
    private static let copyPollAttempts = 40
    private static let copyPollInterval = Duration.milliseconds(25)

    /// A hotkey's target comes from `frontmostApplication`, which can be Tinycast itself.
    private func targetAcceptsInjection(_ targetApp: NSRunningApplication?) -> Bool {
        guard let targetApp,
            !targetApp.isTerminated,
            targetApp.bundleIdentifier != Bundle.main.bundleIdentifier,
            !IsSecureEventInputEnabled()
        else { return false }
        return true
    }

    /// Re-checked after activation, so a target that went away or went secure gets no ⌘C.
    private func copyIsAllowed(targetApp: NSRunningApplication?) -> Bool {
        guard targetAcceptsInjection(targetApp), let targetApp,
            targetApp.isActive,
            NSWorkspace.shared.frontmostApplication?.processIdentifier
                == targetApp.processIdentifier
        else { return false }
        return Permissions.ensureAccessibility()
    }

    private func activateAndWaitForTarget(_ targetApp: NSRunningApplication?) async -> Bool {
        guard let targetApp, !targetApp.isTerminated else { return false }
        targetApp.activate()
        for _ in 0..<50 {
            if targetApp.isActive,
                NSWorkspace.shared.frontmostApplication?.processIdentifier
                    == targetApp.processIdentifier
            {
                return true
            }
            guard await wait(for: .milliseconds(20)) else { return false }
        }
        return false
    }

    private func selection(in target: InjectionTarget?) -> String {
        guard let app = target?.externalApp, Permissions.isAccessibilityTrusted() else { return "" }
        return AccessibilityText.selection(in: app) ?? ""
    }

    private func wait(for duration: Duration) async -> Bool {
        do {
            try await Task.sleep(for: duration)
            return !Task.isCancelled
        } catch {
            return false
        }
    }
}

@MainActor
protocol PasteboardAccess: AnyObject {
    var changeCount: Int { get }
    var pasteboardItems: [NSPasteboardItem]? { get }
    @discardableResult func clearContents() -> Int
    func writeObjects(_ objects: [any NSPasteboardWriting]) -> Bool
}

extension NSPasteboard: PasteboardAccess {}

@MainActor
struct PasteboardSnapshot {
    struct Item {
        let values: [(type: NSPasteboard.PasteboardType, data: Data)]
    }

    let items: [Item]
    let changeCount: Int

    var firstStringData: Data? {
        items.first?.values.first { $0.type == .string }?.data
    }

    init?(pasteboard: any PasteboardAccess) {
        let changeCount = pasteboard.changeCount
        var items: [Item] = []
        for pasteboardItem in pasteboard.pasteboardItems ?? [] {
            var values: [(type: NSPasteboard.PasteboardType, data: Data)] = []
            for type in pasteboardItem.types {
                guard let data = pasteboardItem.data(forType: type) else { return nil }
                values.append((type: type, data: data))
            }
            items.append(Item(values: values))
        }
        guard pasteboard.changeCount == changeCount else { return nil }
        self.items = items
        self.changeCount = changeCount
    }

    func pasteboardItems() -> [NSPasteboardItem]? {
        var pasteboardItems: [NSPasteboardItem] = []
        pasteboardItems.reserveCapacity(items.count)
        for item in items {
            let pasteboardItem = NSPasteboardItem()
            for value in item.values {
                guard pasteboardItem.setData(value.data, forType: value.type) else { return nil }
            }
            pasteboardItems.append(pasteboardItem)
        }
        return pasteboardItems
    }
}
