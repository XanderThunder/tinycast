import Foundation

enum CommandID: String, CaseIterable, Sendable {
    case calculatorHistory = "command:calculator-history"
    case clipboardHistory = "command:clipboard-history"
    case pasteSequentially = "command:paste-sequentially"
    case searchFiles = "command:search-files"
    case searchMenuItems = "command:search-menu-items"
    case switchWindows = "command:switch-windows"
    case switchWindowsBackwards = "command:switch-windows-backwards"
    case openCamera = "command:open-camera"
    case openInBrowser = "command:open-in-browser"
    case runShellCommand = "command:run-shell-command"
    case createCustomCommand = "command:create-custom-command"
    case searchCustomCommands = "command:search-custom-commands"
    case define = "command:define"
    case createWindowLayout = "command:create-window-layout"
    case captureWindowLayout = "command:capture-window-layout"
    case switchRoom = "command:switch-room"
    case createRoom = "command:create-room"
    case createQuicklink = "command:create-quicklink"
    case searchQuicklinks = "command:search-quicklinks"
    case importQuicklinks = "command:import-quicklinks"
    case exportQuicklinks = "command:export-quicklinks"
    case searchSnippets = "command:search-snippets"
    case createSnippet = "command:create-snippet"
    case exportSettings = "command:export-settings"
    case importSettings = "command:import-settings"
    case importFromRaycast = "command:import-from-raycast"
    case settings = "command:settings"
    case about = "command:about"
    case quit = "command:quit"

    static let defaultCompactBarCommands: [CommandID] = [
        .clipboardHistory, .searchFiles, .searchQuicklinks
    ]

    static let compactBarOptions: [CommandID] =
        defaultCompactBarCommands + [
            .searchSnippets
        ]

    static let compactBarLimit = 4

    static func validCompactBarCommands(_ commands: [CommandID]) -> Bool {
        commands.count <= compactBarLimit && Set(commands).count == commands.count
            && commands.allSatisfy(compactBarOptions.contains)
    }

    static func compactBarCommands(from identifiers: [String]) -> [CommandID]? {
        let commands = identifiers.compactMap(CommandID.init(rawValue:))
        guard commands.count == identifiers.count, validCompactBarCommands(commands) else { return nil }
        return commands
    }

    var name: String { nameResource.resolved() }

    var englishName: String { nameResource.key }

    private var nameResource: LocalizedStringResource {
        switch self {
        case .calculatorHistory: return "Calculator History"
        case .clipboardHistory: return "Clipboard History"
        case .pasteSequentially: return "Paste Sequentially"
        case .searchFiles: return "Search Files"
        case .searchMenuItems: return "Search Menu Bar Items"
        case .switchWindows: return "Switch Windows"
        case .switchWindowsBackwards: return "Switch Windows Backwards"
        case .openCamera: return "Open Camera"
        case .openInBrowser: return "Open in Browser"
        case .runShellCommand: return "Run Shell Command"
        case .createCustomCommand: return "Create Custom Command"
        case .searchCustomCommands: return "Search Custom Commands"
        case .define: return "Define Word"
        case .createWindowLayout: return "Create Window Layout"
        case .captureWindowLayout: return "Create Layout from Current Windows"
        case .switchRoom: return "Switch Room"
        case .createRoom: return "Create Room"
        case .createQuicklink: return "Create Quicklink"
        case .searchQuicklinks: return "Search Quicklinks"
        case .importQuicklinks: return "Import Quicklinks"
        case .exportQuicklinks: return "Export Quicklinks"
        case .searchSnippets: return "Search Snippets"
        case .createSnippet: return "Create Snippet"
        case .exportSettings: return "Export Backup"
        case .importSettings: return "Import Backup"
        case .importFromRaycast: return "Import from Raycast"
        case .settings: return "Tinycast Settings"
        case .about: return "About Tinycast"
        case .quit: return "Quit Tinycast"
        }
    }

    var sfSymbol: String {
        switch self {
        case .calculatorHistory: return "plus.forwardslash.minus"
        case .clipboardHistory: return "list.clipboard.fill"
        case .pasteSequentially: return "arrow.right.doc.on.clipboard"
        case .searchFiles: return "doc.text.magnifyingglass"
        case .searchMenuItems: return "menubar.rectangle"
        case .switchWindows, .switchWindowsBackwards: return "macwindow.on.rectangle"
        case .openCamera: return "camera.fill"
        case .openInBrowser: return "globe"
        case .runShellCommand, .createCustomCommand, .searchCustomCommands: return "terminal.fill"
        case .define: return "book.closed.fill"
        case .createWindowLayout: return "plus.rectangle.on.rectangle.fill"
        case .captureWindowLayout: return "macwindow.badge.plus"
        case .switchRoom: return "door.left.hand.open"
        case .createRoom: return "rectangle.stack.fill.badge.plus"
        case .createQuicklink: return "link.badge.plus"
        case .searchQuicklinks: return Quicklink.sfSymbol
        case .importQuicklinks: return "square.and.arrow.down.fill"
        case .exportQuicklinks: return "square.and.arrow.up.fill"
        case .searchSnippets: return "curlybraces"
        case .createSnippet: return "plus.rectangle.on.rectangle.fill"
        case .exportSettings: return "square.and.arrow.up.fill"
        case .importSettings: return "square.and.arrow.down.fill"
        case .importFromRaycast: return "arrow.down.doc.fill"
        case .settings: return "gearshape.fill"
        case .about: return "info.circle.fill"
        case .quit: return "power"
        }
    }

    var tint: IconTint {
        switch self {
        case .clipboardHistory, .pasteSequentially: return .indigo
        case .calculatorHistory: return .green
        case .searchFiles, .openInBrowser, .createQuicklink, .searchQuicklinks, .importQuicklinks,
            .exportQuicklinks:
            return .blue
        case .searchMenuItems, .switchWindows, .switchWindowsBackwards, .runShellCommand,
            .createCustomCommand, .searchCustomCommands:
            return .graphite
        case .openCamera, .settings, .about: return .gray
        case .define, .searchSnippets, .createSnippet: return .brown
        case .quit: return .red
        case .createWindowLayout, .captureWindowLayout, .switchRoom, .createRoom: return .mint
        case .exportSettings, .importSettings, .importFromRaycast: return .cyan
        }
    }

    /// Queries this command wins until the user opens a rival more.
    var boostedTerms: Set<String> { [] }

    /// Suggested, highest first, until the user's own habits fill the section.
    var suggestionPriority: Int? {
        switch self {
        case .clipboardHistory: 80
        case .searchFiles: 70
        case .createQuicklink, .createSnippet: 30
        default: nil
        }
    }

    /// Query-driven: the typed text is their input, so they are built where offered, never listed.
    var isQueryDriven: Bool {
        self == .openInBrowser || self == .runShellCommand
    }

    /// A chord carries no query, and none should be able to terminate the app outright.
    var hotKeyAction: HotKeyAction? {
        isQueryDriven || self == .quit ? nil : .command(self)
    }
}
