import Foundation

struct SkillMetadata: Codable, Sendable {
    let sourceRepoURL: String
    let clonedRepoPath: String
    let installedAt: Date
}
