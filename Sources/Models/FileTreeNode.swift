import Foundation

struct FileTreeNode: Identifiable, Sendable {
    let id: String
    let name: String
    let isDirectory: Bool
    let children: [FileTreeNode]
}
