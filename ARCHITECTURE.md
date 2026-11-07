# Architecture & Technical Design Specification

*Document version: 1.0.0*  
*Target Environment: iOS 17.0+, iPadOS 17.0+*  
*Architecture Pattern: MVVM (Model-View-ViewModel) + Service-Oriented Domain Layer*

---

## 1. Architectural Philosophy

MangaReader is engineered around four core tenets:
1. **Separation of Concerns:** Distinct boundaries between Persistence, Networking, Domain Logic, and UI rendering.
2. **Actor-Based Thread Safety:** Heavy background operations (disk caching, image fetching, archive decompression) are performed off the Main Actor, while UI bindings are strictly `@MainActor` constrained.
3. **Low Memory Footprint:** Manga chapters can contain between 50 to 250 high-resolution vertical panels. Memory spikes are mitigated via lazy views (`LazyVStack`), automatic `NSCache` eviction upon system memory pressure warnings, and local file streaming.
4. **Resilient Extensibility:** Content sources and trackers implement clean Swift protocols, enabling developers to plug in new providers without modifying core reader logic.

---

## 2. Layered System Diagram

```
┌───────────────────────────────────────────────────────────┐
│                    Presentation Layer                     │
│  MainTabView (Adaptive iPhone TabView / iPad SplitView)   │
│  ├─ HomeView                ├─ DownloadsView              │
│  ├─ LibraryView             ├─ SettingsView               │
│  ├─ BrowseView              └─ ReaderContainerView        │
└─────────────────────────────┬─────────────────────────────┘
                              │ Data Bindings (@ObservedObject / @Published)
┌─────────────────────────────▼─────────────────────────────┐
│                     ViewModel Layer                       │
│  HomeViewModel, LibraryViewModel, BrowseViewModel,        │
│  MangaDetailViewModel, ReaderViewModel, DownloadsVM       │
└─────────────────────────────┬─────────────────────────────┘
                              │ Service Calls (Async / Await)
┌─────────────────────────────▼─────────────────────────────┐
│                      Services Layer                       │
│  ├─ ImageCacheManager (NSCache + Actor DiskCache)         │
│  ├─ NetworkClient (Actor, Rate-limiting, Retries)         │
│  ├─ DownloadManager (Background Tasks, NWPathMonitor)     │
│  ├─ SourceManager (MangaSource Protocol, TaskGroup)       │
│  ├─ ArchiveExtractor (Pure Swift ZIP/CBZ & EPUB Parser)   │
│  ├─ TrackerManager (AniList GraphQL, MAL REST, Keychain)  │
│  └─ BackupService (JSON Schema V1 Export/Restore)         │
└─────────────────────────────┬─────────────────────────────┘
                              │ Reactive Updates
┌─────────────────────────────▼─────────────────────────────┐
│                    Persistence Layer                      │
│  DatabaseManager (Thread-safe JSON Store / SwiftData)     │
│  ├─ LibraryRepository       ├─ HistoryRepository          │
└───────────────────────────────────────────────────────────┘
```

---

## 3. Component Deep Dive

### 3.1 The Reading Engine
The reading engine (`ReaderContainerView`) isolates rendering into two specialized components depending on the selected `ReadingMode`:

* **`WebtoonReaderView`:** Designed for vertical, infinite-scroll manhwa. Uses a `ScrollViewReader` containing a `LazyVStack(spacing: 0)` of `AsyncMangaImage` views. Images are loaded on demand as their cell intersects the viewport, and reading progress updates the persistent database reactively.
* **`PagedReaderView`:** Designed for single/double page flipping. Uses SwiftUI's `.tabViewStyle(.page(indexDisplayMode: .never))` with bidirectional layout flipping for traditional Right-to-Left (Japanese) manga.
* **Gesture Zones:**
  * Top/Left: Previous page or scroll step.
  * Center: Toggle overlay chrome (navigation bars, chapter scrubber, reading mode switcher).
  * Bottom/Right: Next page or scroll step.
  * Two-finger pinch: `MagnificationGesture` supporting arbitrary scaling up to 3.5× with double-tap snap-to-zoom.

### 3.2 Dual-Layer Image Caching (`ImageCacheManager`)
* **Layer 1 (L1 In-Memory):** `NSCache<NSString, UIImage>` configured with a total cost limit of 150 MB and maximum item count of 250 images. Subscribes to `UIApplication.didReceiveMemoryWarningNotification` to flush memory instantly.
* **Layer 2 (L2 On-Disk):** `DiskCache` actor managing a sandboxed folder in `Library/Caches/MangaImages`. Filenames are computed using MD5 digests of the image URL. Eviction follows an LRU policy: when the directory exceeds 500 MB, the oldest 30% of files by access date are pruned.

### 3.3 The Download Queue (`DownloadManager`)
* Coordinates concurrent downloads of chapter images.
* Files are structured on disk as:
  ```
  Documents/Downloads/{mangaID}/{chapterID}/{pageIndex}.jpg
  ```
* When opening a chapter, `ReaderViewModel` first queries `DownloadManager.localPagesForChapter(_)`. If found, all pages are served via `file://` URLs, bypassing network latency and providing complete offline support.
* Listens to iOS network status via `NWPathMonitor`. If `wifiOnly` is set to `true`, active downloads pause automatically when cellular data is active and resume upon reconnecting to Wi-Fi.

### 3.4 Protocol-Based Content Sources (`MangaSource`)
Every content provider implements `MangaSource`:
```swift
public protocol MangaSource: AnyObject, Sendable {
    var manifest: SourceManifest { get }
    func fetchPopular(page: Int) async throws -> [MangaItem]
    func fetchLatest(page: Int) async throws -> [MangaItem]
    func search(query: String, page: Int) async throws -> [MangaItem]
    func fetchMangaDetail(urlOrSlug: String) async throws -> MangaItem
    func fetchChapters(for urlOrSlug: String) async throws -> [ChapterItem]
    func fetchPageURLs(for chapterSourceID: String) async throws -> [URL]
    func checkHealth() async -> Bool
}
```
* **Parallel Global Search:** `SourceManager.globalSearch(query:)` executes searches across all enabled sources concurrently using Swift `TaskGroup`, gathering aggregated results without blocking the UI thread.

### 3.5 Local File Extraction (`ArchiveExtractor`)
* Implements a pure Swift ZIP unpacker without external C libraries.
* Inspects Local File Headers (`0x04034b50`) and decompress deflated streams via iOS native `Compression.framework` (`COMPRESSION_ZLIB`).
* Safely protects against path traversal vulnerabilities by stripping directory paths and isolating files into clean UUID-named sandbox directories.
* Natural sort ordering (`.localizedStandardCompare`) ensures comic pages `1.jpg, 2.jpg, ... 10.jpg` are ordered correctly.

### 3.6 Secure Credential Storage (`KeychainHelper`)
* Interacts directly with Apple's `Security.framework` (`kSecClassGenericPassword`).
* OAuth access tokens and server passwords for AniList, MyAnimeList, and Komga are stored in the iOS Keychain with `kSecAttrAccessibleAfterFirstUnlock`.

---

## 4. Concurrency Model
* **UI Updates:** Enforced on `@MainActor` via `@StateObject` and `@Published` properties.
* **Network & Disk I/O:** Handled via actors (`NetworkClient`, `DiskCache`) and asynchronous Swift routines (`async/await`).
* **Background Tasks:** Cancellable `Task` instances prevent redundant downloads or image decodes when views disappear.
