enum SettingsTab: CaseIterable, Identifiable {
    case general, applications, systemSettings, systemActions, commands, quicklinks,
        appleShortcuts,
        fallbacks, fileSearch, windowManagement, navigation,
        permissions, backup, about
    /// The case, never an index: a selectable `List` flattens section and row IDs together.
    var id: Self { self }

    init?(slug: String) {
        guard let tab = Self.allCases.first(where: { $0.slug == slug }) else { return nil }
        self = tab
    }

    /// `tinycast://settings/<slug>`; spelled out, so renaming a case never breaks a saved link.
    var slug: String {
        switch self {
        case .general: "general"
        case .applications: "applications"
        case .systemSettings: "system-settings"
        case .systemActions: "system-actions"
        case .commands: "commands"
        case .quicklinks: "quicklinks"
        case .appleShortcuts: "apple-shortcuts"
        case .fallbacks: "fallbacks"
        case .fileSearch: "file-search"
        case .windowManagement: "window-management"
        case .navigation: "navigation"
        case .permissions: "permissions"
        case .backup: "backup"
        case .about: "about"
        }
    }

    var title: String {
        switch self {
        case .general: return String(localized: "General")
        case .applications: return String(localized: "Applications")
        case .systemSettings: return String(localized: "System Settings")
        case .systemActions: return String(localized: "System Actions")
        case .commands: return String(localized: "Commands")
        case .quicklinks: return String(localized: "Quicklinks")
        case .appleShortcuts: return String(localized: "Apple Shortcuts")
        case .fallbacks: return String(localized: "Fallbacks")
        case .fileSearch: return String(localized: "File Search")
        case .navigation: return String(localized: "Navigation")
        case .windowManagement: return String(localized: "Window Management")
        case .permissions: return String(localized: "Permissions")
        case .backup: return String(localized: "Backup")
        case .about: return String(localized: "About")
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "switch.2"
        case .applications: return "square.grid.2x2.fill"
        case .systemSettings: return "gearshape.fill"
        case .systemActions: return "bolt.fill"
        case .commands: return "terminal.fill"
        case .quicklinks: return "link"
        case .appleShortcuts: return "square.2.layers.3d.fill"
        case .fallbacks: return "arrow.turn.down.right"
        case .fileSearch: return "doc.text.magnifyingglass"
        case .navigation: return "arrow.left.arrow.right"
        case .windowManagement: return "macwindow"
        case .permissions: return "lock.shield.fill"
        case .backup: return "arrow.up.arrow.down.circle.fill"
        case .about: return "info.circle.fill"
        }
    }

    var tint: IconTint {
        switch self {
        case .general, .systemSettings, .fallbacks, .about: return .gray
        case .commands, .navigation: return .graphite
        case .permissions, .quicklinks, .fileSearch: return .blue
        case .applications, .backup: return .cyan
        case .windowManagement: return .mint
        case .systemActions: return .orange
        case .appleShortcuts: return .pink
        }
    }
}

/// Declaration order is display order; not `.Section`, which would shadow SwiftUI's `Section`.
enum SettingsSection: CaseIterable, Identifiable {
    case general, launcher, features, advanced
    /// See `SettingsTab.id`: distinct types keep the two namespaces from colliding.
    var id: Self { self }

    var title: String {
        switch self {
        case .general: return String(localized: "General")
        case .launcher: return String(localized: "Launcher")
        case .features: return String(localized: "Features")
        case .advanced: return String(localized: "Advanced")
        }
    }

    var tabs: [SettingsTab] {
        switch self {
        case .general: return [.general, .permissions]
        case .launcher:
            return [
                .applications, .systemSettings, .systemActions, .commands, .quicklinks,
                .appleShortcuts, .fallbacks
            ]
        case .features:
            return [
                .fileSearch, .windowManagement, .navigation
            ]
        case .advanced: return [.backup, .about]
        }
    }
}
