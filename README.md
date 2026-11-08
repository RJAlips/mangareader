# MangaReader – Premium iOS Manga & Manhwa Reader

[![iOS 17+](https://img.shields.io/badge/iOS-17.0%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-purple.svg)](https://developer.apple.com/xcode/swiftui/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)


---

## 🌟 Key Highlights & Features

### 1. 📖 Advanced Reading Engine
* **Multiple Reading Modes:**
  * **Webtoon Long-Strip:** Continuous vertical scrolling optimized for manhwa chapters with hundreds of image panels. Lazy-loaded to prevent memory pressure.
  * **Right-to-Left (RTL):** Traditional Japanese manga paging with tap zones and page flipping.
  * **Left-to-Right (LTR):** Western comic and graphic novel paging.
  * **Vertical Paged:** Single-page vertical paging.
  * **Double-Page Spread:** Side-by-side two-page reading mode for iPad and landscape orientation.
* **Touch & Gestures:**
  * Pinch-to-zoom (up to 3.5× magnification) and double-tap zoom toggle.
  * 3-zone tap navigation (left: page turn, center: controls toggle, right: page turn).
* **Display Customization:**
  * Background colors: **Pure AMOLED Black**, **Dark Charcoal**, **Sepia**, and **White**.
  * Image scaling: **Fit Width**, **Fit Height**, **Stretch to Fill**, and **Original**.
  * Interactive page scrubber slider and persistent reading progress tracker.
  * Built-in software brightness dimmer for late-night reading in dark environments.
  * Screen wake lock (`isIdleTimerDisabled`) while reading.

### 2. 🗃️ Library Management
* **Custom Categories & System Shelves:** "Reading", "Plan to Read", "Completed", "On Hold", "Dropped", plus unlimited custom user categories.
* **Adaptive Grid & List Views:** Toggle between compact 3-column grid, comfortable 2-column grid, and rich list view.
* **Batch Operations:** Multi-select mode for bulk marking chapters read/unread, bulk downloads, and batch categorization.
* **Smart Sorting & Filtering:** Sort by title, last read date, latest updates, unread chapter count; filter by genre, unread status, and downloaded status.

### 3. 🌐 Modular Source-Provider Architecture
* Native Swift protocol (`MangaSource`) allowing independent content providers.
* Built-in Providers:
  1. **MangaReader Curated:** Pre-packaged open catalog of curated manhwa, manga, and comics with multiple chapters.
  2. **MangaDex (Official REST API v5):** Full search, metadata, chapters, and high-res page streaming via MangaDex@Home.
  3. **Komga Server Provider:** Native support for self-hosted digital media servers with user authentication, library browsing, and remote read-progress syncing.
  4. **Local Archive Provider:** Integrated local files as a first-class source.
* Multi-source **Global Search** executing queries concurrently using Swift `TaskGroup`.

### 4. 📂 Local Content Import (Files App)
* **Archive Support:** Direct import of **CBZ**, **ZIP**, and **EPUB** graphic files.
* **Folder Scanning:** Import full folders containing JPG, PNG, WebP, and HEIC images.
* **Offline First:** Extracted into sandbox storage with thumbnail extraction, allowing 100% offline reading with zero network dependency.

### 5. ⚡ Dual-Layer High-Performance Image Cache
* **Memory Cache:** `NSCache` with item count and byte cost limits, responsive to iOS system memory warnings.
* **Disk Cache:** Persistent LRU disk cache in `Caches/` with cryptographic MD5 filename hashing and automatic 70% pruning when size threshold is reached.

### 6. 📥 Background Download Queue
* Concurrent background downloads with pause, resume, cancel, and retry capabilities.
* Network reachability monitoring (`NWPathMonitor`) with optional **Wi-Fi-only downloads** enforcement.
* Local disk storage tracking and one-tap cache cleaning.

### 7. 🔄 Tracking Integration & Security
* Support for **AniList** (GraphQL) and **MyAnimeList** (REST API v2) reading progress synchronization.
* **Keychain Helper:** OAuth tokens and passwords are encrypted and stored in iOS **Keychain** (`Security.framework`), never in plaintext.

### 8. 💾 Portable Backup & Restore
* Complete JSON backup schema (`BackupData`) exporting manga library, chapters, categories, reading progress, reader settings, and tracker links.
* Integrated iOS `ShareSheet` and document file picker for local and iCloud Drive storage.

---

## 📱 Architecture & Tech Stack

```
MangaReader
 ├── App/                 # Entry point, AppState, App lifecycle
 ├── DesignSystem/        # Semantic Colors, Typography, Spacing, Reusable Views
 ├── Models/              # Codable Domain Models (MangaItem, ChapterItem, etc.)
 ├── Persistence/         # DatabaseManager, LibraryRepository, HistoryRepository
 ├── Services/
 │    ├── ImageCache/     # NSCache + LRU DiskCache with MD5 hashing
 │    ├── Network/        # Actor-based URLSession network client
 │    ├── Downloads/      # DownloadManager queue & file writer
 │    ├── Sources/        # MangaSource protocol, SourceManager, MangaDex, Komga
 │    ├── LocalImport/    # Pure Swift ZIP/CBZ & EPUB extractor
 │    ├── Tracking/       # AniList, MAL, and Keychain storage
 │    └── Backup/         # JSON Backup and Restore service
 ├── ViewModels/          # MVVM ViewModels with Combine & @Published
 └── Views/               # SwiftUI Views for 5 Tabs, Detail, and Reader Engine
```

* **Language:** Swift 5.9+
* **Framework:** SwiftUI
* **Target:** iOS 17.0+ (iPhone & iPad)
* **Concurrency:** Swift Async/Await, Actors, TaskGroups
* **Persistence:** JSON Document Store + SwiftData Compatible Domain Layer
* **Security:** iOS Keychain Services API

---

## 🚀 Building & Running the Project

### Prerequisites
1. **macOS Sonoma (14.0+)** or newer.
2. **Xcode 15.0+** or **Xcode 16.0+**.
3. An active Apple Developer Account (optional for simulator, required for device deployment).

### Option 1: Open via Xcode Project (`.xcodeproj`)
1. Clone or copy the repository to your Mac:
   ```bash
   git clone <repo-url> MangaReader
   cd MangaReader
   ```
2. Double-click `MangaReader.xcodeproj` to open in Xcode.
3. Select an **iPhone 15/16 Pro** or **iPad Pro** simulator from the target dropdown.
4. Press `Cmd + R` to build and run!

### Option 2: Swift Package Manager (`Package.swift`)
The repository is also configured as a standard Swift Package. You can open the root folder directly in Xcode:
```bash
xed .
```
Run tests with:
```bash
swift test
```

---

## 🧪 Running Unit & UI Tests
To execute the automated test suites inside Xcode:
* Press `Cmd + U` to run all unit tests in `MangaReaderTests`:
  * `ModelTests`: Validates chapter numbering and reading progress formulas.
  * `ReaderViewModelTests`: Validates chapter transitions, paging, and reading modes.
  * `ArchiveExtractorTests`: Validates natural numerical filename sorting.
  * `SourceManagerTests`: Validates provider registry, enable/disable toggles.
  * `BackupServiceTests`: Validates JSON serialization round-trips.
* UI Tests (`NavigationUITests`): Tests tab bar navigation across all 5 main screens.

---

## 📄 License
This project is released under the **MIT License**.
*Reference inspiration:* Mihon (Apache 2.0) and Tachimanga. All source code in this repository is original Swift implementations.
