import SwiftUI

@main
struct AgentSkillManagerApp: App {
    @State private var viewModel: AppViewModel

    init() {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let skillsDir = homeDir.appendingPathComponent(".claude/skills", isDirectory: true)
        let disabledDir = homeDir.appendingPathComponent(".claude/skills-disabled", isDirectory: true)

        let appSupportDir: URL
        if let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            appSupportDir = support.appendingPathComponent("Agent-Skill-Manager", isDirectory: true)
        } else {
            appSupportDir = homeDir.appendingPathComponent("Library/Application Support/Agent-Skill-Manager", isDirectory: true)
        }

        let fileSystemManager = FileSystemManager(
            skillsDirectoryURL: skillsDir,
            disabledDirectoryURL: disabledDir
        )
        let metadataStore = MetadataStore(
            fileURL: appSupportDir.appendingPathComponent("metadata.json")
        )
        let skillManager = SkillManager(
            fileSystemManager: fileSystemManager,
            gitManager: GitManager(),
            skillParser: SkillParser.self,
            metadataStore: metadataStore
        )

        _viewModel = State(initialValue: AppViewModel(skillManager: skillManager))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
    }
}
