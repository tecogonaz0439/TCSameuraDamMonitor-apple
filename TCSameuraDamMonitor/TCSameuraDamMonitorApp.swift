// SPDX-FileCopyrightText: 2026 tecogonaz <tecogonaz@kusugami-lab.net>
// SPDX-License-Identifier: Apache-2.0

import SwiftUI
import SwiftData

#if os(macOS)
import AppKit
#endif

#if os(iOS)
import UIKit
import UserNotifications

@MainActor
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([])
    }
}
#endif

#if os(macOS)
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if MacMainWindowPresenter.presentMainWindowForDockReopen(in: sender) {
            return false
        }
        sender.activate(ignoringOtherApps: true)
        return true
    }
}
#endif

@main
struct TCSameuraDamMonitorApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    private static let mainWindowID = "main-window"
    private static let widgetURLScheme = "tcsameuradammonitor"
    /// 起動時に確定したメニューバー常駐モード。`defaultLaunchBehavior` の起動時評価専用であり、設定変更では更新しない。
    private let launchMenuBarResidencyMode: MenuBarResidencyMode
    #endif
    @State private var appModel: DamAppModel
    var sharedModelContainer: ModelContainer?
    var persistenceFailureMessage: String?

    init() {
        #if DEBUG
        if let uiTestConfiguration = UITestLaunchSupport.currentConfiguration {
            uiTestConfiguration.prepareDefaults()
            let container = (try? Self.makeInMemoryModelContainer()) ?? (try! Self.makeInMemoryModelContainer())
            uiTestConfiguration.seed(modelContainer: container)
            let uiTestModel = uiTestConfiguration.makeAppModel()
            _appModel = State(initialValue: uiTestModel)
            #if os(macOS)
            launchMenuBarResidencyMode = uiTestModel.settings.menuBarResidencyMode
            #endif
            sharedModelContainer = container
            persistenceFailureMessage = nil
            return
        }
        #endif

        let model = DamAppModel()
        do {
            let container = try Self.makeModelContainer()
            #if os(macOS)
            model.configure(modelContext: ModelContext(container), launchContext: .foreground)
            #endif
            _appModel = State(initialValue: model)
            #if os(macOS)
            launchMenuBarResidencyMode = model.settings.menuBarResidencyMode
            #endif
            sharedModelContainer = container
            persistenceFailureMessage = nil
        } catch {
            _appModel = State(initialValue: model)
            #if os(macOS)
            launchMenuBarResidencyMode = model.settings.menuBarResidencyMode
            #endif
            sharedModelContainer = try? Self.makeInMemoryModelContainer()
            persistenceFailureMessage = error.localizedDescription
        }
    }

    private static var modelSchema: Schema {
        Schema([
            DamDataRecord.self,
            HistoricalSearchMetaRecord.self,
            HistoricalDamDataRecord.self,
            SudmonitorHistoryRecord.self,
            DebugLogRecord.self,
        ])
    }

    #if os(macOS)
    private static var persistentStoreBaseName: String {
        "net.tecogonaz.TCSameuraDamMonitor/default"
    }
    #else
    private static var persistentStoreBaseName: String {
        "net.tecogonaz.TCSameuraDamMonitor"
    }
    #endif

    static func makeModelContainer() throws -> ModelContainer {
        let schema = modelSchema
        prepareApplicationSupportDirectory()
        #if os(macOS)
        let storeURL: URL
        if let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let parentDir = baseURL.appendingPathComponent("net.tecogonaz.TCSameuraDamMonitor", isDirectory: true)
            try? FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
            storeURL = parentDir.appendingPathComponent("default.store")
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            let parentDir = home.appendingPathComponent("Library/Application Support/net.tecogonaz.TCSameuraDamMonitor", isDirectory: true)
            try? FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
            storeURL = parentDir.appendingPathComponent("default.store")
        }
        let modelConfiguration = ModelConfiguration(schema: schema, url: storeURL)
        #else
        let modelConfiguration = ModelConfiguration(persistentStoreBaseName, schema: schema, isStoredInMemoryOnly: false)
        #endif
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            try Self.backUpPersistentStoresAfterModelContainerFailure()
            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                throw error
            }
        }
    }

    private static func prepareApplicationSupportDirectory() {
        guard let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        let dir = baseURL.appendingPathComponent("net.tecogonaz.TCSameuraDamMonitor", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        excludeFromBackup(dir)
    }

    private static func makeInMemoryModelContainer() throws -> ModelContainer {
        let schema = modelSchema
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    }

    private static func backUpPersistentStoresAfterModelContainerFailure() throws {
        let fileManager = FileManager.default
        let supportDirectories = persistentStoreSupportDirectoryCandidates(fileManager: fileManager)
        guard !supportDirectories.isEmpty else {
            return
        }

        let timestamp = Self.persistentStoreBackupTimestamp()
        var firstError: Error?
        for supportDirectory in supportDirectories {
            let storeFiles = persistentStoreFileURLs(in: supportDirectory, fileManager: fileManager)
            guard !storeFiles.isEmpty else {
                continue
            }

            let backupDirectory = supportDirectory.appendingPathComponent("SwiftDataStoreBackup-\(timestamp)", isDirectory: true)
            do {
                try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
                excludeFromBackup(backupDirectory)
                for storeFile in storeFiles {
                    let destination = backupDirectory.appendingPathComponent(storeFile.lastPathComponent)
                    if fileManager.fileExists(atPath: destination.path) {
                        try fileManager.removeItem(at: destination)
                    }
                    try fileManager.moveItem(at: storeFile, to: destination)
                }
            } catch {
                firstError = firstError ?? error
            }
        }

        if let firstError {
            throw firstError
        }
    }

    private static func persistentStoreSupportDirectoryCandidates(fileManager: FileManager) -> [URL] {
        var directories: [URL] = []
        if let appSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            directories.append(appSupportDirectory)
        }
        if let appGroupDirectory = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.net.tecogonaz.TCSameuraDamMonitor")?
            .appendingPathComponent("Library/Application Support", isDirectory: true) {
            directories.append(appGroupDirectory)
        }

        var seenPaths = Set<String>()
        return directories.filter { directory in
            seenPaths.insert(directory.standardizedFileURL.path).inserted
        }
    }

    private static func persistentStoreFileURLs(in supportDirectory: URL, fileManager: FileManager) -> [URL] {
        let fileNames = [
            "\(persistentStoreBaseName).store",
            "\(persistentStoreBaseName).store-shm",
            "\(persistentStoreBaseName).store-wal",
        ]
        return fileNames
            .map { supportDirectory.appendingPathComponent($0) }
            .filter { fileManager.fileExists(atPath: $0.path) }
    }

    private static func persistentStoreBackupTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    private static func excludeFromBackup(_ url: URL) {
        var resourceURL = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? resourceURL.setResourceValues(values)
    }

    var body: some Scene {
        #if os(macOS)
        mainWindowScene
        menuBarExtraScene
        #else
        WindowGroup {
            appRootContent
        }
        #endif
    }

    #if os(macOS)
    /// 型検査負荷を分散させるためのmacOS専用Scene分割。body直下は静的なScene合成のみとし、
    /// 実行時条件分岐 (SceneBuilderはif/if-else未対応) を排除する。
    private var mainWindowScene: some Scene {
        Window(AppText.appName, id: Self.mainWindowID) {
            appRootContent
                .frame(minWidth: MacLayout.minWindowWidth, minHeight: MacLayout.minWindowHeight)
                .background(MacMainWindowIdentifierView())
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
        .defaultSize(width: 1000, height: 700)
        .windowResizability(.contentMinSize)
        .defaultLaunchBehavior(launchBehavior)
        .commands {
            MacAppCommands(
                appModel: appModel,
                mainWindowID: Self.mainWindowID,
                canSelectMainWindowDetail: persistenceFailureMessage == nil
            )
        }
    }

    /// 起動時snapshotに基づくlaunch behavior。値レベルの切替えに留め、Scene分岐は行わない。
    /// `.automatic` は修飾子省略時の既定と等価だが、三項の両枝を明示して意図を固定する。
    private var launchBehavior: SceneLaunchBehavior {
        isLaunchSuppressed ? .suppressed : .automatic
    }

    /// 起動時snapshotに基づく単純Bool。三項演算子の引数を単純化するための抽出。
    private var isLaunchSuppressed: Bool {
        launchMenuBarResidencyMode == .residentHidden
    }

    /// MenuBarExtraは常時宣言し、表示有無はisInserted bindingで制御する
    /// (Sceneの実行時条件分岐はSceneBuilder未対応のため)。設定変更でアイコンのみ即時反映される。
    private var menuBarExtraScene: some Scene {
        MenuBarExtra(AppText.appName, image: "MenuBarIcon", isInserted: menuBarExtraInserted) {
            MenuBarContent(
                appModel: appModel,
                mainWindowID: Self.mainWindowID
            )
        }
        .menuBarExtraStyle(.menu)
    }

    /// 設定変更に即時追従するbinding。ユーザーがアイコンをメニューバーから除去した場合は
    /// 設定自体をnotResidentへ戻し、設定画面表示と一致させる。
    private var menuBarExtraInserted: Binding<Bool> {
        Binding(
            get: { appModel.settings.menuBarResidencyMode != .notResident },
            set: { isInserted in
                if !isInserted, appModel.settings.menuBarResidencyMode != .notResident {
                    appModel.updateSettings { $0.menuBarResidencyMode = .notResident }
                }
            }
        )
    }
    #endif

    @ViewBuilder
    private var appRootContent: some View {
        if let persistenceFailureMessage {
            optionalModelContainer {
                PersistenceFailureView(errorDescription: persistenceFailureMessage)
            }
        } else {
            optionalModelContainer {
                ContentView(appModel: appModel)
            }
        }
    }

    @ViewBuilder
    private func optionalModelContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if let sharedModelContainer {
            content().modelContainer(sharedModelContainer)
        } else {
            content()
        }
    }

    #if os(macOS)
    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == Self.widgetURLScheme else { return }
        MacMainWindowPresenter.presentMainWindow(id: Self.mainWindowID)
    }
    #endif
}

