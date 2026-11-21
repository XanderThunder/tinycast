import AppKit

enum PaletteMode: String, CaseIterable, Identifiable {
    case launcher
    case calculatorHistory
    case fileSearch
    case menuSearch
    case switchWindows
    case rooms
    /// Choosing a room's windows and apps; the room was named on the Rooms screen.
    case roomWindows
    case customCommandEditor
    case customCommands
    case quicklinks
    case quicklinkEditor
    case dictionary

    var id: String { rawValue }

    var isNativeEditor: Bool {
        self == .quicklinkEditor || self == .customCommandEditor
    }

    var systemImage: String {
        switch self {
        case .launcher: return "magnifyingglass"
        case .calculatorHistory: return "plus.forwardslash.minus"
        case .fileSearch: return "doc.text.magnifyingglass"
        case .menuSearch: return "menubar.rectangle"
        case .switchWindows: return "macwindow.on.rectangle"
        case .rooms: return "door.left.hand.open"
        case .roomWindows: return "macwindow.badge.plus"
        case .customCommandEditor, .customCommands: return CustomCommand.sfSymbol
        case .quicklinks, .quicklinkEditor: return Quicklink.sfSymbol
        case .dictionary: return "book.closed"
        }
    }
    var placeholder: String {
        switch self {
        case .launcher: return String(localized: "Search for apps and commands…")
        case .calculatorHistory:
            return String(localized: "Do math, convert units, or search your past calculations…")
        case .fileSearch: return String(localized: "Search files and folders…")
        case .menuSearch: return String(localized: "Search menu bar items…")
        case .switchWindows: return String(localized: "Search open windows…")
        case .rooms: return String(localized: "Search rooms, or name a new one…")
        case .roomWindows: return String(localized: "Search windows, or type an app to add…")
        case .customCommandEditor: return String(localized: "Command editor")
        case .customCommands: return String(localized: "Search custom commands…")
        case .quicklinks: return String(localized: "Search quicklinks…")
        case .quicklinkEditor: return String(localized: "Quicklink editor")
        case .dictionary: return String(localized: "Look up a word…")
        }
    }
}

/// The app a paste lands in, resolved once per show so nothing re-reads it per render.
struct PasteTarget: Equatable {
    let name: String
    /// Bundle path for `IconCache` — nil for a target with no on-disk bundle.
    let iconPath: String?

    init?(app: NSRunningApplication?) {
        guard let app, let name = app.localizedName else { return nil }
        self.name = name
        iconPath = app.bundleURL?.path
    }

    var pasteTitle: String { String(localized: "Paste to \(name)") }
}
