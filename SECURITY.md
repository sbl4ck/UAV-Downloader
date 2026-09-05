# Security policy

## Reporting a vulnerability

Do not open a public Issue for a vulnerability that could expose user data or
credentials. Use GitHub's private vulnerability reporting feature for this
repository. Include the affected version, iOS version, reproduction steps, impact,
and any proposed mitigation.

For ordinary parser failures, site changes, or extraction errors with no security
impact, use the public Issue tracker instead.

## Secrets and local data

The app does not require or store any API key. It does not send analytics or
telemetry anywhere. Reports and logs must not include cookies, proxy credentials,
tokens, personal paths, or downloaded content.

## Network behavior

The app makes HTTP requests only to the video-page domains you enter and, for the
SupJav extractor, the SupremeJAV embed hosts those pages redirect to. It never
downloads or stores video/segment data itself — resolved stream URLs are handed to
VLC, which performs the actual network fetch for playback.
