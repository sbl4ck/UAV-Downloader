import SwiftUI
import UIKit

/// Wraps `UIActivityViewController` for SwiftUI. Sharing the generated `.m3u8` file
/// surfaces "Copy to VLC" (or AirDrop/Files/etc.) in the system share sheet.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
