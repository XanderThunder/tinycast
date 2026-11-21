import Foundation

/// Every settings.json binding, built once for the settings file.
@MainActor
struct SettingsBindingSet {
    let bindings: [SettingsFileBinding]
    let commit: () -> [SettingsFileIssue]
    /// Kept to apply a waiting launcher record once its app is installed.
    let launcher: LauncherSettingsFile
}
