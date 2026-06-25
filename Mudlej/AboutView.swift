//
//  AboutView.swift
//  Mudlej
//
//  The About panel — app info plus an in-app language switch (System / English /
//  العربية). Hosted in an AppKit window opened on demand, so it never pops up at
//  launch (a SwiftUI `Window` scene would, on macOS 14).
//

import SwiftUI
import AppKit

struct AboutView: View {
    @Bindable var manager: AwakeManager

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var appTitle: String {
        let isArabic: Bool
        switch manager.appLanguage {
        case .ar:     isArabic = true
        case .en:     isArabic = false
        case .system: isArabic = Locale.autoupdatingCurrent.language.languageCode?.identifier == "ar"
        }
        return isArabic ? "🥷 مدلج" : "🥷 Mudlej"
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.stars")
                .font(.system(size: 40))
                .foregroundStyle(.tint)

            Text(verbatim: appTitle)
                .font(.title2.bold())

            Text("Keeps your Mac awake while AI agents run.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Text("“مدلج” means one who journeys through the night — the Mac keeps working until your agents reach dawn.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Text("Version \(version)")
                .font(.footnote)
                .foregroundStyle(.tertiary)

            Divider()

            Picker("Language", selection: $manager.appLanguage) {
                Text("System").tag(AwakeManager.AppLanguage.system)
                Text("English").tag(AwakeManager.AppLanguage.en)
                Text(verbatim: "العربية").tag(AwakeManager.AppLanguage.ar)
            }
            .pickerStyle(.segmented)
        }
        .padding(24)
        .frame(width: 360)
        // Recomputes when appLanguage changes, so the switch is live.
        .environment(\.locale, manager.locale)
        .environment(\.layoutDirection, manager.appLanguage == .ar ? .rightToLeft : .leftToRight)
    }
}

/// Lazily creates and shows a single About window hosting `AboutView`.
@MainActor
final class AboutWindow {
    static let shared = AboutWindow()
    private var window: NSWindow?

    func show(manager: AwakeManager) {
        if window == nil {
            let hosting = NSHostingView(rootView: AboutView(manager: manager))
            let w = NSWindow(
                contentRect: NSRect(origin: .zero, size: hosting.fittingSize),
                styleMask: [.titled, .closable],
                backing: .buffered, defer: false)
            w.isReleasedWhenClosed = false
            w.contentView = hosting
            w.setContentSize(hosting.fittingSize)
            w.center()
            window = w
        }
        // Title bar follows the in-app language too (content already does).
        window?.title = title(in: manager)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    /// Resolves "About Mudlej" in the app's chosen language (falls back to system).
    private func title(in manager: AwakeManager) -> String {
        if manager.appLanguage != .system,
           let path = Bundle.main.path(forResource: manager.appLanguage.rawValue, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: "About Mudlej", value: nil, table: nil)
        }
        return String(localized: "About Mudlej")
    }
}
