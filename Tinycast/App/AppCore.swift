import AppKit

/// Single owner of every long-lived manager. Wired up once from the app delegate.
@MainActor
@Observable
final class AppCore {
    static let shared = AppCore()

    let launcherRanking: LauncherRankingStore
    let appIndex: AppIndex
    let customCommands = CustomCommandStore()
    let quicklinks = QuicklinkStore()
    let windowLayouts = WindowLayoutStore()
    let customWindowSizes = CustomWindowSizeStore()
    let rooms = RoomStore()
    let roomMinimums = RoomMinimumSizeStore()
    let roomParking = RoomParkingLedger(
        fileURL: AppPaths.applicationSupport().appendingPathComponent("room-parking.json"))
    let roomSession = RoomSession()
    let textInjector: TextInjector
    let hotKeys = HotKeyManager()
    @ObservationIgnored private(set) lazy var hyperKey = HyperKeyManager(
        settings: settings, hotKeys: hotKeys)
    let windowMover = WindowMover()
    let spaceSwitcher = SpaceSwitcher()
    let inputSourceSwitcher = InputSourceSwitcher()
    let settings: AppSettings
    /// Mirrors settings into settings.json; nil while the Backup pane's switch is off.
    @ObservationIgnored private var settingsFile: SettingsFileRepository?
    @ObservationIgnored private(set) lazy var settingsBindings = makeSettingsBindings()
    @ObservationIgnored private var appearanceObservation: NSKeyValueObservation?
    @ObservationIgnored private let iconStyle = IconStyleMonitor()
    let favorites = FavoritesStore()
    let visibility = VisibilityStore()
    let aliases = AliasStore()
    let fallbacks = FallbackStore()
    let calcHistory = CalculatorHistoryStore()
    let currencyRates = CurrencyRateStore()
    let regionNumberFormat = RegionNumberFormatMonitor()
    let runningApps = RunningAppsMonitor()
    let palette = PaletteState()
    let fileIndexer = FileIndexer()
    @ObservationIgnored private(set) lazy var fileSearch = FileSearchSession(index: fileIndexer.index)
    let dictionary = DictionarySession()
    let menuSearch = MenuSearchSession()
    let windowSwitch = WindowSwitchSession()
    let activationPolicy = ActivationPolicy()

    /// Set when a layout editor should open with Settings; the pane consumes it.
    var pendingWindowLayoutEdit: WindowLayoutEditRequest?

    @ObservationIgnored private(set) lazy var quicklinkCoordinator = QuicklinkCoordinator(
        store: quicklinks, settings: settings,
        appIndex: appIndex, injector: textInjector, hotKeys: hotKeys, favorites: favorites,
        visibility: visibility, ranking: launcherRanking, aliases: aliases,
        windowController: windowController,
        paletteCoordinator: paletteCoordinator,
        clipboardHistory: { NSPasteboard.general.string(forType: .string).map { [$0] } ?? [] },
        core: self)

