import Foundation
import UIKit

enum VLCOpener {
    /// Best-effort direct handoff via VLC's `vlc://` URL scheme. This skips the
    /// Referer/User-Agent headers a playlist file carries, so it only reliably works
    /// for streams that don't require them — the share-sheet "Copy to VLC" flow with
    /// the generated playlist file is the primary, more reliable path.
    static func canOpenDirectly(streamURL: URL) -> Bool {
        guard let vlcURL = URL(string: "vlc://\(streamURL.absoluteString)") else { return false }
        return UIApplication.shared.canOpenURL(vlcURL)
    }

    static func openStreamDirectly(_ streamURL: URL) {
        guard let vlcURL = URL(string: "vlc://\(streamURL.absoluteString)") else { return }
        UIApplication.shared.open(vlcURL)
    }
}
