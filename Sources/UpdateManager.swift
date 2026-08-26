import AppKit
import Foundation

// MARK: - Release model

/// Minimal release description kept so the surrounding update UI still compiles.
/// No release is ever fetched in this build, so instances of this type are never
/// constructed at runtime.
struct GitHubRelease: Decodable, Identifiable {
    let tagName: String
    let name: String?
    let body: String?
    let htmlUrl: String
    let publishedAt: String

    var id: String { tagName }

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlUrl = "html_url"
        case publishedAt = "published_at"
    }
}

enum UpdateStatus: Equatable {
    case idle
    case downloading
    case installing
    case readyToRelaunch
    case error(String)
}

// MARK: - Update manager

/// Qliq ships without a network updater.
///
/// The upstream build polled a GitHub release feed and could replace its own
/// bundle with whatever that feed pointed at. That behaviour is deliberately
/// absent here: this app is built from source and installed locally, so an
/// automatic updater would either do nothing or install a different product
/// over it.
///
/// The public surface is preserved only so the existing menu and settings
/// views keep compiling. Every state that could lead to a download is
/// permanently empty, and asking for an update explains how updates actually
/// arrive.
@MainActor
final class UpdateManager: ObservableObject {
    static let shared = UpdateManager()

    @Published var updateAvailable = false
    @Published var latestRelease: GitHubRelease?
    @Published var latestReleaseVersion: String = ""
    @Published var latestReleaseDate: String = ""
    @Published var isChecking = false
    @Published var downloadProgress: Double?
    @Published var updateStatus: UpdateStatus = .idle
    @Published var lastCheckDate: Date?

    private static let autoCheckKey = "qliq.updates.autoCheck"
    private static let lastCheckKey = "qliq.updates.lastCheck"

    var autoCheckEnabled: Bool {
        get { UserDefaults.standard.object(forKey: Self.autoCheckKey) as? Bool ?? false }
        set {
            objectWillChange.send()
            UserDefaults.standard.set(newValue, forKey: Self.autoCheckKey)
        }
    }

    private init() {
        lastCheckDate = UserDefaults.standard.object(forKey: Self.lastCheckKey) as? Date
    }

    func startPeriodicChecks() {}

    func checkForUpdates(userInitiated: Bool) async {
        isChecking = true
        // Brief pause so the spinner in the menu is visible rather than flashing.
        try? await Task.sleep(nanoseconds: 250_000_000)
        isChecking = false
        lastCheckDate = Date()
        UserDefaults.standard.set(lastCheckDate, forKey: Self.lastCheckKey)
        if userInitiated {
            showUpdateAlert()
        }
    }

    func downloadAndInstall(release: GitHubRelease) {
        updateStatus = .idle
    }

    func cancelDownload() {}

    func showReleaseNotes() {
        showUpdateAlert()
    }

    func showUpdateAlert() {
        let alert = NSAlert()
        alert.messageText = "Updates are handled manually"
        alert.informativeText = """
        \(AppName.displayName) is built and installed locally, so it does not check \
        for updates or download new versions. Rebuild it from source when you want \
        a newer version.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    func shouldShowPostTranscriptionReminder() -> Bool { false }

    func markPostTranscriptionReminderShown() {}
}