    @ObservationIgnored private(set) lazy var paletteCoordinator = PaletteCoordinator(
        palette: palette, settings: settings, appIndex: appIndex,
        fileSearch: fileSearch, menuSearch: menuSearch, windowSwitch: windowSwitch,
        windowController: windowController)
    /// Its own window and lifecycle: neither coordinator shows or closes the other's surface.
    @ObservationIgnored private(set) lazy var settingsCoordinator = SettingsCoordinator(core: self)
    @ObservationIgnored private(set) lazy var onboardingCoordinator = OnboardingCoordinator(
        core: self)
    @ObservationIgnored private(set) lazy var systemActionCoordinator = SystemActionCoordinator(
        paletteCoordinator: paletteCoordinator, core: self)
    @ObservationIgnored private(set) lazy var windowCommandCoordinator = WindowCommandCoordinator(
        settings: settings, paletteCoordinator: paletteCoordinator, windowMover: windowMover,
        spaceSwitcher: spaceSwitcher, customSizes: customWindowSizes)
    @ObservationIgnored private(set) lazy var customWindowSizeCoordinator =
        CustomWindowSizeCoordinator(
            store: customWindowSizes, settings: settings, appIndex: appIndex, hotKeys: hotKeys,
            favorites: favorites, visibility: visibility, ranking: launcherRanking,
            aliases: aliases, core: self)
    @ObservationIgnored private(set) lazy var windowShortcutPresetCoordinator =
        WindowShortcutPresetCoordinator(hotKeys: hotKeys, core: self)
    @ObservationIgnored private(set) lazy var windowLayoutCoordinator = WindowLayoutCoordinator(
        store: windowLayouts, settings: settings, appIndex: appIndex, hotKeys: hotKeys,
        favorites: favorites, visibility: visibility, ranking: launcherRanking, aliases: aliases,
        paletteCoordinator: paletteCoordinator, settingsCoordinator: settingsCoordinator,
        core: self)
    @ObservationIgnored private(set) lazy var roomCoordinator = RoomCoordinator(
        store: rooms, minimums: roomMinimums, ledger: roomParking, session: roomSession,
        settings: settings, appIndex: appIndex, hotKeys: hotKeys, favorites: favorites,
        visibility: visibility, ranking: launcherRanking, aliases: aliases, palette: palette,
        paletteCoordinator: paletteCoordinator, core: self)
    @ObservationIgnored private(set) lazy var customCommandCoordinator = CustomCommandCoordinator(
        store: customCommands, settings: settings, appIndex: appIndex,
        paletteCoordinator: paletteCoordinator, settingsCoordinator: settingsCoordinator,
        hotKeys: hotKeys, favorites: favorites, visibility: visibility,
        ranking: launcherRanking, aliases: aliases, activationPolicy: activationPolicy, core: self)
    @ObservationIgnored private(set) lazy var appleShortcutCoordinator = AppleShortcutCoordinator(
        settings: settings, appIndex: appIndex, hotKeys: hotKeys, favorites: favorites,
        visibility: visibility, ranking: launcherRanking, aliases: aliases,
        paletteCoordinator: paletteCoordinator, core: self)

    @ObservationIgnored private(set) lazy var launcherCoordinator = LauncherCoordinator(
        ranking: launcherRanking, windowController: windowController,
        paletteCoordinator: paletteCoordinator,
        settingsCoordinator: settingsCoordinator,
        customCommandCoordinator: customCommandCoordinator,
        systemActionCoordinator: systemActionCoordinator,
        quicklinkCoordinator: quicklinkCoordinator,
        windowCommandCoordinator: windowCommandCoordinator,
        windowLayoutCoordinator: windowLayoutCoordinator,
        fileSearchCoordinator: fileSearchCoordinator,
        menuSearchCoordinator: menuSearchCoordinator,
        windowSwitchCoordinator: windowSwitchCoordinator,
        core: self)
    @ObservationIgnored private(set) lazy var fallbackCoordinator = FallbackCoordinator(
        store: fallbacks, quicklinks: quicklinks, settings: settings, visibility: visibility,
        core: self)
    @ObservationIgnored private(set) lazy var calculatorCoordinator = CalculatorCoordinator(
        calcHistory: calcHistory, paletteCoordinator: paletteCoordinator, core: self)
    @ObservationIgnored private(set) lazy var fileSearchCoordinator = FileSearchCoordinator(
        settings: settings, appIndex: appIndex, session: fileSearch, indexer: fileIndexer,
        palette: palette, paletteCoordinator: paletteCoordinator,
        windowController: windowController, core: self)
    @ObservationIgnored private(set) lazy var menuSearchCoordinator = MenuSearchCoordinator(
        settings: settings, appIndex: appIndex, session: menuSearch, palette: palette,
        paletteCoordinator: paletteCoordinator, core: self)
    @ObservationIgnored private(set) lazy var windowSwitchCoordinator = WindowSwitchCoordinator(
        settings: settings, appIndex: appIndex, session: windowSwitch, palette: palette,
        paletteCoordinator: paletteCoordinator, core: self)
    @ObservationIgnored private(set) lazy var cameraCoordinator = CameraCoordinator(core: self)
    @ObservationIgnored private(set) lazy var dictionaryCoordinator = DictionaryCoordinator(
        paletteCoordinator: paletteCoordinator)

