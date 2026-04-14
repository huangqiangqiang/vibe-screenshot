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

public actor ScreenCaptureRunner {
    public static let shared = ScreenCaptureRunner()

    private var activeProcesses: [UUID: Process] = [:]

    public init() {}

    @discardableResult
    public func capture(mode: CaptureMode, destinationURL: URL = ScreenshotFileNamer.outputURL()) throws -> URL {
        let processID = UUID()
        let process = Process()

        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = mode.commandArguments + [destinationURL.path]
        process.terminationHandler = { _ in
            Task {
                await self.removeProcess(processID)
            }
        }

        activeProcesses[processID] = process

        do {
            try process.run()
            return destinationURL
        } catch {
            activeProcesses[processID] = nil
            throw error
        }
    }

    private func removeProcess(_ processID: UUID) {
        activeProcesses[processID] = nil
    }
}
