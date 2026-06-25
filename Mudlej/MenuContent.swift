//
//  MenuContent.swift
//  Mudlej
//
//  The dropdown menu: status, three modes, display toggle, launch-at-login, quit.
//

import SwiftUI

struct MenuContent: View {
    @Bindable var manager: AwakeManager

    var body: some View {
        if manager.runningAgents.isEmpty {
            Text("No agents detected")
        } else {
            // Emoji prepended outside the localized key so "Running: %@" still matches.
            Text(verbatim: "🥷 ") + Text("Running: \(manager.runningAgents.joined(separator: ", "))")
        }

        Divider()

        modeButton("Auto", .auto)
        modeButton("Keep awake", .alwaysOn)
        modeButton("Allow sleep", .alwaysOff)

        Divider()

        Toggle("Keep display awake too", isOn: $manager.keepDisplayAwake)

        Toggle("Keep awake with lid closed", isOn: Binding(
            get: { manager.lidClosedAwake },
            set: { manager.setLidClosedAwake($0) }))

        Toggle("Launch at login", isOn: Binding(
            get: { manager.launchAtLogin },
            set: { manager.setLaunchAtLogin($0) }))

        if manager.lidClosedAwake {
            Text("⚠️ Sleep is disabled system-wide until you turn this off.")
        } else {
            Text("Tip: closing the lid sleeps the Mac unless “Keep awake with lid closed” is on.")
        }

        Divider()

        Button("About Mudlej") {
            AboutWindow.shared.show(manager: manager)
        }

        Button("Quit Mudlej") {
            manager.release()
            manager.setLidClosedAwake(false)  // restore system sleep before quitting
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    @ViewBuilder
    private func modeButton(_ title: LocalizedStringKey, _ mode: AwakeManager.Mode) -> some View {
        Button {
            manager.mode = mode
        } label: {
            // SwiftUI shows the checkmark via Label; in .menu style a leading
            // checkmark image marks the active mode.
            if manager.mode == mode {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }
}
