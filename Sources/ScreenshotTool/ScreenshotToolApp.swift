import AppKit
import ScreenshotCore
import SwiftUI

@MainActor
final class ScreenshotMenuModel: ObservableObject {
    func captureArea() {
        scheduleCapture(for: .area)
    }

    func captureFullScreen() {
        scheduleCapture(for: .fullScreen)
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func scheduleCapture(for mode: CaptureMode) {
        Task.detached {
            try? await Task.sleep(nanoseconds: 200_000_000)

            do {
                _ = try await ScreenCaptureRunner.shared.capture(mode: mode)
            } catch {
                NSLog("Capture failed: \(error.localizedDescription)")
            }
        }
    }
}

@main
struct ScreenshotToolApp: App {
    @StateObject private var menuModel = ScreenshotMenuModel()

    var body: some Scene {
        MenuBarExtra {
            Button("区域截图") {
                menuModel.captureArea()
            }

            Button("全屏截图") {
                menuModel.captureFullScreen()
            }

            Divider()

            Button("退出") {
                menuModel.quit()
            }
        } label: {
            Image(systemName: "camera.viewfinder")
        }
        .menuBarExtraStyle(.menu)
    }
}
