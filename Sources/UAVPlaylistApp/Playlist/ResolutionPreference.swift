import Foundation

/// User-selectable resolution preference, persisted the same way the desktop app
/// stores it, just as a plain UserDefaults value instead of a config file.
enum ResolutionPreference {
    static let all = ["highest", "1080", "720", "480", "360", "lowest"]
    private static let key = "resolutionPreference"

    static var current: String {
        get { UserDefaults.standard.string(forKey: key) ?? "highest" }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
