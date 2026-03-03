import Foundation

struct GitManager: Sendable {

    // MARK: - Clone

    func clone(repoURL: String, to destinationURL: URL) async throws {
        try await runGit(["clone", "--", repoURL, destinationURL.path])
    }

    // MARK: - Pull

    func pull(in directoryURL: URL) async throws -> String {
        return try await runGit(["pull"], currentDirectory: directoryURL)
    }

    // MARK: - Repository Detection

    func isGitRepository(at url: URL) -> Bool {
        let gitDir = url.appendingPathComponent(".git")
        return FileManager.default.fileExists(atPath: gitDir.path)
    }

    // MARK: - Private Helpers

    @discardableResult
    private func runGit(
        _ arguments: [String],
        currentDirectory: URL? = nil
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = arguments
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            if let currentDirectory {
                process.currentDirectoryURL = currentDirectory
            }

            process.terminationHandler = { process in
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""

                if process.terminationStatus == 0 {
                    let output = stdout.isEmpty ? stderr : stdout
                    continuation.resume(returning: output)
                } else {
                    let errorMessage = stderr.isEmpty ? stdout : stderr
                    continuation.resume(throwing: GitManagerError.commandFailed(
                        exitCode: process.terminationStatus,
                        message: errorMessage.trimmingCharacters(in: .whitespacesAndNewlines)
                    ))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

enum GitManagerError: Error, LocalizedError {
    case commandFailed(exitCode: Int32, message: String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(_, let message):
            return "Git command failed: \(message)"
        }
    }
}
