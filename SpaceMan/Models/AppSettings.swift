import Foundation

enum AppSettings {
    // MARK: - Keys (centralized to prevent typos)

    enum Key {
        static let showSplashScreen = "showSplashScreen"
        static let confirmBeforeDelete = "confirmBeforeDelete"
        static let includeHiddenFiles = "includeHiddenFiles"
        static let scanThreadCount = "scanThreadCount"
        static let defaultScanPath = "defaultScanPath"
        static let treemapMaxItems = "treemapMaxItems"
        static let showEmptyItems = "showEmptyItems"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let minimumFileSize = "minimumFileSize"
        static let skipPackageContents = "skipPackageContents"
        static let excludeNodeModules = "excludeNodeModules"
        static let excludeDerivedData = "excludeDerivedData"
        static let excludeGitDirs = "excludeGitDirs"
        static let skipSymlinks = "skipSymlinks"
        static let crossVolumeScan = "crossVolumeScan"
        static let duplicatesWarnAllSelected = "duplicatesWarnAllSelected"
        static let duplicatesConfirmBeforeDelete = "duplicatesConfirmBeforeDelete"
        static let forgottenFilesMinimumAge = "forgottenFilesMinimumAge"
    }

    // MARK: - Defaults

    enum Default {
        static let showSplashScreen = true
        static let confirmBeforeDelete = true
        static let includeHiddenFiles = true
        static let scanThreadCount = 8
        static let defaultScanPath = FileManager.default.homeDirectoryForCurrentUser.path
        static let treemapMaxItems = 120
        static let showEmptyItems = true
        static let minimumFileSize = 0  // bytes, 0 = disabled
        static let skipPackageContents = false
        static let excludeNodeModules = false
        static let excludeDerivedData = false
        static let excludeGitDirs = false
        static let skipSymlinks = true
        static let crossVolumeScan = false
        static let duplicatesWarnAllSelected = true
        static let duplicatesConfirmBeforeDelete = true
        static let forgottenFilesMinimumAge = 180  // days (6 months)
    }

    // MARK: - Static Readers (for non-view code)

    static var showSplashScreen: Bool {
        let ud = UserDefaults.standard
        return ud.object(forKey: Key.showSplashScreen) == nil
            ? Default.showSplashScreen
            : ud.bool(forKey: Key.showSplashScreen)
    }

    static var confirmBeforeDelete: Bool {
        let ud = UserDefaults.standard
        return ud.object(forKey: Key.confirmBeforeDelete) == nil
            ? Default.confirmBeforeDelete
            : ud.bool(forKey: Key.confirmBeforeDelete)
    }

    static var includeHiddenFiles: Bool {
        let ud = UserDefaults.standard
        return ud.object(forKey: Key.includeHiddenFiles) == nil
            ? Default.includeHiddenFiles
            : ud.bool(forKey: Key.includeHiddenFiles)
    }

    static var scanThreadCount: Int {
        let ud = UserDefaults.standard
        let val = ud.integer(forKey: Key.scanThreadCount)
        return val == 0 ? Default.scanThreadCount : val
    }

    static var defaultScanURL: URL {
        let path = UserDefaults.standard.string(forKey: Key.defaultScanPath)
            ?? Default.defaultScanPath
        return URL(fileURLWithPath: path)
    }

    static var treemapMaxItems: Int {
        let ud = UserDefaults.standard
        let val = ud.integer(forKey: Key.treemapMaxItems)
        return val == 0 ? Default.treemapMaxItems : val
    }

    static var hasCompletedOnboarding: Bool {
        UserDefaults.standard.bool(forKey: Key.hasCompletedOnboarding)
    }

    static var minimumFileSize: Int {
        let ud = UserDefaults.standard
        return ud.integer(forKey: Key.minimumFileSize)
    }

    static var skipPackageContents: Bool {
        let ud = UserDefaults.standard
        return ud.object(forKey: Key.skipPackageContents) == nil
            ? Default.skipPackageContents
            : ud.bool(forKey: Key.skipPackageContents)
    }

    static var excludeNodeModules: Bool {
        let ud = UserDefaults.standard
        return ud.object(forKey: Key.excludeNodeModules) == nil
            ? Default.excludeNodeModules
            : ud.bool(forKey: Key.excludeNodeModules)
    }

    static var excludeDerivedData: Bool {
        let ud = UserDefaults.standard
        return ud.object(forKey: Key.excludeDerivedData) == nil
            ? Default.excludeDerivedData
            : ud.bool(forKey: Key.excludeDerivedData)
    }

    static var excludeGitDirs: Bool {
        let ud = UserDefaults.standard
        return ud.object(forKey: Key.excludeGitDirs) == nil
            ? Default.excludeGitDirs
            : ud.bool(forKey: Key.excludeGitDirs)
    }

    static var skipSymlinks: Bool {
        let ud = UserDefaults.standard
        return ud.object(forKey: Key.skipSymlinks) == nil
            ? Default.skipSymlinks
            : ud.bool(forKey: Key.skipSymlinks)
    }

    static var crossVolumeScan: Bool {
        let ud = UserDefaults.standard
        return ud.object(forKey: Key.crossVolumeScan) == nil
            ? Default.crossVolumeScan
            : ud.bool(forKey: Key.crossVolumeScan)
    }

    static var duplicatesWarnAllSelected: Bool {
        let ud = UserDefaults.standard
        return ud.object(forKey: Key.duplicatesWarnAllSelected) == nil
            ? Default.duplicatesWarnAllSelected
            : ud.bool(forKey: Key.duplicatesWarnAllSelected)
    }

    static var duplicatesConfirmBeforeDelete: Bool {
        let ud = UserDefaults.standard
        return ud.object(forKey: Key.duplicatesConfirmBeforeDelete) == nil
            ? Default.duplicatesConfirmBeforeDelete
            : ud.bool(forKey: Key.duplicatesConfirmBeforeDelete)
    }

    static var forgottenFilesMinimumAge: Int {
        let ud = UserDefaults.standard
        let val = ud.integer(forKey: Key.forgottenFilesMinimumAge)
        return val == 0 ? Default.forgottenFilesMinimumAge : val
    }

    // MARK: - Registration

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            Key.showSplashScreen: Default.showSplashScreen,
            Key.confirmBeforeDelete: Default.confirmBeforeDelete,
            Key.includeHiddenFiles: Default.includeHiddenFiles,
            Key.scanThreadCount: Default.scanThreadCount,
            Key.defaultScanPath: Default.defaultScanPath,
            Key.treemapMaxItems: Default.treemapMaxItems,
            Key.showEmptyItems: Default.showEmptyItems,
            Key.minimumFileSize: Default.minimumFileSize,
            Key.skipPackageContents: Default.skipPackageContents,
            Key.excludeNodeModules: Default.excludeNodeModules,
            Key.excludeDerivedData: Default.excludeDerivedData,
            Key.excludeGitDirs: Default.excludeGitDirs,
            Key.skipSymlinks: Default.skipSymlinks,
            Key.crossVolumeScan: Default.crossVolumeScan,
            Key.duplicatesWarnAllSelected: Default.duplicatesWarnAllSelected,
            Key.duplicatesConfirmBeforeDelete: Default.duplicatesConfirmBeforeDelete,
            Key.forgottenFilesMinimumAge: Default.forgottenFilesMinimumAge,
        ])
    }
}