    @ObservationIgnored private lazy var windowController = PaletteWindowController(core: self)
    @ObservationIgnored private lazy var messageHUD = MessageHUDController(settings: settings)
    private(set) var isShowingDialog = false
    var isDimmingPaletteForDialog: Bool { isShowingDialog && windowController.isVisible }
    @ObservationIgnored private lazy var dialogs = DialogController(
        settings: settings,
        onPresentationChanged: { [weak self] isPresenting in
            guard let self else { return }
            isShowingDialog = isPresenting
        })
    private let healthTicker = HealthTicker()
    /// Resolved once by AppKit, so it is what this process shows until it relaunches.
    private let launchLocalization = Bundle.main.preferredLocalizations.first
    private var relaunchRequested = false

    private init() {
        let launcherRanking = LauncherRankingStore()
        let settings = AppSettings()
        self.launcherRanking = launcherRanking
        self.settings = settings
        appIndex = AppIndex(ranking: launcherRanking, aliases: aliases)
        textInjector = TextInjector()
    }

    func start(launchedByUser: Bool) {
        Signposts.interval("AppCore.start") {
            // Shorten AppKit's ~2–3s tooltip delay; registration domain, so a user default wins.
            UserDefaults.standard.register(defaults: ["NSInitialToolTipDelay": 250])
            NSApp.setActivationPolicy(.accessory)
            applyAppearance()
            applyMotion()
            observeEffectiveAppearance()

            appIndex.start(settings: settings)
            fileSearchCoordinator.applyEnabled()
            windowSwitchCoordinator.applyEnabled()
            menuSearchCoordinator.applyEnabled()
            fileSearchCoordinator.applyPolicy()
            customCommands.onChange = { [weak self] _ in
                self?.customCommandCoordinator.applyCustomCommandsPresence()
            }
            customCommandCoordinator.applyCustomCommandsPresence()
            applyWindowCommandsPresence()
            customWindowSizes.onChange = { [weak self] _ in
                self?.customWindowSizeCoordinator.applyCustomWindowSizesPresence()
            }
            customWindowSizeCoordinator.applyCustomWindowSizesPresence()
            windowLayouts.onChange = { [weak self] _ in
                self?.windowLayoutCoordinator.applyWindowLayoutsPresence()
            }
            windowLayoutCoordinator.applyWindowLayoutsPresence()
            rooms.onChange = { [weak self] _ in self?.roomCoordinator.applyRoomsPresence() }
            roomCoordinator.applyRoomsPresence()
            // A crash can leave windows parked off-screen; they come home before anything else.
            roomCoordinator.recoverParkedWindows()
            quicklinks.onChange = { [weak self] _ in
                self?.quicklinkCoordinator.applyQuicklinksPresence()
            }
            // Before `hotKeys.start` even when off: the prune reads it. docs/features/quicklinks.md
            quicklinks.load()
            quicklinkCoordinator.applyQuicklinksPresence()
            appleShortcutCoordinator.applyPresence()
            paletteCoordinator.onLauncherShown = { [weak self] in
                self?.appleShortcutCoordinator.refresh()
            }
            paletteCoordinator.onScreenOpening = { [weak self] mode in
                switch mode {
                case .menuSearch: self?.menuSearchCoordinator.load()
                case .switchWindows: self?.windowSwitchCoordinator.load()
                case .rooms, .roomWindows: self?.roomCoordinator.load()
                default: break
                }
            }
            Task { await appIndex.refresh() }
            currencyRates.start()

            hyperKey.healthTicker = healthTicker
            hotKeys.modifierTapMonitor.healthTicker = healthTicker

            hotKeys.onTogglePalette = { [weak self] in self?.paletteCoordinator.togglePalette() }
            hotKeys.onRunCommand = { [weak self] id in self?.launcherCoordinator.runCommand(id) }
            hotKeys.onRunCustomCommand = { [weak self] id in
                self?.customCommandCoordinator.runCustomCommand(id: id)
            }
            hotKeys.onRunSystemAction = { [weak self] id in
                self?.systemActionCoordinator.runSystemAction(id: id)
            }
            hotKeys.onRunWindowCommand = { [weak self] id in
                self?.windowCommandCoordinator.runWindowCommand(id: id)
            }
            hotKeys.onRunWindowLayout = { [weak self] id in
                self?.windowLayoutCoordinator.runWindowLayout(id: id)
            }
            hotKeys.onEnterRoom = { [weak self] id in self?.roomCoordinator.enterRoom(id: id) }
            hotKeys.onRunCustomWindowSize = { [weak self] id in
                self?.windowCommandCoordinator.runCustomWindowSize(id: id)
            }
            hotKeys.onOpenQuicklink = { [weak self] id in
                self?.quicklinkCoordinator.openQuicklinkFromHotKey(id: id)
            }
            hotKeys.onRunAppleShortcut = { [weak self] id in
                self?.appleShortcutCoordinator.run(id: id)
            }
            appIndex.onScan = { [weak self] in
                guard let self else { return }
                hotKeys.removeAppBindings(where: appIndex.isUninstalled)
                // After the first scan, so the file's apps and panes have entries to match.
                if settings.settingsFileEnabled, settingsFile == nil {
                    startSettingsFile(importing: true)
                } else {
                    let issues = settingsBindings.launcher.applyInstalled()
                    if settingsFile != nil { reportSettingsFileIssues(issues) }
                }
            }
            hotKeys.displayName = { [weak self] action in self?.hotKeyDisplayName(for: action) }
            hotKeys.allowsAction = { [weak self] in self?.allowsHotKeyAction($0) ?? false }
            KeyShortcut.displayedHyperChord = { [settings] in
                guard settings.hyperKey != .none else { return nil }
                return KeyShortcut.hyperChord(includesShift: settings.hyperKeyIncludesShift)
            }
            SystemActionRunner.onAsyncFailure = { [weak self] id, failure in
                self?.systemActionCoordinator.presentSystemActionFailure(id: id, failure: failure)
            }
            hotKeys.start(
                customCommandIDs: Set(customCommands.commands.map(\.id)),
                quicklinkIDs: Set(quicklinks.quicklinks.map(\.id)),
                windowLayoutIDs: Set(windowLayouts.layouts.map(\.id)),
                windowRoomIDs: Set(rooms.rooms.map(\.id)),
                customWindowSizeIDs: Set(customWindowSizes.sizes.map(\.id)))
            trackHotKeyAllowance()
            // After `hotKeys.start`: Secure Input equivalents are built from the loaded bindings.
            hyperKey.onProblem = { [weak self] in self?.showMessage($0, tone: .danger) }
            hyperKey.start()

            observeFeatureSwitches()

            // First launch binds no hotkey, so guide once; the marker is written at show-time.
            if !OnboardingState.hasOnboarded {
                OnboardingState.markShown()
                onboardingCoordinator.showOnboarding()
            } else if launchedByUser {
                paletteCoordinator.showPalette(mode: .launcher)
            }
        }
    }

