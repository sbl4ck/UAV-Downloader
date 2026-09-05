# UAV Playlist (iOS)

A from-scratch Swift/SwiftUI port of the JableTV, MissAV, and SupJav link extractors
from this repository's Python desktop app, packaged as an iPhone app in Xcode.

**This app never downloads video data.** You paste a video page URL, the app fetches
just the page HTML (a few KB of text) to find the real stream URL, and it writes a
`.m3u8` playlist file that you hand to **VLC for iOS**. VLC then streams the video
itself. That's the fundamental difference from the desktop `M3U8Crawler`, which
downloads and decrypts every HLS segment to an `.mp4` on disk — nothing here writes a
video file anywhere.

All source, UI text, and comments are in English. Nothing in this iOS port
displays Chinese/Japanese strings the way the desktop GUI's `i18n/locales.py` does;
resolution preferences, error messages, etc. are plain English.

## What's included / not included

Ported directly from `src/uav_downloader/sites/`:

| Site | Python source | Swift port |
|---|---|---|
| JableTV | `jabletv.py` | `Extractors/JableTVExtractor.swift` |
| MissAV | `missav.py` (incl. the Dean Edwards JS-packer decoder) | `Extractors/MissAVExtractor.swift`, `Networking/PackedJSDecoder.swift` |
| SupJav | `supjav.py` (FST/Streamtape/TV server fallback chain) | `Extractors/SupJavExtractor.swift` |

**Not ported, by request:** Hanime1. **Not ported, out of scope for a link/playlist
app:** segment downloading, AES-128 decryption, ffmpeg remuxing, subtitle generation
(Whisper/translation), the browse/watch/watcher GUIs, and Windows packaging — none of
that applies once VLC is doing the playback instead of this app doing the download.

**Not ported, technical limitation:** the desktop app's Cloudflare-bypass path
(`curl_cffi`/`cloudscraper` browser impersonation). This app uses a plain
`URLSession` with a desktop-Chrome `User-Agent`. Most pages work fine; a page that the
desktop app can only reach via its Cloudflare workaround will report "blocked" here
too. There's no clean equivalent to TLS-fingerprint impersonation in a stock iOS app.

## Opening the project

### Option A — open as a Swift package app (Xcode 16+)

1. Open `Package.swift` directly in Xcode (`File > Open…`, pick this folder).
2. Xcode resolves the one dependency, [SwiftSoup](https://github.com/scinfu/SwiftSoup)
   (used for CSS-selector HTML parsing, the same role BeautifulSoup plays in the
   Python code).
3. Pick an iPhone (device or simulator) as the run destination and press **Run**.

This uses Xcode 16's "run a Swift package as an iOS app" support
(`Product.iOSApplication` in `Package.swift`), so there's no `.xcodeproj` to
commit — Xcode generates the app target from `Package.swift` itself. This was not
compiled/run in this environment (a Linux container without Xcode) — if your Xcode
version doesn't yet support this product type, use Option B instead.

### Option B — regular Xcode project (any recent Xcode)

1. `File > New > Project… > iOS > App`, interface **SwiftUI**, language **Swift**.
2. `File > Add Package Dependencies…`, add `https://github.com/scinfu/SwiftSoup.git`.
3. Delete the template's `ContentView.swift`/`App.swift` and drag in everything under
   `Sources/UAVPlaylistApp/` (keep the folder structure).
4. In the target's Info tab, add:
   - `LSApplicationQueriesSchemes`: `vlc`, `vlc-x-callback`
   - `UIFileSharingEnabled`: `YES`
   - `LSSupportsOpeningDocumentsInPlace`: `YES`
   (the same keys are in `Support/Info-Additions.plist` for reference.)
5. Run on an iPhone.

## Using it

1. Install **VLC for iOS** from the App Store (used for playback, not needed to build).
2. Paste a JableTV/MissAV/SupJav video page URL and tap **Build VLC playlist**.
3. Tap **Open playlist (Copy to VLC…)** and choose VLC from the share sheet — this
   copies the `.m3u8` file into VLC's library, which then streams the video.
4. If the resolved stream needs no special headers, **Open stream directly in VLC**
   is also available (uses VLC's `vlc://` URL scheme directly, skipping the file).

The resolution picker (Highest/1080/720/480/360/Lowest) mirrors the desktop app's
`select_variant` logic: when the extracted URL is a master HLS playlist with several
quality variants, the app resolves it down to the one matching your preference before
handing it to VLC.

## Architecture

```
Sources/UAVPlaylistApp/
  App.swift                     entry point
  ContentView.swift             the one screen: URL field, resolution picker, result
  PlaylistViewModel.swift       orchestrates extract -> build playlist -> share/open
  Models/
    ExtractedVideo.swift        title/thumbnail/stream URL/headers for one video
    ExtractionError.swift       English user-facing error messages
  Networking/
    HTTPClient.swift            async URLSession wrapper (Referer/UA headers, cookies)
    RegexUtils.swift            re.search/re.findall-style helpers
    PackedJSDecoder.swift       Dean Edwards p,a,c,k,e,d unpacker
    HLSVariantSelector.swift    picks one HLS variant by resolution preference
  Extractors/
    SiteExtractor.swift         protocol every site conforms to
    ExtractorRegistry.swift     URL -> extractor dispatch
    JableTVExtractor.swift
    MissAVExtractor.swift
    SupJavExtractor.swift
  Playlist/
    ResolutionPreference.swift  persisted user choice
    PlaylistBuilder.swift       writes the .m3u8 (#EXTINF/#EXTVLCOPT/stream URL)
    ShareSheet.swift            UIActivityViewController bridge
    VLCOpener.swift             vlc:// direct-open fallback
```

## Legal note

This is a link-resolution/playlist tool for content you already have the right to
view on the source sites, same as the existing desktop app in this repository —
see the repo's top-level `README.md`/`SECURITY.md` for the project's overall scope
and disclaimers.
