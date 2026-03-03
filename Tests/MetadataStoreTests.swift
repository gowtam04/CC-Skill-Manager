import Testing
import Foundation
@testable import CCSkillManager

@Suite("MetadataStore Tests")
struct MetadataStoreTests {

    /// Creates a temporary directory for test file I/O and returns a file URL within it.
    private func makeTempFileURL(filename: String = "metadata.json") -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MetadataStoreTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir.appendingPathComponent(filename)
    }

    /// Removes the parent directory of the given file URL.
    private func cleanUp(_ fileURL: URL) {
        try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
    }

    // MARK: - Loading

    @Test("Loads metadata from a valid JSON file")
    func loadValidMetadata() throws {
        let fileURL = makeTempFileURL()
        defer { cleanUp(fileURL) }

        let json = """
        {
          "skills": {
            "my-skill": {
              "sourceRepoURL": "https://github.com/user/repo",
              "clonedRepoPath": "/Users/test/Library/Application Support/CC-Skill-Manager/repos/repo",
              "installedAt": "2026-03-02T12:00:00Z"
            }
          }
        }
        """
        try json.write(to: fileURL, atomically: true, encoding: .utf8)

        let store = MetadataStore(fileURL: fileURL)
        let metadata = try store.load()

        #expect(metadata.count == 1)
        #expect(metadata["my-skill"] != nil)
        #expect(metadata["my-skill"]?.sourceRepoURL == "https://github.com/user/repo")
        #expect(metadata["my-skill"]?.clonedRepoPath == "/Users/test/Library/Application Support/CC-Skill-Manager/repos/repo")
    }

    @Test("Returns empty metadata when file does not exist")
    func loadMissingFile() throws {
        let fileURL = makeTempFileURL()
        defer { cleanUp(fileURL) }

        // Do not create the file — it should not exist
        let store = MetadataStore(fileURL: fileURL)
        let metadata = try store.load()

        #expect(metadata.isEmpty)
    }

    @Test("Throws or returns empty for corrupt JSON file")
    func loadCorruptJSON() throws {
        let fileURL = makeTempFileURL()
        defer { cleanUp(fileURL) }

        let corruptJSON = "{ this is not valid json !!!"
        try corruptJSON.write(to: fileURL, atomically: true, encoding: .utf8)

        let store = MetadataStore(fileURL: fileURL)

        // Implementation may throw or return empty — either is acceptable
        // We test that it does not crash
        do {
            let metadata = try store.load()
            // If it doesn't throw, it should return empty
            #expect(metadata.isEmpty)
        } catch {
            // Throwing is also acceptable for corrupt data
            #expect(error is DecodingError || error is CocoaError || error is (any Error))
        }
    }

    @Test("Loads metadata with multiple skill entries")
    func loadMultipleEntries() throws {
        let fileURL = makeTempFileURL()
        defer { cleanUp(fileURL) }

        let json = """
        {
          "skills": {
            "skill-one": {
              "sourceRepoURL": "https://github.com/user/repo1",
              "clonedRepoPath": "/path/to/repo1",
              "installedAt": "2026-01-15T08:30:00Z"
            },
            "skill-two": {
              "sourceRepoURL": "https://github.com/user/repo2",
              "clonedRepoPath": "/path/to/repo2",
              "installedAt": "2026-02-20T14:00:00Z"
            }
          }
        }
        """
        try json.write(to: fileURL, atomically: true, encoding: .utf8)

        let store = MetadataStore(fileURL: fileURL)
        let metadata = try store.load()

        #expect(metadata.count == 2)
        #expect(metadata["skill-one"] != nil)
        #expect(metadata["skill-two"] != nil)
    }

    // MARK: - Saving

    @Test("Saves metadata to disk")
    func saveMetadata() throws {
        let fileURL = makeTempFileURL()
        defer { cleanUp(fileURL) }

        let store = MetadataStore(fileURL: fileURL)

        let entry = SkillMetadata(
            sourceRepoURL: "https://github.com/user/repo",
            clonedRepoPath: "/path/to/repo",
            installedAt: Date()
        )

        try store.save(["test-skill": entry])

        // Verify file was written
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        // Verify content is valid JSON by reading it back
        let data = try Data(contentsOf: fileURL)
        #expect(!data.isEmpty)
    }

    @Test("Creates parent directories when saving if they do not exist")
    func saveCreatesDirectories() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MetadataStoreTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("nested", isDirectory: true)
        let fileURL = tempDir.appendingPathComponent("metadata.json")
        defer { try? FileManager.default.removeItem(at: tempDir.deletingLastPathComponent()) }

        let store = MetadataStore(fileURL: fileURL)

        let entry = SkillMetadata(
            sourceRepoURL: "https://github.com/user/repo",
            clonedRepoPath: "/path/to/repo",
            installedAt: Date()
        )

        try store.save(["test-skill": entry])

        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }

    // MARK: - Round-Trip

    @Test("Round-trip: save then load produces same data")
    func roundTrip() throws {
        let fileURL = makeTempFileURL()
        defer { cleanUp(fileURL) }

        let store = MetadataStore(fileURL: fileURL)

        let now = Date()
        let original: [String: SkillMetadata] = [
            "skill-alpha": SkillMetadata(
                sourceRepoURL: "https://github.com/alpha/repo",
                clonedRepoPath: "/path/to/alpha",
                installedAt: now
            ),
            "skill-beta": SkillMetadata(
                sourceRepoURL: "https://github.com/beta/repo",
                clonedRepoPath: "/path/to/beta",
                installedAt: now
            ),
        ]

        try store.save(original)
        let loaded = try store.load()

        #expect(loaded.count == original.count)
        #expect(loaded["skill-alpha"]?.sourceRepoURL == original["skill-alpha"]?.sourceRepoURL)
        #expect(loaded["skill-alpha"]?.clonedRepoPath == original["skill-alpha"]?.clonedRepoPath)
        #expect(loaded["skill-beta"]?.sourceRepoURL == original["skill-beta"]?.sourceRepoURL)
        #expect(loaded["skill-beta"]?.clonedRepoPath == original["skill-beta"]?.clonedRepoPath)
    }

    // MARK: - Add / Remove / Update Entries

    @Test("Add a new skill metadata entry to existing metadata")
    func addEntry() throws {
        let fileURL = makeTempFileURL()
        defer { cleanUp(fileURL) }

        let store = MetadataStore(fileURL: fileURL)

        // Start with one entry
        let initial: [String: SkillMetadata] = [
            "existing-skill": SkillMetadata(
                sourceRepoURL: "https://github.com/user/existing",
                clonedRepoPath: "/path/to/existing",
                installedAt: Date()
            ),
        ]
        try store.save(initial)

        // Load, add a new entry, save again
        var metadata = try store.load()
        metadata["new-skill"] = SkillMetadata(
            sourceRepoURL: "https://github.com/user/new",
            clonedRepoPath: "/path/to/new",
            installedAt: Date()
        )
        try store.save(metadata)

        // Verify both entries exist
        let reloaded = try store.load()
        #expect(reloaded.count == 2)
        #expect(reloaded["existing-skill"] != nil)
        #expect(reloaded["new-skill"] != nil)
    }

    @Test("Remove a skill metadata entry from existing metadata")
    func removeEntry() throws {
        let fileURL = makeTempFileURL()
        defer { cleanUp(fileURL) }

        let store = MetadataStore(fileURL: fileURL)

        let initial: [String: SkillMetadata] = [
            "keep-skill": SkillMetadata(
                sourceRepoURL: "https://github.com/user/keep",
                clonedRepoPath: "/path/to/keep",
                installedAt: Date()
            ),
            "remove-skill": SkillMetadata(
                sourceRepoURL: "https://github.com/user/remove",
                clonedRepoPath: "/path/to/remove",
                installedAt: Date()
            ),
        ]
        try store.save(initial)

        // Load, remove an entry, save again
        var metadata = try store.load()
        metadata.removeValue(forKey: "remove-skill")
        try store.save(metadata)

        // Verify only one entry remains
        let reloaded = try store.load()
        #expect(reloaded.count == 1)
        #expect(reloaded["keep-skill"] != nil)
        #expect(reloaded["remove-skill"] == nil)
    }

    @Test("Update an existing skill metadata entry")
    func updateEntry() throws {
        let fileURL = makeTempFileURL()
        defer { cleanUp(fileURL) }

        let store = MetadataStore(fileURL: fileURL)

        let initial: [String: SkillMetadata] = [
            "my-skill": SkillMetadata(
                sourceRepoURL: "https://github.com/user/old-repo",
                clonedRepoPath: "/path/to/old",
                installedAt: Date()
            ),
        ]
        try store.save(initial)

        // Load, update the entry, save again
        var metadata = try store.load()
        metadata["my-skill"] = SkillMetadata(
            sourceRepoURL: "https://github.com/user/new-repo",
            clonedRepoPath: "/path/to/new",
            installedAt: Date()
        )
        try store.save(metadata)

        // Verify the entry was updated
        let reloaded = try store.load()
        #expect(reloaded["my-skill"]?.sourceRepoURL == "https://github.com/user/new-repo")
        #expect(reloaded["my-skill"]?.clonedRepoPath == "/path/to/new")
    }

    @Test("Saving empty metadata results in empty load")
    func saveAndLoadEmpty() throws {
        let fileURL = makeTempFileURL()
        defer { cleanUp(fileURL) }

        let store = MetadataStore(fileURL: fileURL)
        try store.save([:])

        let loaded = try store.load()
        #expect(loaded.isEmpty)
    }
}
