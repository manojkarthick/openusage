import AppKit

/// Presents the standard macOS About panel for the footer menu's "About OpenUsage" item.
///
/// As a menu-bar accessory app, OpenUsage is not the active app while the popover is showing, so the
/// app is activated first — otherwise the panel would open behind whatever app currently owns the
/// foreground. The panel pulls the app icon, name, and version (`CFBundleShortVersionString` — the
/// same string `AppInfo.version` surfaces in the footer) straight from the bundle; we only supply the
/// credits, which name this fork's maintainer, credit the upstream authors, and link the fork's repo.
enum AboutPanel {
    @MainActor
    static func present() {
        NSApp.activate(ignoringOtherApps: true)
        NSApplication.shared.orderFrontStandardAboutPanel(options: [.credits: credits])
    }

    /// Centered, secondary-styled credits. The standard panel renders `.link`-attributed runs as clickable.
    private static var credits: NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let base: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraph,
        ]

        let credits = NSMutableAttributedString()
        credits.append(NSAttributedString(string: "Fork maintained by ", attributes: base))
        credits.append(link("Manoj Karthick", "https://github.com/manojkarthick", base: base))
        credits.append(NSAttributedString(string: "\n\nBased on ", attributes: base))
        credits.append(link("OpenUsage", "https://github.com/robinebers/openusage", base: base))
        credits.append(NSAttributedString(string: " by ", attributes: base))
        credits.append(link("Robin Ebers", "https://itsbyrob.in/x", base: base))
        credits.append(NSAttributedString(string: ",\n", attributes: base))
        credits.append(link("Mert", "https://github.com/validatedev", base: base))
        credits.append(NSAttributedString(string: " & ", attributes: base))
        credits.append(link("David", "https://github.com/davidarny", base: base))
        credits.append(NSAttributedString(string: "\n\nOpen source on ", attributes: base))
        credits.append(link("GitHub", "https://github.com/manojkarthick/openusage", base: base))
        return credits
    }

    private static func link(_ text: String, _ urlString: String, base: [NSAttributedString.Key: Any]) -> NSAttributedString {
        var attributes = base
        if let url = URL(string: urlString) {
            attributes[.link] = url
        }
        return NSAttributedString(string: text, attributes: attributes)
    }
}