    func handleReopen() {
        if settingsCoordinator.focusExisting() { return }
        if onboardingCoordinator.focusExisting() { return }
        if customCommandCoordinator.focusOutputWindow() { return }
        paletteCoordinator.showPalette(mode: .launcher, restoreAnyMode: true)
    }

    func allowsHotKeyAction(_ action: HotKeyAction) -> Bool {
        guard visibility.allowsHotKey(action) else { return false }
        // A disabled feature drops its commands from the launcher; their shortcuts go too.
        switch action {
        case .command(let id): return appIndex.isCommandEnabled(id)
        case .windowCommand, .customWindowSize, .windowLayout, .windowRoom:
            return settings.windowManagementEnabled
        case .customCommand(let id):
            return settings.customCommandsEnabled && customCommands.command(id: id)?.isEnabled == true
        case .quicklink(let id):
            return settings.quicklinksEnabled && quicklinks.quicklink(id: id)?.isEnabled == true
        case .appleShortcut: return settings.appleShortcutsEnabled
        case .togglePalette, .app, .settingsPane, .systemAction: return true
        }
    }

    /// The store-backed half of the conflict message; `HotKeyManager` names the catalogs itself.
    private func hotKeyDisplayName(for action: HotKeyAction) -> String? {
        switch action {
        case .app(let bundleID):
            return appIndex.apps.first { $0.kind == .application && $0.bundleID == bundleID }?.name
        case .settingsPane(let bundleID):
            return appIndex.apps.first { $0.kind == .systemSettings && $0.bundleID == bundleID }?
                .name
        case .customCommand(let id):
            return customCommands.command(id: id)?.name
        case .quicklink(let id):
            return quicklinks.quicklink(id: id)?.name
        case .windowLayout(let id):
            return windowLayouts.layout(id: id)?.name
        case .windowRoom(let id):
            return rooms.room(id: id)?.name
        case .customWindowSize(let id):
            return customWindowSizes.size(id: id)?.name
        case .appleShortcut(let id):
            return appleShortcutCoordinator.name(of: id)
        case .togglePalette, .command, .systemAction, .windowCommand:
            return nil
        }
    }

