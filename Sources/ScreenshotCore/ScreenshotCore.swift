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

    public var errorDescription: String? {
        switch self {
        case .cancelled:
            return "The screenshot was cancelled."
        case let .failed(status):
            return "The screenshot command failed with exit status \(status)."
        case .outputUnavailable:
            return "The screenshot file was not created."
        case .clipboardWriteFailed:
            return "The screenshot was saved, but copying it to the clipboard failed."
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
        let resolvedDestinationURL = destinationURL ?? makeDestinationURL(for: savePolicy)
        let shouldRemoveAfterCopy = savePolicy == .clipboardOnly

        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = mode.commandArguments + [resolvedDestinationURL.path]

        activeProcesses[processID] = process

        do {
            try process.run()
            let terminationStatus = try await waitForTermination(of: process)
            activeProcesses[processID] = nil

            guard terminationStatus == 0 else {
                if terminationStatus == 1 {
                    throw CaptureError.cancelled
                }

                throw CaptureError.failed(terminationStatus)
            }

            let outputURL = try await waitForOutput(at: resolvedDestinationURL)
            try await copyImageDataToPasteboard(from: outputURL)

            if shouldRemoveAfterCopy {
                try removeTemporaryFile(at: outputURL)
                return nil
            }

            return outputURL
        } catch {
            activeProcesses[processID] = nil

            if shouldRemoveAfterCopy {
                try? removeTemporaryFile(at: resolvedDestinationURL)
            }

            throw error
        }
    }

    private func waitForTermination(of process: Process) async throws -> Int32 {
        try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { process in
                continuation.resume(returning: process.terminationStatus)
            }
        }
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

        let didWrite = await MainActor.run { () -> Bool in
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            return pasteboard.setData(imageData, forType: .png)
        }

        if !didWrite {
            throw CaptureError.clipboardWriteFailed
        }
    }

    private func makeDestinationURL(for savePolicy: CaptureSavePolicy) -> URL {
        switch savePolicy {
        case .desktop:
            return ScreenshotFileNamer.outputURL(fileManager: fileManager)
        case .clipboardOnly:
            return fileManager.temporaryDirectory
                .appendingPathComponent("shot-\(UUID().uuidString)")
                .appendingPathExtension("png")
        }
    }

    private func removeTemporaryFile(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }

        try fileManager.removeItem(at: url)
    }
}
