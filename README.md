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

Install **VLC for iOS** from the App Store first (used for playback; not needed to build).

The app has four tabs:

**Browse** — pick a site, then tick **checkboxes** next to any number of categories or
filter tags (JableTV also exposes its full sidebar tag list: Clothing, Body, Acts, Kinks,
Story, Roles, Places, Misc). Tap **Browse N selected** and the listings are fetched
together and merged into one de-duplicated grid — a video that appears in two selected
categories shows once. **Tap a card to add it to the playlist queue** (tap again to
remove); the card shows a checkmark while queued. **Add all** queues everything loaded so
far, and **Load more** advances every selected category by a page. Each site's search is
available from the search field on its category screen.

All menu, category, and tag labels are English. JableTV is asked for English via its
`kt_rt_lang` cookie, MissAV categories use its `/en/` routes, and any label that still
comes back localized is replaced with a known English name for that slug (or a title-cased
form of the slug), so nothing non-English reaches the menus.

**Add URL** — paste a single video page URL to queue it directly, for when you already
have a link.

**Account** — sign in to a MissAV account and its **saved playlists appear as their own
checkbox section** ("My Playlists") under MissAV in Browse, alongside the built-in
categories. Tick one or several, browse them, and queue videos exactly as you would
from any other category. Credentials go only to `missav.ai`; with "Remember me" on they
are stored in the device Keychain (device-only, requires unlock), and signing out
deletes them and clears the session cookies.

**Playlist** — your queue, accumulated across sites and persisted between launches.
Name it, then tap **Build VLC playlist**. The app opens each queued video's page just
long enough to resolve its stream URL, then writes **one `.m3u8` containing every
video as a separate entry**, so VLC plays through the whole list. Videos that fail to
resolve are listed individually rather than silently dropped. Finally, tap **Open
playlist (Copy to VLC…)** and choose VLC from the share sheet.

Nothing is downloaded to the device at any point — the playlist holds remote stream
URLs, and VLC does the fetching.

The resolution preference (Highest/1080/720/480/360/Lowest) resolves a master HLS
playlist down to the one variant matching your preference before handing it to VLC.

## Architecture

Two halves: **browsers** find videos (listing pages), **extractors** resolve one video
page to a stream URL. The queue sits between them, and the playlist builder is the
final step.

```
UAVPlaylist.xcodeproj/          Xcode project
Support/Info-Additions.plist    VLC URL schemes, file-sharing entitlements
Sources/UAVPlaylistApp/
  App.swift                     entry point
  ContentView.swift             tab shell: Browse / Add URL / Playlist
  Models/
    ExtractedVideo.swift        resolved stream URL + headers for one video
    VideoListing.swift          a video card from a listing; BrowseCategory
    ExtractionError.swift       English user-facing error messages
  Networking/
    HTTPClient.swift            async URLSession wrapper (Referer/UA headers, cookies)
    RegexUtils.swift            regex-search/findall-style helpers
    PackedJSDecoder.swift       Dean Edwards p,a,c,k,e,d unpacker
    HLSVariantSelector.swift    picks one HLS variant by resolution preference
  Account/
    KeychainStore.swift         Keychain-backed credential storage
    MissAVAccount.swift         MissAV login + saved-playlist fetching
  Browsers/                     listing/browse side
    SiteBrowser.swift           protocol + registry
    SiteCatalog.swift           English category/tag vocabulary + label fallback
    JableTVBrowser.swift        live categories, sidebar tags, ?from=N paging
    MissAVBrowser.swift         categories + account playlists, ?page=N paging
    SupJavBrowser.swift         fixed categories, /page/N paging
  Extractors/                   stream-resolution side
    SiteExtractor.swift         protocol every site conforms to
    ExtractorRegistry.swift     URL -> extractor dispatch
    JableTVExtractor.swift
    MissAVExtractor.swift
    SupJavExtractor.swift
  Queue/
    QueueStore.swift            the persisted playlist queue
    PlaylistJob.swift           queue -> resolve each -> one playlist, with failures
  Playlist/
    ResolutionPreference.swift  persisted user choice
    PlaylistBuilder.swift       writes the multi-entry .m3u8
    ShareSheet.swift            UIActivityViewController bridge
    VLCOpener.swift             vlc:// direct-open fallback
  Views/
    SitesView.swift             site picker
    CategoryListView.swift      multi-select checkboxes for categories + tags
    VideoGridView.swift         merged paged card grid, tap-to-queue
    QueueView.swift             queue, build progress, share to VLC
    AddByURLView.swift          queue a single URL by hand
    AccountView.swift           MissAV sign-in and playlist list
```

## Legal note

This is a link-resolution/playlist tool for content you already have the right to
view on the source sites. See [`SECURITY.md`](./SECURITY.md) for the vulnerability
reporting policy.