    func relaunch() {
        guard !relaunchRequested else { return }
        relaunchRequested = true
        // AppKit's termination loop must start outside a Swift task or dispatch callback.
        RunLoop.main.perform(inModes: [.common]) {
            MainActor.assumeIsolated { NSApp.terminate(nil) }
        }
    }

    func prepareForTermination() {
        settingsFile?.flush()
        // Caps Lock first: its remap is the one teardown that outlives the process.
        hyperKey.prepareForTermination()
        windowLayoutCoordinator.prepareForTermination()
        roomCoordinator.prepareForTermination()
        inputSourceSwitcher.endSession()
        if relaunchRequested { RelaunchRunner.relaunchAfterExit(Bundle.main.bundleURL) }
    }

    // MARK: - Feature switches

    private func observeFeatureSwitches() {
        track(
            {
                _ = $0.windowManagementEnabled
                _ = $0.windowManagementShowInLauncher
            },
            reproject: {
                $0.applyWindowCommandsPresence()
                $0.customWindowSizeCoordinator.applyCustomWindowSizesPresence()
            })
        track(
            {
                _ = $0.windowManagementEnabled
                _ = $0.windowLayoutsShowInLauncher
            }, reproject: { $0.windowLayoutCoordinator.applyWindowLayoutsPresence() })
        track(
            {
                _ = $0.windowManagementEnabled
                _ = $0.windowRoomsShowInLauncher
            }, reproject: { $0.roomCoordinator.applyEnabled() })
        track(
            {
                _ = $0.customCommandsEnabled
                _ = $0.customCommandsShowInLauncher
            }, reproject: { $0.customCommandCoordinator.applyCustomCommandsPresence() })
        track(
            {
                _ = $0.quicklinksEnabled
                _ = $0.quicklinksShowInLauncher
            }, reproject: { $0.quicklinkCoordinator.applyQuicklinksPresence() })
        track(
            { _ = $0.appleShortcutsEnabled },
            reproject: { $0.appleShortcutCoordinator.applyPresence() })
        track({ _ = $0.fileSearchEnabled }, reproject: { $0.fileSearchCoordinator.applyEnabled() })
        track(
            { _ = $0.fileSearchShowInLauncher },
            reproject: { $0.fileSearchCoordinator.applyLauncherFiles() })
        // Two features, one switch: each coordinator gates only its own command and mode.
        track(
            { _ = $0.navigationEnabled },
            reproject: {
                $0.windowSwitchCoordinator.applyEnabled()
                $0.menuSearchCoordinator.applyEnabled()
            })
        track(
            {
                _ = $0.fileSearchScopes
                _ = $0.fileSearchIncludesHiddenFiles
                _ = $0.fileSearchIgnorePatterns
                _ = $0.fileSearchRemovedDefaultPatterns
            }, reproject: { $0.fileSearchCoordinator.applyPolicy() })
        // Not a feature switch, but the same re-projection: a combo has the chord's ⇧ bit baked in.
        track({ _ = $0.hyperKeyIncludesShift }, reproject: { $0.applyHyperChord() })
        track({ _ = $0.appearance }, reproject: { $0.applyAppearance() })
        track({ _ = $0.animationsEnabled }, reproject: { $0.applyMotion() })
        track({ _ = $0.language }, reproject: { $0.offerLanguageRelaunch() })
        track({ _ = $0.interfaceSize }, reproject: { $0.windowController.applyInterfaceSize() })
    }

