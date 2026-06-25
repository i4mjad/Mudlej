//
//  MudlejApp.swift
//  Mudlej
//
//  Menu-bar-only app (LSUIElement). The icon reflects state: moon.stars while
//  holding sleep off (journeying through the night), moon.zzz while idle.
//

import SwiftUI

@main
struct MudlejApp: App {
    @State private var manager = AwakeManager()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(manager: manager)
                .environment(\.locale, manager.locale)
        } label: {
            // 🥷 while journeying (holding sleep off); quiet moon while idle.
            if manager.isHeld {
                Text(verbatim: "🥷")
            } else {
                Image(systemName: "moon.zzz")
            }
        }
        .menuBarExtraStyle(.menu)
    }
}
