import Foundation

struct DiscoveredSkill: Sendable {
    let directoryURL: URL
    let isEnabled: Bool
    let isSymlink: Bool
    let symlinkTarget: URL?
    let skillMDContent: String
}

struct FileSystemManager: Sendable {

    let skillsDirectoryURL: URL
    let disabledDirectoryURL: URL

    init(skillsDirectoryURL: URL, disabledDirectoryURL: URL) {
        self.skillsDirectoryURL = skillsDirectoryURL
        self.disabledDirectoryURL = disabledDirectoryURL
    }

    // MARK: - Scanning

    func scanSkills() throws -> [DiscoveredSkill] {
        var results: [DiscoveredSkill] = []

        if FileManager.default.fileExists(atPath: skillsDirectoryURL.path) {
            let enabledSkills = try scanDirectory(skillsDirectoryURL, isEnabled: true)
            results.append(contentsOf: enabledSkills)
        }

        if FileManager.default.fileExists(atPath: disabledDirectoryURL.path) {
            let disabledSkills = try scanDirectory(disabledDirectoryURL, isEnabled: false)
            results.append(contentsOf: disabledSkills)
        }

        return results
    }

    private func scanDirectory(_ directoryURL: URL, isEnabled: Bool) throws -> [DiscoveredSkill] {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        var results: [DiscoveredSkill] = []

        for itemURL in contents {
            let skillMDURL = itemURL.appendingPathComponent("SKILL.md")

            // Only include directories that contain a SKILL.md
            guard fm.fileExists(atPath: skillMDURL.path) else { continue }

            let content = try String(contentsOf: skillMDURL, encoding: .utf8)
            let symlink = isSymlink(at: itemURL)
            let target: URL? = symlink ? (try? resolveSymlink(at: itemURL)) : nil

            results.append(DiscoveredSkill(
                directoryURL: itemURL,
                isEnabled: isEnabled,
                isSymlink: symlink,
                symlinkTarget: target,
                skillMDContent: content
            ))
        }

        return results
    }

    // MARK: - Copy

    func copySkill(from sourceURL: URL, to name: String) throws {
        let fm = FileManager.default
        let destinationURL = skillsDirectoryURL.appendingPathComponent(name)

        // Remove existing if present
        if fm.fileExists(atPath: destinationURL.path) {
            try fm.removeItem(at: destinationURL)
        }

        try fm.copyItem(at: sourceURL, to: destinationURL)
    }

    // MARK: - Move

    func moveSkill(from sourceURL: URL, to destinationURL: URL) throws {
        let fm = FileManager.default

        // Check for naming conflict
        if fm.fileExists(atPath: destinationURL.path) {
            throw FileSystemManagerError.nameConflict(destinationURL.lastPathComponent)
        }

        try fm.moveItem(at: sourceURL, to: destinationURL)
    }

    // MARK: - Delete

    func deleteSkill(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    // MARK: - Symlink Operations

    func isSymlink(at url: URL) -> Bool {
        let fm = FileManager.default
        do {
            let attrs = try fm.attributesOfItem(atPath: url.path)
            return attrs[.type] as? FileAttributeType == .typeSymbolicLink
        } catch {
            return false
        }
    }

    func resolveSymlink(at url: URL) throws -> URL {
        let resolved = try FileManager.default.destinationOfSymbolicLink(atPath: url.path)
        let resolvedURL: URL
        if resolved.hasPrefix("/") {
            resolvedURL = URL(fileURLWithPath: resolved)
        } else {
            resolvedURL = url.deletingLastPathComponent().appendingPathComponent(resolved)
        }
        return resolvedURL.standardizedFileURL
    }

    func createSymlink(at symlinkURL: URL, pointingTo targetURL: URL) throws {
        try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: targetURL)
    }

    // MARK: - Directory Helpers

    func ensureDirectoryExists(at url: URL) throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}

enum FileSystemManagerError: Error, LocalizedError {
    case nameConflict(String)

    var errorDescription: String? {
        switch self {
        case .nameConflict(let name):
            return "A skill named '\(name)' already exists in the target directory."
        }
    }
}