#if os(macOS)
private struct MacAppCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    let appModel: DamAppModel
    let mainWindowID: String
    let canSelectMainWindowDetail: Bool

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(AppText.menuAboutApp) {
                showMainWindow(selection: .appInfo)
            }
        }

        CommandGroup(replacing: .appSettings) {
            Button(AppText.menuSettings) {
                showMainWindow(selection: .settings)
            }
        }
    }

    private func showMainWindow(selection: DamAppModel.DetailSelection) {
        if canSelectMainWindowDetail {
            appModel.selectedDetail = selection
        }
        MacMainWindowPresenter.presentMainWindow(id: mainWindowID, openWindow: openWindow)
    }
}

private struct MenuBarContent: View {
    @Environment(\.openWindow) private var openWindow

    let appModel: DamAppModel
    let mainWindowID: String

    var body: some View {
        MenuBarRealtimeStatusView(appModel: appModel)
        Divider()
        Button(AppText.menuBarOpenMainWindow) {
            MacMainWindowPresenter.presentMainWindow(id: mainWindowID, openWindow: openWindow)
        }
        Button(AppText.menuBarQuit) {
            NSApplication.shared.terminate(nil)
        }
    }
}

private struct MenuBarRealtimeStatusView: View {
    let appModel: DamAppModel

