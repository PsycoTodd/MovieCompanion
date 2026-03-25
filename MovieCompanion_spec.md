# MovieCompanion — iOS Project Specification

## Overview

**MovieCompanion** is an iOS SwiftUI app that displays synchronized LRC subtitles on a dark
screen. It is designed to be used as a personal subtitle companion while watching a movie in
a theater — the user loads the app, selects their movie and language, and the subtitle text
scrolls in sync with the film.

---

## Tech Stack

| Item | Choice |
|---|---|
| Platform | iOS 16+ |
| Language | Swift 5.9+ |
| UI Framework | SwiftUI only (no UIKit except `isIdleTimerDisabled`) |
| Xcode | 15+ |
| Third-party dependencies | None |

---

## File Naming Convention

LRC subtitle files are stored as bundled resources in the Xcode project using this pattern:

```
{MovieTitle}_{LanguageCode}.lrc
```

**Examples:**
```
Inception_EN.lrc
Inception_ZH.lrc
Dune_EN.lrc
Dune_FR.lrc
```

The app auto-discovers all movies and languages by scanning `.lrc` files in the bundle at launch.
No manifest file is needed.

---

## App Navigation Flow

```
SplashView  (timed ~2s)
    └─> MovieListView
            └─> LanguageSelectionView
                    └─> SubtitlePlayerView
                            └─> (auto-return on finish) MovieListView
```

All navigation is managed by a `NavigationStack` rooted at `MovieListView`.
`SplashView` is shown as the initial scene and pushes to the stack on completion.

---

## LRC Format Reference

Standard LRC format:

```
[ti: Inception]
[ar: MovieCompanion]

[00:12.50] We were in a dream...
[00:15.00] A dream within a dream.
[01:02.33] You mustn't be afraid to dream a little bigger, darling.
```

**Parsing rules:**
- Timestamp format: `[mm:ss.xx]` where `xx` is hundredths of seconds
- Metadata tags (`[ti:]`, `[ar:]`, `[al:]`, `[by:]`, etc.) are silently skipped
- Lines with no valid timestamp are ignored
- Resulting lines are sorted ascending by timestamp

---

## Data Models

### `Movie`
```swift
struct Movie: Identifiable {
    let id: String           // slug derived from title, e.g. "inception"
    let title: String        // display name, e.g. "Inception"
    let languages: [Language]
}
```

### `Language`
```swift
struct Language: Identifiable {
    let code: String         // e.g. "EN", "ZH", "FR"
    let displayName: String  // e.g. "English", "Chinese", "French"
    let lrcFileName: String  // bundle resource name without extension, e.g. "Inception_EN"
}
```

**Language code → display name mapping** (cover at minimum):
| Code | Display Name |
|---|---|
| EN | English |
| ZH | Chinese |
| FR | French |
| ES | Spanish |
| JA | Japanese |
| KO | Korean |
| DE | German |
| Unknown code | Use code as-is |

### `SubtitleLine`
```swift
struct SubtitleLine: Identifiable {
    let id: UUID
    let timestamp: TimeInterval   // seconds from start
    let text: String
}
```

---

## Core Services

### `LRCParser`

Parses a single `.lrc` bundle resource into `[SubtitleLine]`.

**Interface:**
```swift
struct LRCParser {
    static func parse(fileName: String) -> [SubtitleLine]
}
```

**Logic:**
1. Load file content from `Bundle.main` by filename + `.lrc` extension
2. Split into lines
3. For each line, attempt to match `[mm:ss.xx]` prefix with a regex or manual parse
4. If match found: convert timestamp to `TimeInterval`, capture remaining text
5. Skip metadata tags and empty text lines
6. Return array sorted by `timestamp` ascending

### `MovieLibrary`

Scans `Bundle.main` for all `.lrc` resources and constructs the movie catalog.

**Interface:**
```swift
struct MovieLibrary {
    static func loadAll() -> [Movie]
}
```

**Logic:**
1. Call `Bundle.main.urls(forResourcesWithExtension: "lrc", subdirectory: nil)`
2. For each URL, extract the filename stem (e.g. `Inception_EN`)
3. Split on the last `_` to get `(titleRaw, languageCode)`
4. Convert `titleRaw` underscores/dashes to spaces for display title
5. Group by title → build `[Movie]` sorted alphabetically
6. Within each movie, build `[Language]` sorted by display name

---

## ViewModels

### `MovieLibraryViewModel: ObservableObject`

```swift
@MainActor
class MovieLibraryViewModel: ObservableObject {
    @Published var movies: [Movie] = []

    init() {
        movies = MovieLibrary.loadAll()
    }
}
```

### `PlayerViewModel: ObservableObject`

```swift
@MainActor
class PlayerViewModel: ObservableObject {
    @Published var currentLine: SubtitleLine? = nil
    @Published var isPlaying: Bool = false
    @Published var elapsedTime: TimeInterval = 0
    var totalDuration: TimeInterval = 0
    var onFinished: (() -> Void)? = nil

    private var lines: [SubtitleLine] = []
    private var timer: Timer? = nil
    private let tickInterval: TimeInterval = 0.1

    func load(lrcFileName: String)
    func play()
    func pause()
    func seek(to time: TimeInterval)
    func stop()          // resets state, fires no callback
}
```

