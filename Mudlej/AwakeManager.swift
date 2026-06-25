//
//  AwakeManager.swift
//  Mudlej
//
//  Owns the power assertion, the 5s polling loop, agent detection, and
//  UserDefaults persistence. The Mac is the مُدْلِج — it journeys through the
//  night while agents run, then is allowed to rest.
//

import Foundation
import AppKit
import Observation
import ServiceManagement

@MainActor
@Observable
final class AwakeManager {

    enum Mode: String {
        case auto       // hold only while an agent is detected
        case alwaysOn   // always hold (Keep awake)
        case alwaysOff  // never hold (Allow sleep)
    }

    /// In-app language override for the UI (independent of the system language).
    enum AppLanguage: String, CaseIterable {
        case system, en, ar
    }

    // Persisted settings
    var mode: Mode {
        didSet {
            defaults.set(mode.rawValue, forKey: Keys.mode)
            evaluate()
        }
    }
    var keepDisplayAwake: Bool {
        didSet {
            defaults.set(keepDisplayAwake, forKey: Keys.keepDisplayAwake)
            reapplyIfHeld()
        }
    }
    /// Whether `pmset disablesleep` is currently requested. Not a `didSet` toggle:
    /// changing it needs an admin prompt that can be cancelled, so it's driven
    /// through `setLidClosedAwake(_:)` which only persists on success.
    private(set) var lidClosedAwake: Bool
    var appLanguage: AppLanguage {
        didSet { defaults.set(appLanguage.rawValue, forKey: Keys.language) }
    }

    /// Locale to inject via `\.locale` so the UI follows `appLanguage`.
    var locale: Locale {
        switch appLanguage {
        case .system: return .autoupdatingCurrent
        case .en:     return Locale(identifier: "en")
        case .ar:     return Locale(identifier: "ar")
        }
    }

    // Live state for the UI
    private(set) var runningAgents: [String] = []
    private(set) var isHeld: Bool = false

    /// Substring patterns matched against `ps` output. Editable via:
    /// `defaults write com.amjadkhalfan.Mudlej AgentPatterns -array claude codex ...`
    private var patterns: [String]

    private var activity: NSObjectProtocol?
    private var timer: Timer?
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let mode = "Mode"
        static let keepDisplayAwake = "KeepDisplayAwake"
        static let patterns = "AgentPatterns"
        static let language = "AppLanguage"
        static let lidClosedAwake = "LidClosedAwake"
    }

    static let defaultPatterns = ["claude", "codex", "cursor-agent", "aider"]

    init() {
        mode = Mode(rawValue: defaults.string(forKey: Keys.mode) ?? "") ?? .auto
        keepDisplayAwake = defaults.bool(forKey: Keys.keepDisplayAwake)
        // Reflects last intent only — we don't re-run pmset on launch (would re-prompt).
        lidClosedAwake = defaults.bool(forKey: Keys.lidClosedAwake)
        patterns = defaults.stringArray(forKey: Keys.patterns) ?? Self.defaultPatterns
        appLanguage = AppLanguage(rawValue: defaults.string(forKey: Keys.language) ?? "") ?? .system
        start()
    }

    // MARK: - Lifecycle

    private func start() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleTerminate),
            name: NSApplication.willTerminateNotification, object: nil)

        // Timer fires on the main run loop, so we're already MainActor-isolated.
        let t = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        tick()
    }

    @objc private func handleTerminate() {
        release()
        // Best-effort: restore system sleep. A prompt this late in tear-down is
        // unreliable — the Quit button restores earlier; see setLidClosedAwake.
        if lidClosedAwake { runDisableSleep(false) }
    }

    // MARK: - Poll + decide

    private func tick() {
        runningAgents = detectAgents()
        evaluate()
    }

    private func evaluate() {
        let shouldHold: Bool
        switch mode {
        case .alwaysOn:  shouldHold = true
        case .alwaysOff: shouldHold = false
        case .auto:      shouldHold = !runningAgents.isEmpty
        }
        shouldHold ? hold() : release()
    }

    /// Runs `/bin/ps -Axo comm=` and returns the patterns found in the output.
    /// On any failure returns `[]` — the manual modes still work without detection.
    /// ponytail: substring match; false-pos/neg documented in README.
    private func detectAgents() -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-Axo", "comm="]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let output = String(decoding: data, as: UTF8.self).lowercased()
            return patterns.filter { output.contains($0.lowercased()) }
        } catch {
            return []
        }
    }

    // MARK: - Assertion

    private func hold() {
        guard activity == nil else { return }
        var options: ProcessInfo.ActivityOptions = [.idleSystemSleepDisabled]
        if keepDisplayAwake { options.insert(.idleDisplaySleepDisabled) }
        activity = ProcessInfo.processInfo.beginActivity(
            options: options,
            reason: "Mudlej keeping the Mac awake for running agents")
        isHeld = true
    }

    func release() {
        guard let activity else { return }
        ProcessInfo.processInfo.endActivity(activity)
        self.activity = nil
        isHeld = false
    }

    private func reapplyIfHeld() {
        guard isHeld else { return }
        release()
        evaluate()
    }

    // MARK: - Lid-close sleep (root)

    /// Toggles `pmset disablesleep` — the only override for clamshell (lid-close)
    /// sleep, which power assertions don't cover. Persists only on success so the
    /// UI Toggle snaps back if the admin prompt is cancelled.
    func setLidClosedAwake(_ on: Bool) {
        guard on != lidClosedAwake else { return }
        guard runDisableSleep(on) else { return }
        lidClosedAwake = on
        defaults.set(on, forKey: Keys.lidClosedAwake)
    }

    /// Runs `pmset -a disablesleep 0/1` as root via the native admin prompt.
    /// ponytail: AppleScript admin prompt is the lazy path — needs root, prompts
    /// each toggle, and a crash/force-quit while enabled leaves disablesleep=1
    /// (the visible Toggle is the recovery path). Upgrade to an SMAppService
    /// daemon + XPC only if silent toggling / guaranteed restore-on-quit matters.
    @discardableResult
    private func runDisableSleep(_ disable: Bool) -> Bool {
        let src = "do shell script \"/usr/bin/pmset -a disablesleep \(disable ? 1 : 0)\""
                + " with administrator privileges"
        var err: NSDictionary?
        NSAppleScript(source: src)?.executeAndReturnError(&err)
        return err == nil
    }

    // MARK: - Launch at login

    var launchAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            // Best-effort: ignore (e.g. unsigned build, missing approval).
        }
    }
}
