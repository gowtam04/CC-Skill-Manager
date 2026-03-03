import Foundation

struct MetadataStore: Sendable {

    let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func load() throws -> [String: SkillMetadata] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return [:]
        }

        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let wrapper = try decoder.decode(MetadataWrapper.self, from: data)
        return wrapper.skills
    }

    func save(_ metadata: [String: SkillMetadata]) throws {
        let parentDir = fileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parentDir.path) {
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }

        let wrapper = MetadataWrapper(skills: metadata)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(wrapper)
        try data.write(to: fileURL, options: .atomic)
    }
}

private struct MetadataWrapper: Codable {
    let skills: [String: SkillMetadata]
}