    /// `.system` resolves to `nil`, so AppKit follows macOS with nothing polling.
    private func applyAppearance() {
        NSApp.appearance = settings.appearance.nsAppearance
    }

    /// A built panel keeps the behaviour it was made with, so the live ones are re-pointed.
    private func applyMotion() {
        Motion.isEnabled = settings.animationsEnabled
        for case let panel as any AnimatedPanel in NSApp.windows {
            panel.followMotion()
        }
    }

    private var isLanguagePending: Bool { settings.language.rawValue != launchLocalization }

    private func offerLanguageRelaunch() {
        guard isLanguagePending else { return }
        Task {
            guard
                await confirm(
                    title: String(localized: "Relaunch Tinycast?"),
                    message: String(localized: "The new language applies after Tinycast relaunches."),
                    symbol: "globe", confirmTitle: String(localized: "Relaunch"), tone: .neutral,
                    confirmRole: .standard, dismissTitle: String(localized: "Later")),
                isLanguagePending
            else { return }
            relaunch()
        }
    }

    /// IconCache is told here, not from `applyAppearance()`, which never fires under `.system`.
    private func observeEffectiveAppearance() {
        // Synchronous on main, so no row can cache a tile under the outgoing appearance's key.
        appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.initial]) { app, _ in
            MainActor.assumeIsolated { IconCache.setDarkSurface(app.effectiveAppearance.isDark) }
        }
    }

    private func track(
        _ reads: @escaping @Sendable @MainActor (AppSettings) -> Void,
        reproject: @escaping @Sendable @MainActor (AppCore) -> Void
    ) {
        track(settings, reads, reproject: reproject)
    }

    /// Fires synchronously on main before the write lands, so the task re-arms and re-reads.
    private func track<Store: AnyObject & Sendable>(
        _ store: Store,
        _ reads: @escaping @Sendable @MainActor (Store) -> Void,
        reproject: @escaping @Sendable @MainActor (AppCore) -> Void
    ) {
        withObservationTracking {
            reads(store)
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.track(store, reads, reproject: reproject)
                reproject(self)
            }
        }
    }

    /// Re-arms on whatever `allowsHotKeyAction` read: feature switches and visibility.
    private func trackHotKeyAllowance() {
        withObservationTracking {
            hotKeys.applyAllowance()
        } onChange: { [weak self] in
            Task { @MainActor in self?.trackHotKeyAllowance() }
        }
    }

    /// Without a Hyper key the chord means nothing, so a literal ⌃⌥⌘ combo is left as recorded.
    private func applyHyperChord() {
        guard settings.hyperKey != .none else { return }
        hotKeys.retargetHyperBindings(includesShift: settings.hyperKeyIncludesShift)
    }

    private func applyWindowCommandsPresence() {
        let visible = settings.windowManagementEnabled && settings.windowManagementShowInLauncher
        appIndex.setWindowCommandsVisible(visible)
    }

    // MARK: - Settings file

    /// Mirrors settings into settings.json from now on; `importing` applies the file's own first.
    func startSettingsFile(importing: Bool) {
        guard settingsFile == nil else { return }
        let file = SettingsFileRepository(
            fileURL: AppPaths.settingsFile(), bindings: settingsBindings.bindings,
            commit: settingsBindings.commit)
        file.onIssues = { [weak self] issues in self?.reportSettingsFileIssues(issues) }
        settingsFile = file
        settings.settingsFileEnabled = true
        file.start(importing: importing)
    }

    /// Stops the mirror; the file stays on disk as last written.
    func stopSettingsFile() {
        settingsFile?.flush()
        settingsFile = nil
        settings.settingsFileEnabled = false
    }

    private func makeSettingsBindings() -> SettingsBindingSet {
        let shortcuts = HotKeySettingsFile(hotKeys: hotKeys)
        let launcher = LauncherSettingsFile(
            appIndex: appIndex, aliases: aliases, visibility: visibility, shortcuts: shortcuts)
        let bindings = SettingsFileSchema.bindings(
            settings: settings,
            shortcuts: shortcuts, launcher: launcher,
            windowManagement: WindowManagementSettingsFile(
                sizes: customWindowSizes, layouts: windowLayouts, rooms: rooms, aliases: aliases,
                shortcuts: shortcuts))
        return SettingsBindingSet(bindings: bindings, commit: shortcuts.commit, launcher: launcher)
    }

    private func reportSettingsFileIssues(_ issues: [SettingsFileIssue]) {
        guard let summary = SettingsFileIssue.summary(issues) else { return }
        showMessage(summary, tone: .danger)
    }

    // MARK: - Dialogs, routed here so `dialogs` stays the single owner

    func showNotice(title: String, message: String, symbol: String, tone: DialogTone) async {
        await dialogs.notice(title: title, message: message, symbol: symbol, tone: tone)
    }

    /// `tone` styles the glyph, `confirmRole` the button; separate on purpose.
    func confirm(
        title: String, message: String?, symbol: String?, confirmTitle: String,
        tone: DialogTone = .danger, confirmRole: DialogAction.Role = .destructive,
        dismissTitle: String = String(localized: "Cancel")
    ) async -> Bool {
        await dialogs.confirm(
            title: title, message: message, symbol: symbol, tone: tone, confirmTitle: confirmTitle,
            confirmRole: confirmRole, dismissTitle: dismissTitle)
    }

    /// A question with more than two answers; the returned index is into `options`.
    func choose(
        title: String, message: String?, symbol: String?, options: [DialogAction],
        defaultIndex: Int, tone: DialogTone = .neutral
    ) async -> Int {
        await dialogs.choose(
            title: title, message: message, symbol: symbol, tone: tone, options: options,
            defaultIndex: defaultIndex)
    }

    /// A failure with one usable second option; `true` when the user takes it.
    func reportFailure(
        title: String, message: String, symbol: String, recovery: String?
    ) async
        -> Bool
    {
        await dialogs.reportFailure(
            title: title, message: message, symbol: symbol, recovery: recovery)
    }

    /// The transient success/info pill, so `messageHUD` stays single-owned alongside `dialogs`.
    func showMessage(_ message: String, tone: DialogTone = .success) {
        messageHUD.show(message: message, tone: tone)
    }

    /// The same pill with a spinner, for work the reader started and cannot otherwise see running.
    func showProgress(_ message: String, onCancel: (() -> Void)? = nil) {
        messageHUD.showProgress(message: message, onCancel: onCancel)
    }

    func hideProgress() {
        messageHUD.dismiss()
    }

    func pickVolume(current: Float32) async -> Float32? {
        await dialogs.pickVolume(current: current)
    }
}
