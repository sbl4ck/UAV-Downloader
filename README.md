# UAV Playlist

An iPhone app (Swift/SwiftUI, built with Xcode) that resolves a JableTV, MissAV, or
SupJav video page URL to its real stream URL and writes a **VLC-ready `.m3u8`
playlist**, instead of downloading the video.

**This app never downloads video data.** You paste a video page URL, the app fetches
just the page HTML (a few KB of text) to find the real stream URL, and it writes a
`.m3u8` playlist file that you hand to **VLC for iOS**. VLC then streams the video
itself — nothing here writes a video file anywhere.

All source, UI text, and comments are in English.

## Supported sites

| Site | Extractor |
|---|---|
| JableTV | `Sources/UAVPlaylistApp/Extractors/JableTVExtractor.swift` |
| MissAV (incl. the Dean Edwards JS-packer decoder) | `Extractors/MissAVExtractor.swift`, `Networking/PackedJSDecoder.swift` |
| SupJav (FST/Streamtape/TV server fallback chain) | `Extractors/SupJavExtractor.swift` |

**Known limitation:** there's no Cloudflare-bypass path (no equivalent of
`curl_cffi`/`cloudscraper` browser-fingerprint impersonation). The app uses a plain
`URLSession` with a desktop-Chrome `User-Agent`. Most pages work fine; a page that's
actively behind a Cloudflare challenge will report "blocked".

## Opening the project

1. Double-click `UAVPlaylist.xcodeproj` (or open it from Xcode's `File > Open…`).
2. Xcode resolves the one package dependency,
   [SwiftSoup](https://github.com/scinfu/SwiftSoup) (used for CSS-selector HTML
   parsing) — this needs a network connection the first time.
3. Plug in your iPhone (or pick a simulator) as the run destination.
4. Select the `UAVPlaylist` target in the project navigator, open the **Signing &
   Capabilities** tab, and pick your Apple ID under **Team** (Xcode adds a free
   personal team automatically if you sign in via `Xcode > Settings > Accounts`).
   This is the normal one-time step Apple requires to install any app you build
   yourself onto your own iPhone.
5. Press **Run** (▶).

## Using it

1. Install **VLC for iOS** from the App Store (used for playback, not needed to build).
2. Paste a JableTV/MissAV/SupJav video page URL and tap **Build VLC playlist**.
3. Tap **Open playlist (Copy to VLC…)** and choose VLC from the share sheet — this
   copies the `.m3u8` file into VLC's library, which then streams the video.
4. If the resolved stream needs no special headers, **Open stream directly in VLC**
   is also available (uses VLC's `vlc://` URL scheme directly, skipping the file).

The resolution picker (Highest/1080/720/480/360/Lowest) resolves a master HLS
playlist down to the one variant matching your preference before handing it to VLC.

## Architecture

```
UAVPlaylist.xcodeproj/          Xcode project
Support/Info-Additions.plist    VLC URL schemes, file-sharing entitlements
Sources/UAVPlaylistApp/
  App.swift                     entry point
  ContentView.swift             the one screen: URL field, resolution picker, result
  PlaylistViewModel.swift       orchestrates extract -> build playlist -> share/open
  Models/
    ExtractedVideo.swift        title/thumbnail/stream URL/headers for one video
    ExtractionError.swift       English user-facing error messages
  Networking/
    HTTPClient.swift            async URLSession wrapper (Referer/UA headers, cookies)
    RegexUtils.swift            regex-search/findall-style helpers
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
view on the source sites. See [`SECURITY.md`](./SECURITY.md) for the vulnerability
reporting policy.