    var body: some View {
        let lines = RealtimeStatusMenuLines.make(
            data: appModel.damData,
            damConfig: appModel.currentDamConfig,
            settings: appModel.settings,
            damLoadStatus: appModel.damLoadStatus
        )
        MenuBarStatusRow(text: lines.title)
        if let detail = lines.detail {
            let trendText = DamStatusMessageFormatter.trendText(lines.trend)
            let detailText = [detail, trendText]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            MenuBarStatusRow(text: detailText)
        }
        if let status = lines.status {
            MenuBarStatusRow(text: status)
        }
    }
}

private struct MenuBarStatusRow: View {
    let text: String

    var body: some View {
        Button {} label: {
            Text(text)
                .lineLimit(1)
                .frame(minWidth: 280, alignment: .leading)
                .foregroundStyle(.primary)
        }
    }
}

enum MacMainWindowPresenter {
    static let mainWindowIdentifier = NSUserInterfaceItemIdentifier("net.tecogonaz.TCSameuraDamMonitor.main-window")

    static func isMainWindow(identifier: NSUserInterfaceItemIdentifier?, title: String, expectedTitle: String = AppText.appName) -> Bool {
        identifier == mainWindowIdentifier || title == expectedTitle
    }

    static func isMainWindowMenuItem(title: String, expectedTitle: String = AppText.appName) -> Bool {
        title == expectedTitle
    }

    static func presentMainWindow(id: String, openWindow: OpenWindowAction? = nil) {
        if !presentExistingMainWindow(), let openWindow {
            openWindow(id: id)
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    static func presentMainWindowForDockReopen(in application: NSApplication = .shared) -> Bool {
        if presentExistingMainWindow(in: application) {
            return true
        }
        if performMainWindowMenuItem(in: application) {
            application.activate(ignoringOtherApps: true)
            return true
        }
        return false
    }

    static func presentExistingMainWindow(in application: NSApplication = .shared) -> Bool {
        guard let window = application.windows.first(where: { window in
            isMainWindow(identifier: window.identifier, title: window.title)
        }) else {
            return false
        }

        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        application.activate(ignoringOtherApps: true)
        return true
    }

    private static func performMainWindowMenuItem(in application: NSApplication) -> Bool {
        guard let windowsMenu = application.windowsMenu,
              let index = windowsMenu.items.firstIndex(where: { item in
            isMainWindowMenuItem(title: item.title)
        }) else {
            return false
        }
        windowsMenu.performActionForItem(at: index)
        return true
    }
}

private struct MacMainWindowIdentifierView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        MainWindowIdentifyingView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.window?.identifier = MacMainWindowPresenter.mainWindowIdentifier
    }
}

private final class MainWindowIdentifyingView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.identifier = MacMainWindowPresenter.mainWindowIdentifier
    }
}
#endif

private struct PersistenceFailureView: View {
    let errorDescription: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(AppText.persistenceFailureTitle)
                .font(.title2)
                .fontWeight(.semibold)
            Text(AppText.persistenceFailureMessage)
            Text(AppText.persistenceFailureDetail)
                .foregroundStyle(.secondary)
            Text(errorDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding()
        .frame(maxWidth: 520, alignment: .leading)
    }
}
