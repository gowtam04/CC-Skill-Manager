import Testing
import Foundation
@testable import CCSkillManager

@Suite("GitManager Tests")
struct GitManagerTests {

    // MARK: - Helpers

    /// Creates a temporary directory for test operations.
    private func makeTempDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GitManagerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    /// Removes the given directory and all its contents.
    private func cleanUp(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// Creates a local git repository for testing without network access.
    private func createLocalGitRepo(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["init"]
        process.currentDirectoryURL = url
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()

        // Create an initial commit so the repo has a valid HEAD
        let readmeURL = url.appendingPathComponent("README.md")
        try "Test repo".write(to: readmeURL, atomically: true, encoding: .utf8)

        let addProcess = Process()
        addProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        addProcess.arguments = ["add", "."]
        addProcess.currentDirectoryURL = url
        addProcess.standardOutput = FileHandle.nullDevice
        addProcess.standardError = FileHandle.nullDevice
        try addProcess.run()
        addProcess.waitUntilExit()

        let commitProcess = Process()
        commitProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        commitProcess.arguments = ["commit", "-m", "Initial commit"]
        commitProcess.currentDirectoryURL = url
        commitProcess.standardOutput = FileHandle.nullDevice
        commitProcess.standardError = FileHandle.nullDevice
        commitProcess.environment = [
            "GIT_AUTHOR_NAME": "Test",
            "GIT_AUTHOR_EMAIL": "test@test.com",
            "GIT_COMMITTER_NAME": "Test",
            "GIT_COMMITTER_EMAIL": "test@test.com"
        ]
        try commitProcess.run()
        commitProcess.waitUntilExit()
    }

    // MARK: - isGitRepository

    @Test("isGitRepository returns true for a git repository")
    func isGitRepoTrue() throws {
        let tempDir = try makeTempDirectory()
        defer { cleanUp(tempDir) }

        let repoDir = tempDir.appendingPathComponent("test-repo", isDirectory: true)
        try createLocalGitRepo(at: repoDir)

        let manager = GitManager()
        #expect(manager.isGitRepository(at: repoDir))
    }

    @Test("isGitRepository returns false for a non-git directory")
    func isGitRepoFalse() throws {
        let tempDir = try makeTempDirectory()
        defer { cleanUp(tempDir) }

        let plainDir = tempDir.appendingPathComponent("not-a-repo", isDirectory: true)
        try FileManager.default.createDirectory(at: plainDir, withIntermediateDirectories: true)

        let manager = GitManager()
        #expect(!manager.isGitRepository(at: plainDir))
    }

    @Test("isGitRepository returns false for a non-existent directory")
    func isGitRepoNonExistent() throws {
        let tempDir = try makeTempDirectory()
        defer { cleanUp(tempDir) }

        let nonExistent = tempDir.appendingPathComponent("does-not-exist")

        let manager = GitManager()
        #expect(!manager.isGitRepository(at: nonExistent))
    }

    // MARK: - Clone

    @Test("Clone from a local bare repo creates a valid git repository")
    func cloneLocalRepo() async throws {
        let tempDir = try makeTempDirectory()
        defer { cleanUp(tempDir) }

        // Create a bare repo to clone from (simulates a remote without network)
        let bareRepoDir = tempDir.appendingPathComponent("bare-repo.git", isDirectory: true)
        try FileManager.default.createDirectory(at: bareRepoDir, withIntermediateDirectories: true)

        let initProcess = Process()
        initProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        initProcess.arguments = ["init", "--bare"]
        initProcess.currentDirectoryURL = bareRepoDir
        initProcess.standardOutput = FileHandle.nullDevice
        initProcess.standardError = FileHandle.nullDevice
        try initProcess.run()
        initProcess.waitUntilExit()

        // Clone the bare repo into a working copy, then push a commit back
        let workingDir = tempDir.appendingPathComponent("working", isDirectory: true)
        let cloneWorkingProcess = Process()
        cloneWorkingProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        cloneWorkingProcess.arguments = ["clone", bareRepoDir.path, workingDir.path]
        cloneWorkingProcess.standardOutput = FileHandle.nullDevice
        cloneWorkingProcess.standardError = FileHandle.nullDevice
        try cloneWorkingProcess.run()
        cloneWorkingProcess.waitUntilExit()

        // Add a file and push to bare repo
        try "Hello".write(
            to: workingDir.appendingPathComponent("README.md"),
            atomically: true,
            encoding: .utf8
        )
        for (args, env) in [
            (["add", "."], [:] as [String: String]),
            (["commit", "-m", "init"], [
                "GIT_AUTHOR_NAME": "Test",
                "GIT_AUTHOR_EMAIL": "test@test.com",
                "GIT_COMMITTER_NAME": "Test",
                "GIT_COMMITTER_EMAIL": "test@test.com"
            ]),
            (["push"], [:]),
        ] {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            p.arguments = args
            p.currentDirectoryURL = workingDir
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
            if !env.isEmpty { p.environment = env }
            try p.run()
            p.waitUntilExit()
        }

        // Now test the GitManager's clone
        let destinationDir = tempDir.appendingPathComponent("cloned-output", isDirectory: true)
        let manager = GitManager()
        try await manager.clone(repoURL: bareRepoDir.path, to: destinationDir)

        #expect(manager.isGitRepository(at: destinationDir))
        #expect(FileManager.default.fileExists(
            atPath: destinationDir.appendingPathComponent("README.md").path
        ))
    }

    @Test("Clone throws for invalid URL")
    func cloneInvalidURL() async throws {
        let tempDir = try makeTempDirectory()
        defer { cleanUp(tempDir) }

        let destinationDir = tempDir.appendingPathComponent("output", isDirectory: true)
        let manager = GitManager()

        await #expect(throws: (any Error).self) {
            try await manager.clone(repoURL: "not-a-valid-url-at-all", to: destinationDir)
        }
    }

    @Test("Clone throws for non-existent repository path")
    func cloneNonExistentRepo() async throws {
        let tempDir = try makeTempDirectory()
        defer { cleanUp(tempDir) }

        let destinationDir = tempDir.appendingPathComponent("output", isDirectory: true)
        let manager = GitManager()

        await #expect(throws: (any Error).self) {
            try await manager.clone(
                repoURL: "/tmp/definitely-does-not-exist-\(UUID().uuidString)",
                to: destinationDir
            )
        }
    }

    // MARK: - Pull

    @Test("Pull in a valid git repo succeeds")
    func pullInValidRepo() async throws {
        let tempDir = try makeTempDirectory()
        defer { cleanUp(tempDir) }

        // Set up a bare repo and a clone (so pull has a remote)
        let bareRepoDir = tempDir.appendingPathComponent("bare.git", isDirectory: true)
        try FileManager.default.createDirectory(at: bareRepoDir, withIntermediateDirectories: true)

        let initP = Process()
        initP.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        initP.arguments = ["init", "--bare"]
        initP.currentDirectoryURL = bareRepoDir
        initP.standardOutput = FileHandle.nullDevice
        initP.standardError = FileHandle.nullDevice
        try initP.run()
        initP.waitUntilExit()

        let cloneDir = tempDir.appendingPathComponent("clone", isDirectory: true)
        let cloneP = Process()
        cloneP.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        cloneP.arguments = ["clone", bareRepoDir.path, cloneDir.path]
        cloneP.standardOutput = FileHandle.nullDevice
        cloneP.standardError = FileHandle.nullDevice
        try cloneP.run()
        cloneP.waitUntilExit()

        // Add initial commit
        try "initial".write(
            to: cloneDir.appendingPathComponent("file.txt"),
            atomically: true,
            encoding: .utf8
        )
        for (args, env) in [
            (["add", "."], [:] as [String: String]),
            (["commit", "-m", "initial"], [
                "GIT_AUTHOR_NAME": "Test",
                "GIT_AUTHOR_EMAIL": "test@test.com",
                "GIT_COMMITTER_NAME": "Test",
                "GIT_COMMITTER_EMAIL": "test@test.com"
            ]),
            (["push"], [:]),
        ] {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            p.arguments = args
            p.currentDirectoryURL = cloneDir
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
            if !env.isEmpty { p.environment = env }
            try p.run()
            p.waitUntilExit()
        }

        let manager = GitManager()
        let output = try await manager.pull(in: cloneDir)

        // Pull output should be a string (could be "Already up to date." or similar)
        #expect(output is String)
    }

    @Test("Pull returns output string")
    func pullReturnsOutput() async throws {
        let tempDir = try makeTempDirectory()
        defer { cleanUp(tempDir) }

        // Set up bare repo + clone for pull
        let bareRepoDir = tempDir.appendingPathComponent("bare.git", isDirectory: true)
        try FileManager.default.createDirectory(at: bareRepoDir, withIntermediateDirectories: true)

        let initP = Process()
        initP.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        initP.arguments = ["init", "--bare"]
        initP.currentDirectoryURL = bareRepoDir
        initP.standardOutput = FileHandle.nullDevice
        initP.standardError = FileHandle.nullDevice
        try initP.run()
        initP.waitUntilExit()

        let cloneDir = tempDir.appendingPathComponent("clone", isDirectory: true)
        let cloneP = Process()
        cloneP.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        cloneP.arguments = ["clone", bareRepoDir.path, cloneDir.path]
        cloneP.standardOutput = FileHandle.nullDevice
        cloneP.standardError = FileHandle.nullDevice
        try cloneP.run()
        cloneP.waitUntilExit()

        try "content".write(
            to: cloneDir.appendingPathComponent("file.txt"),
            atomically: true,
            encoding: .utf8
        )
        for (args, env) in [
            (["add", "."], [:] as [String: String]),
            (["commit", "-m", "init"], [
                "GIT_AUTHOR_NAME": "Test",
                "GIT_AUTHOR_EMAIL": "test@test.com",
                "GIT_COMMITTER_NAME": "Test",
                "GIT_COMMITTER_EMAIL": "test@test.com"
            ]),
            (["push"], [:]),
        ] {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            p.arguments = args
            p.currentDirectoryURL = cloneDir
            p.standardOutput = FileHandle.nullDevice
            p.standardError = FileHandle.nullDevice
            if !env.isEmpty { p.environment = env }
            try p.run()
            p.waitUntilExit()
        }

        let manager = GitManager()
        let output = try await manager.pull(in: cloneDir)

        // Output should be non-empty and contain git's response
        #expect(!output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    // MARK: - Edge Cases

    @Test("Pull in a non-git directory throws")
    func pullInNonGitDirectory() async throws {
        let tempDir = try makeTempDirectory()
        defer { cleanUp(tempDir) }

        let plainDir = tempDir.appendingPathComponent("plain", isDirectory: true)
        try FileManager.default.createDirectory(at: plainDir, withIntermediateDirectories: true)

        let manager = GitManager()

        await #expect(throws: (any Error).self) {
            try await manager.pull(in: plainDir)
        }
    }
}
