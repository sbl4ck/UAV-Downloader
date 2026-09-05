# Contributing to UAV Playlist

Thank you for improving the project. Bug reports that include a reproducible video
page URL and the exact Xcode/iOS versions used are especially valuable, since
supported sites change their page markup independently of the app.

## Development setup

Requires Xcode 16 or later and an Apple ID (free personal team is enough for
running on your own device).

```bash
git clone https://github.com/sbl4ck/UAV-Downloader.git
cd UAV-Downloader
open UAVPlaylist.xcodeproj
```

Xcode resolves the SwiftSoup package dependency automatically on first open.

## Pull requests

- Keep one file per site extractor under `Sources/UAVPlaylistApp/Extractors/`,
  conforming to `SiteExtractor`.
- Keep shared HTTP/regex/HLS-parsing helpers in `Networking/`.
- All UI text, error messages, and code comments must be in English.
- Never commit API keys, cookies, proxy credentials, or downloaded video content.
- New extractors should never download or store video/segment data — the app's
  entire point is resolving a stream URL and handing playback off to VLC.
