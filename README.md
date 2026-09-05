# UAV Playlist

An iPhone app (Swift/SwiftUI, built with Xcode) that resolves a JableTV, MissAV, or
SupJav video page URL to its real stream URL and writes a **VLC-ready `.m3u8`
playlist**, instead of downloading the video.

**This app never downloads video data.** It fetches just the page HTML (a few KB of
text) to find the real stream URL, then either **plays the playlist in-app** or writes
a `.m3u8` you can hand to **VLC for iOS**. Either way the video is streamed from the
source — nothing here writes a video file anywhere.

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

**Account** — sign in to a MissAV account. Credentials go only to `missav.ai`; with
"Remember me" on they are stored in the device Keychain (device-only, requires unlock),
and signing out deletes them and clears the session cookies.

Signing in adds two things to Browse:

- Under **MissAV**, a **"My Playlists"** checkbox section listing the account's saved
  playlists. Tick one or several and browse them exactly like any other category.
- Under **JableTV**, a **"From MissAV Playlists"** section mirroring those same
  playlists. Browsing one reads the MissAV playlist, pulls the JAV code (`ABCD-123`)
  off each entry, searches JableTV for it, and keeps the best match — **preferring the
  uncensored cut** when the results offer one. Entries whose id isn't a standard code
  (amateur/FC2-style) and codes JableTV has no result for are skipped. Each code costs
  one search and searches run one at a time to avoid tripping rate limits, so a
  mirrored page is noticeably slower to load than a normal listing.

**Playlist** — your queue, accumulated across sites and persisted between launches.
Name it, then tap **Resolve playlist**: the app opens each queued video's page just long
enough to find its stream URL. Videos that fail are listed individually rather than
silently dropped. Once resolved you get two options:

- **Play N videos in app** — the built-in player. It attaches the `Referer`/`Origin`/
  `User-Agent` headers each stream needs, advances through the list automatically at the
  end of each video, and lets you tap any row to jump to it. Native transport controls,
  AirPlay, full screen, Picture in Picture, and background audio all come along.
- **Open playlist (Copy to VLC…)** — the `.m3u8` export, one `#EXTINF` entry per video,
  still available as an alternative.

Nothing is downloaded to the device at any point — the playlist holds remote stream
URLs, and whichever player you choose streams them.

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
  ContentView.swift             tab shell: Browse / Add URL / Playlist / Account
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
    JableTVBrowser.swift        live categories, sidebar tags, MissAV mirroring
    JAVCode.swift               code extraction + cross-site matching/uncensored score
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
  Player/
    PlaylistPlayer.swift        AVPlayer queue: header injection, auto-advance, jump
    PlayerView.swift            player surface + tappable up-next list
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
