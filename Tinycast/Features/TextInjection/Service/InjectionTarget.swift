import AppKit

/// The app text is read from: the one behind the palette, or the frontmost one for a hotkey.
enum InjectionTarget {
    case external(NSRunningApplication)

    /// Our panels never activate, so a key window of ours means the keystroke stayed with us.
    @MainActor
    static func current() -> InjectionTarget? {
        guard NSApp.keyWindow == nil else { return nil }
        return NSWorkspace.shared.frontmostApplication.map(InjectionTarget.external)
    }

    /// What the palette covered when it was summoned.
    @MainActor
    static func behindPalette(app: NSRunningApplication?) -> InjectionTarget? {
        app.map(InjectionTarget.external)
    }

    var externalApp: NSRunningApplication? {
        guard case .external(let app) = self else { return nil }
        return app
    }
}
