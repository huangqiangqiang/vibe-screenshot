import AppKit
import Foundation

public enum CaptureMode: Sendable {
    case area
    case fullScreen

    fileprivate var commandArguments: [String] {
        switch self {
        case .area:
            return ["-i", "-x"]
        case .fullScreen:
            return ["-x"]
        }
    }
}

public enum CaptureSavePolicy: Sendable {
    case desktop
    case clipboardOnly
}

public enum ScreenshotFileNamer {
    public static func outputURL(
        date: Date = Date(),
        fileManager: FileManager = .default,
        timeZone: TimeZone = .current
    ) -> URL {
        let desktopURL = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Desktop", isDirectory: true)

        return desktopURL.appendingPathComponent("shot-(\(timestamp(for: date, timeZone: timeZone))).png")
    }

    public static func timestamp(for date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        return formatter.string(from: date)
    }
}

public enum CaptureError: LocalizedError {
    case cancelled
    case failed(Int32)
    case outputUnavailable
    case clipboardWriteFailed
    case desktopSaveFailed

    public var errorDescription: String? {
        switch self {
        case .cancelled:
            return "The screenshot was cancelled."
        case let .failed(status):
            return "The screenshot command failed with exit status \(status)."
        case .outputUnavailable:
            return "The screenshot file was not created."
        case .clipboardWriteFailed:
            return "The screenshot was captured, but copying it to the clipboard failed."
        case .desktopSaveFailed:
            return "The screenshot was copied to the clipboard, but saving it to the Desktop failed."
        }
    }
}

public actor ScreenCaptureRunner {
    public static let shared = ScreenCaptureRunner()

    private var activeProcesses: [UUID: Process] = [:]
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    @discardableResult
    public func capture(
        mode: CaptureMode,
        savePolicy: CaptureSavePolicy = .desktop,
        destinationURL: URL? = nil
    ) async throws -> URL? {
        let processID = UUID()
        let process = Process()
        let temporaryCaptureURL = makeTemporaryCaptureURL()
        let desktopDestinationURL = savePolicy == .desktop
            ? (destinationURL ?? ScreenshotFileNamer.outputURL(fileManager: fileManager))
            : nil

        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = mode.commandArguments + [temporaryCaptureURL.path]

        activeProcesses[processID] = process

        do {
            try process.run()
            let terminationStatus = await waitForTermination(of: process)
            activeProcesses[processID] = nil

            guard terminationStatus == 0 else {
                if terminationStatus == 1 {
                    throw CaptureError.cancelled
                }

                throw CaptureError.failed(terminationStatus)
            }

            let outputURL = try await waitForOutput(at: temporaryCaptureURL)
            try await copyImageDataToPasteboard(from: outputURL)

            guard let desktopDestinationURL else {
                try removeTemporaryFile(at: outputURL)
                return nil
            }

            do {
                try moveCapturedImage(from: outputURL, to: desktopDestinationURL)
                return desktopDestinationURL
            } catch {
                try? removeTemporaryFile(at: outputURL)
                throw CaptureError.desktopSaveFailed
            }
        } catch {
            activeProcesses[processID] = nil
            try? removeTemporaryFile(at: temporaryCaptureURL)
            throw error
        }
    }

    private func waitForTermination(of process: Process) async -> Int32 {
        await Task.detached(priority: .userInitiated) {
            process.waitUntilExit()
            return process.terminationStatus
        }.value
    }

    private func waitForOutput(at url: URL) async throws -> URL {
        for _ in 0..<20 {
            if fileManager.fileExists(atPath: url.path) {
                return url
            }

            try await Task.sleep(nanoseconds: 50_000_000)
        }

        throw CaptureError.outputUnavailable
    }

    private func copyImageDataToPasteboard(from url: URL) async throws {
        let imageData = try Data(contentsOf: url)
        guard let image = NSImage(contentsOf: url) else {
            throw CaptureError.clipboardWriteFailed
        }

        let didWrite = await MainActor.run { () -> Bool in
            let item = NSPasteboardItem()
            item.setData(imageData, forType: .png)

            if let tiffData = image.tiffRepresentation {
                item.setData(tiffData, forType: .tiff)
            }

            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            return pasteboard.writeObjects([item])
        }

        if !didWrite {
            throw CaptureError.clipboardWriteFailed
        }
    }

    private func makeTemporaryCaptureURL() -> URL {
        fileManager.temporaryDirectory
            .appendingPathComponent("shot-\(UUID().uuidString)")
            .appendingPathExtension("png")
    }

    private func moveCapturedImage(from sourceURL: URL, to destinationURL: URL) throws {
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.moveItem(at: sourceURL, to: destinationURL)
    }

    private func removeTemporaryFile(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }

        try fileManager.removeItem(at: url)
    }
}