**Playback logic:**
- `play()` starts a repeating `Timer` at 0.1s intervals
- Each tick increments `elapsedTime` by `tickInterval`
- `currentLine` is set to the last `SubtitleLine` whose `timestamp <= elapsedTime`
- When `elapsedTime` exceeds the last line's `timestamp` by a short grace period (e.g. 1.5s),
  call `onFinished?()` and stop the timer
- `totalDuration` is set to the timestamp of the last subtitle line

**Screen wake lock:**
- `UIApplication.shared.isIdleTimerDisabled = true` on `play()`
- `UIApplication.shared.isIdleTimerDisabled = false` on `pause()`, `stop()`, and view disappear

---

## Views

### `SplashView`

- Full-screen black background
- Centered `AppLogo` image from `Assets.xcassets` (placeholder acceptable)
- App name `"MovieCompanion"` in white below the logo, serif or bold sans font
- After **2 seconds** (via `.onAppear` + `DispatchQueue.main.asyncAfter`), trigger
  navigation to `MovieListView`
- No back button or navigation chrome

### `MovieListView`

- Root of `NavigationStack`
- `List` of `Movie` items, dark background
- Each row: movie title in white, subtitle count or language badges optional
- Chevron `>` on trailing edge
- Navigation bar title: `"MovieCompanion"` (inline or large, dark style)

### `LanguageSelectionView`

- Navigation bar title: the movie title
- `List` of `Language` items for the selected movie
- Each row: language `displayName` in white text
- Tapping navigates to `SubtitlePlayerView`, passing the selected `lrcFileName`

### `SubtitlePlayerView`

**Background:** `Color.black.ignoresSafeArea()` — pure black, no navigation chrome visible

**Layout (top to bottom):**

1. **Subtitle display area** — vertically centered, horizontally centered, padding ~40pt sides
   - Shows `currentLine?.text ?? ""`
   - Font: `.system(size: fontSize, weight: .medium)`, color: `.white`
   - Multiline, `.multilineTextAlignment(.center)`
   - Animated crossfade between lines: `.animation(.easeInOut(duration: 0.25), value: currentLine?.id)`

2. **Controls area** — pinned to bottom, above safe area

   a. **Time labels row:** `elapsed mm:ss` on left, `total mm:ss` on right, gray text

   b. **Seek slider:** `Slider(value: $elapsedTime, in: 0...totalDuration)`
      - On edit: call `playerViewModel.seek(to:)`
      - Accent color: white or warm gold

   c. **Font size row:** label `"A"` small on left, `Slider` for `fontSize` (range 16–48),
      label `"A"` large on right — all in gray

   d. **Play/Pause button:** large SF Symbol (`play.fill` / `pause.fill`),
      white, centered, ~44pt tap target

**Behavior:**
- `.onAppear`: call `playerViewModel.load(lrcFileName:)`
- `.onDisappear`: call `playerViewModel.stop()`, re-enable idle timer
- `playerViewModel.onFinished`: pop navigation stack back to `MovieListView`
- Hide navigation bar back button during playback (or style minimally)

---

## Visual Design Tokens

| Token | Value |
|---|---|
| App background | `Color(red: 0.05, green: 0.05, blue: 0.05)` (~`#0D0D0D`) |
| Player background | `Color.black` |
| Primary text | `Color.white` |
| Secondary text / labels | `Color(white: 0.5)` |
| Accent / interactive | `Color(red: 0.9, green: 0.79, blue: 0.48)` (warm gold `#E5C97B`) |
| List row background | `.clear` over dark nav stack background |
| Navigation bar style | `.navigationBarTitleDisplayMode(.inline)` + dark color scheme |
| Subtitle font weight | `.medium` |
| UI label font size | 13–14pt |

Apply `.preferredColorScheme(.dark)` at the app root.

---

## Project File Structure

```
MovieCompanion/
├── MovieCompanionApp.swift              # @main, sets up NavigationStack, shows SplashView
├── Assets.xcassets/
│   └── AppLogo.imageset/               # Placeholder logo image
├── Resources/                          # Bundled .lrc files
│   ├── Inception_EN.lrc
│   └── Inception_ZH.lrc               # (add more as needed)
├── Models/
│   ├── Movie.swift
│   ├── Language.swift
│   └── SubtitleLine.swift
├── Services/
│   ├── LRCParser.swift
│   └── MovieLibrary.swift
├── ViewModels/
│   ├── MovieLibraryViewModel.swift
│   └── PlayerViewModel.swift
└── Views/
    ├── SplashView.swift
    ├── MovieListView.swift
    ├── LanguageSelectionView.swift
    └── SubtitlePlayerView.swift
```

---

## Sample LRC File (for testing)

Create `Resources/Inception_EN.lrc` with:

```
[ti: Inception]
[ar: Test]

[00:05.00] We were dreaming together.
[00:09.50] But whose dream is this?
[00:14.00] You need to go deeper.
[00:20.00] Dreams feel real while we're in them.
[00:26.50] It's only when we wake up that we realize something was strange.
[00:34.00] I can't imagine you with all your complexity...
[00:40.00] ...all your perfection, all your imperfection.
[00:48.00] Look at you. You're just a shade.
[00:54.00] You're just a shade of my real wife.
```

---

## Out of Scope (v1)

- Downloading LRC files from a remote URL
- Multiple simultaneous subtitle tracks
- Video playback
- Custom font family selection
- Landscape orientation / iPad layout
- Searching or filtering the movie list
- User-added LRC files (Files app import)
