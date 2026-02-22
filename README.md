<p align="center">
  <img src="SpaceMan/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="128" height="128" alt="SpaceMan Icon">
</p>

<h1 align="center">SpaceMan</h1>

<p align="center">
  <strong>A powerful disk space analyzer and cleanup tool for macOS</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue?style=flat-square" alt="macOS 14+">
  <img src="https://img.shields.io/badge/swift-5.9-orange?style=flat-square" alt="Swift 5.9">
  <img src="https://img.shields.io/badge/UI-SwiftUI%20%2B%20AppKit-purple?style=flat-square" alt="SwiftUI + AppKit">
  <img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="MIT License">
</p>

## Features

### Disk Scanner
> Visualize your entire disk usage with an interactive treemap

<p align="center">
  <img width="700" alt="Disk Scanner" src="https://github.com/user-attachments/assets/6a44fa2e-e499-47f6-a147-5339267b52d1" />
</p>

- **Squarified treemap** rendered with Core Graphics for smooth performance
- Breadcrumb navigation to drill into any folder
- Sidebar file browser with real-time size display
- **Large Files** view to quickly find the biggest space hogs
- File inspector panel with detailed metadata
- Cleanup queue to batch files for review before deletion
- Color-coded file categories (apps, images, videos, documents, archives, developer files, etc.)

---

### App Manager
> Find and remove apps with all their related files

<p align="center">
  <img width="700" alt="App Manager" src="https://github.com/user-attachments/assets/eff9c406-246f-473b-98d0-288c09d4bf34" />
</p>

- Scans `/Applications` and discovers every installed app
- Finds **related data** across Library folders — caches, app support, preferences, containers, and more
- App cards with icons and size breakdown
- Detail inspector showing exactly where app data lives
- Full cleanup: remove the app and all associated files in one action

---

### Duplicates Finder
> Detect and remove duplicate files to reclaim wasted space

<p align="center">
  <img width="700" alt="Duplicates Finder" src="https://github.com/user-attachments/assets/74b168f1-0903-4b44-9843-5e7af92a007a" />
</p>

- Two-phase scan: fast size-based filtering, then SHA-256 hash verification
- Groups duplicates with clear visual hierarchy
- **Auto-select** keeps the newest copy and marks the rest for removal
- Safety warning when all copies of a file are selected
- Move to Trash or permanently delete
- Configurable scan scope: Home, Downloads, Desktop, Documents, or custom folders

---

### Smart Clean
> One-click safe cleanup of caches, downloads, and duplicates

<p align="center">
  <img width="700" alt="Smart Clean" src="https://github.com/user-attachments/assets/e621196a-5794-499c-8250-935b6f0d3cd5" />
</p>

- Orchestrates multiple scanners (Downloads, App Caches, Duplicates) in one pass
- **Rule engine** classifies every item as Safe, Review, or Risky
- Category cards with expand/collapse to inspect what will be cleaned
- Circular gauge dashboard showing total reclaimable space
- Clean history log with timestamps and size freed
- Select all safe items with one click

---

### Forgotten Files
> Find old files you haven't opened in months or years

<p align="center">
  <img width="700" alt="Forgotten Files" src="https://github.com/user-attachments/assets/5e5ba4de-06e2-49ef-bd26-19ac8f07b987" />
</p>

- Scans for files untouched beyond a configurable age threshold (1 week to 5 years)
- **Age breakdown bar** — visual stacked bar showing file distribution by age bucket
- Inline search, category filtering, and sort by size/age/name
- Smart recommendations flag safe-to-remove files (old installers, archives, large videos)
- Scope options: Home, Downloads, Desktop, Documents, Pictures, Movies
- Context menu: Reveal in Finder, Copy Path

---

## Settings

| Tab | Options |
|-----|---------|
| **General** | Splash screen toggle, delete confirmation |
| **Scanning** | Hidden files, thread count, minimum file size, skip packages/symlinks, exclude directories (node_modules, DerivedData, .git), cross-volume scanning, default scan path |
| **Display** | Treemap detail level (50-500 items), show empty items |
| **Duplicates** | Delete confirmation, warn when all copies selected |
| **Forgotten Files** | Minimum age threshold |

---

## Tech Stack

| | |
|---|---|
| **Framework** | SwiftUI + AppKit hybrid |
| **Architecture** | MVVM with `@Observable` and `@MainActor` |
| **Rendering** | Core Graphics treemap via `NSView` |
| **Hashing** | CryptoKit SHA-256 for duplicate detection |
| **Target** | macOS 14.0+ (Sonoma) |
| **Build** | Xcode 15+, XcodeGen |

---

## Installation

Download the latest release from the [Releases page](https://github.com/18jad/spaceman/releases).

```bash
# After downloading and unzipping, remove the quarantine flag:
xattr -cr /Applications/SpaceMan.app
```

## Building from Source

```bash
# Install XcodeGen if needed
brew install xcodegen

# Generate the Xcode project
xcodegen generate

# Build
xcodebuild -scheme SpaceMan -configuration Release build
```

Or open `SpaceMan.xcodeproj` in Xcode and hit Run.

---

## Project Structure

```
SpaceMan/
├── Models/          FileNode, FileCategory, AppInfo, AppSettings,
│                    SmartCleanModels, DuplicateModels, ForgottenFileItem
├── Views/           ContentView, TreemapView, SidebarView, BreadcrumbView,
│                    StorageBarView, StatusBarView, FileDetailView,
│                    AppManagerView, AppCardView, AppDetailView,
│                    DuplicatesView, SmartCleanView, DashboardView,
│                    ForgottenFilesView, LargeFilesView, SettingsView
├── ViewModels/      ScanViewModel, AppManagerViewModel,
│                    DuplicatesViewModel, SmartCleanViewModel,
│                    ForgottenFilesViewModel
├── Services/        DiskScanner, FileDeleter, StorageInfoService,
│                    AppScanner, DuplicateFinder, SmartCleanService,
│                    SmartCleanRuleEngine, SmartCleanExecutor,
│                    DownloadsScanner, ForgottenFilesScanner,
│                    ForgottenFilesRuleEngine
├── Utilities/       SizeFormatter
└── SpaceManApp.swift
```

---

## Author

Built by [@18jad](https://github.com/18jad)
