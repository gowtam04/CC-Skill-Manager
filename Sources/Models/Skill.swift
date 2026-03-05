import Foundation

struct Skill: Identifiable, Sendable {
    let id: UUID
    let name: String
    let description: String
    let directoryURL: URL
    let isSymlink: Bool
    let symlinkTarget: URL?
    let isEnabled: Bool
    let sourceRepoURL: String?
    let rawContent: String
    let fileTree: [FileTreeNode]
}
