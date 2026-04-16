import AppKit
import ScreenshotCore
import SwiftUI

@MainActor
final class ScreenshotPreferences {
    private static let saveToDesktopKey = "saveScreenshotToDesktop"
    private let userDefaults: UserDefaults

    var shouldSaveToDesktop: Bool {
        didSet {
            userDefaults.set(shouldSaveToDesktop, forKey: Self.saveToDesktopKey)
        }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.shouldSaveToDesktop = userDefaults.object(forKey: Self.saveToDesktopKey) as? Bool ?? true
    }

    var savePolicy: CaptureSavePolicy {
        shouldSaveToDesktop ? .desktop : .clipboardOnly
    }
}

@MainActor
final class ScreenshotStatusController: NSObject {
    private let preferences = ScreenshotPreferences()
    private var statusItem: NSStatusItem?

    func install() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            let image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "ScreenshotTool")
            button.image = image?.withSymbolConfiguration(configuration)
            button.image?.isTemplate = true
            button.toolTip = "ScreenshotTool"
        }

        statusItem.menu = buildMenu()
        self.statusItem = statusItem
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        menu.addItem(makeActionItem(title: "区域截图", action: #selector(captureArea)))
        menu.addItem(makeActionItem(title: "全屏截图", action: #selector(captureFullScreen)))
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "设置", action: nil, keyEquivalent: "")
        settingsItem.submenu = buildSettingsSubmenu()
        menu.addItem(settingsItem)
        menu.addItem(makeActionItem(title: "退出", action: #selector(quit)))

        return menu
    }

    private func buildSettingsSubmenu() -> NSMenu {
        let submenu = NSMenu(title: "设置")
        submenu.autoenablesItems = false

        let saveToDesktopItem = NSMenuItem()
        saveToDesktopItem.view = makeSaveToDesktopSwitchView()
        submenu.addItem(saveToDesktopItem)

        return submenu
    }

    private func makeActionItem(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func makeSaveToDesktopSwitchView() -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 30))

        let label = NSTextField(labelWithString: "生成截图到桌面")
        label.font = NSFont.menuFont(ofSize: 0)
        label.translatesAutoresizingMaskIntoConstraints = false

        let toggle = NSSwitch()
        toggle.state = preferences.shouldSaveToDesktop ? .on : .off
        toggle.target = self
        toggle.action = #selector(toggleSaveToDesktop(_:))
        toggle.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(label)
        container.addSubview(toggle)

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 220),
            container.heightAnchor.constraint(equalToConstant: 30),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            toggle.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            toggle.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -12)
        ])

        return container
    }

    @objc
    private func toggleSaveToDesktop(_ sender: NSSwitch) {
        preferences.shouldSaveToDesktop = sender.state == .on
    }

    @objc
    private func captureArea() {
        scheduleCapture(for: .area)
    }

    @objc
    private func captureFullScreen() {
        scheduleCapture(for: .fullScreen)
    }

    @objc
    private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func scheduleCapture(for mode: CaptureMode) {
        statusItem?.menu?.cancelTracking()
        let savePolicy = preferences.savePolicy

        Task.detached {
            try? await Task.sleep(nanoseconds: 200_000_000)

            do {
                _ = try await ScreenCaptureRunner.shared.capture(mode: mode, savePolicy: savePolicy)
            } catch CaptureError.cancelled {
                return
            } catch {
                NSLog("Capture failed: \(error.localizedDescription)")
            }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusController = ScreenshotStatusController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusController.install()
    }
}

@main
struct ScreenshotToolApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
