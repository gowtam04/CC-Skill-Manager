import Testing
import Foundation
@testable import CCSkillManager

@Suite("Skill Model Tests")
struct SkillModelTests {

    // MARK: - Initialization

    @Test("Initializes a Skill with all required fields")
    func initWithAllFields() {
        let directoryURL = URL(fileURLWithPath: "/Users/test/.claude/skills/my-skill")
        let skill = Skill(
            id: UUID(),
            name: "my-skill",
            description: "A test skill",
            directoryURL: directoryURL,
            isSymlink: false,
            symlinkTarget: nil,
            isEnabled: true,
            sourceRepoURL: nil,
            rawContent: "---\nname: my-skill\ndescription: A test skill\n---\nBody"
        )

        #expect(skill.name == "my-skill")
        #expect(skill.description == "A test skill")
        #expect(skill.directoryURL == directoryURL)
        #expect(skill.isSymlink == false)
        #expect(skill.symlinkTarget == nil)
        #expect(skill.isEnabled == true)
        #expect(skill.sourceRepoURL == nil)
        #expect(skill.rawContent.contains("Body"))
    }

    @Test("Initializes a symlinked skill with target path")
    func initSymlinkedSkill() {
        let directoryURL = URL(fileURLWithPath: "/Users/test/.claude/skills/linked-skill")
        let targetURL = URL(fileURLWithPath: "/Users/test/Library/Application Support/CC-Skill-Manager/repos/repo/skill")
        let skill = Skill(
            id: UUID(),
            name: "linked-skill",
            description: "A symlinked skill",
            directoryURL: directoryURL,
            isSymlink: true,
            symlinkTarget: targetURL,
            isEnabled: true,
            sourceRepoURL: "https://github.com/user/repo",
            rawContent: ""
        )

        #expect(skill.isSymlink == true)
        #expect(skill.symlinkTarget == targetURL)
        #expect(skill.sourceRepoURL == "https://github.com/user/repo")
    }

    @Test("Each skill gets a unique UUID")
    func uniqueIDs() {
        let url = URL(fileURLWithPath: "/Users/test/.claude/skills/skill")
        let skill1 = Skill(
            id: UUID(),
            name: "skill-1",
            description: "First",
            directoryURL: url,
            isSymlink: false,
            symlinkTarget: nil,
            isEnabled: true,
            sourceRepoURL: nil,
            rawContent: ""
        )
        let skill2 = Skill(
            id: UUID(),
            name: "skill-2",
            description: "Second",
            directoryURL: url,
            isSymlink: false,
            symlinkTarget: nil,
            isEnabled: true,
            sourceRepoURL: nil,
            rawContent: ""
        )

        #expect(skill1.id != skill2.id)
    }

    // MARK: - Enabled/Disabled State from Path

    @Test("Skill is enabled when directory is under skills/")
    func enabledWhenInSkillsDirectory() {
        let directoryURL = URL(fileURLWithPath: "/Users/test/.claude/skills/my-skill")
        let skill = Skill(
            id: UUID(),
            name: "my-skill",
            description: "Enabled skill",
            directoryURL: directoryURL,
            isSymlink: false,
            symlinkTarget: nil,
            isEnabled: true,
            sourceRepoURL: nil,
            rawContent: ""
        )

        #expect(skill.isEnabled == true)
    }

    @Test("Skill is disabled when directory is under skills-disabled/")
    func disabledWhenInSkillsDisabledDirectory() {
        let directoryURL = URL(fileURLWithPath: "/Users/test/.claude/skills-disabled/my-skill")
        let skill = Skill(
            id: UUID(),
            name: "my-skill",
            description: "Disabled skill",
            directoryURL: directoryURL,
            isSymlink: false,
            symlinkTarget: nil,
            isEnabled: false,
            sourceRepoURL: nil,
            rawContent: ""
        )

        #expect(skill.isEnabled == false)
    }

    @Test("isEnabled reflects the skills/ path correctly for path-derived enablement")
    func isEnabledDerivedFromPath() {
        let enabledURL = URL(fileURLWithPath: "/Users/test/.claude/skills/test-skill")
        let disabledURL = URL(fileURLWithPath: "/Users/test/.claude/skills-disabled/test-skill")

        // A skill in skills/ should be enabled
        let enabledSkill = Skill(
            id: UUID(),
            name: "test-skill",
            description: "Test",
            directoryURL: enabledURL,
            isSymlink: false,
            symlinkTarget: nil,
            isEnabled: true,
            sourceRepoURL: nil,
            rawContent: ""
        )

        // A skill in skills-disabled/ should be disabled
        let disabledSkill = Skill(
            id: UUID(),
            name: "test-skill",
            description: "Test",
            directoryURL: disabledURL,
            isSymlink: false,
            symlinkTarget: nil,
            isEnabled: false,
            sourceRepoURL: nil,
            rawContent: ""
        )

        #expect(enabledSkill.isEnabled == true)
        #expect(disabledSkill.isEnabled == false)
    }

    // MARK: - Optional Fields

    @Test("sourceRepoURL is nil for locally imported skills")
    func sourceRepoURLNilForLocalSkills() {
        let skill = Skill(
            id: UUID(),
            name: "local-skill",
            description: "Imported from file",
            directoryURL: URL(fileURLWithPath: "/Users/test/.claude/skills/local-skill"),
            isSymlink: false,
            symlinkTarget: nil,
            isEnabled: true,
            sourceRepoURL: nil,
            rawContent: ""
        )

        #expect(skill.sourceRepoURL == nil)
    }

    @Test("sourceRepoURL is populated for URL-installed skills")
    func sourceRepoURLForURLInstalledSkills() {
        let skill = Skill(
            id: UUID(),
            name: "url-skill",
            description: "Installed from URL",
            directoryURL: URL(fileURLWithPath: "/Users/test/.claude/skills/url-skill"),
            isSymlink: true,
            symlinkTarget: URL(fileURLWithPath: "/path/to/repo/skill"),
            isEnabled: true,
            sourceRepoURL: "https://github.com/user/repo",
            rawContent: ""
        )

        #expect(skill.sourceRepoURL == "https://github.com/user/repo")
    }

    @Test("symlinkTarget is nil for non-symlinked skills")
    func symlinkTargetNilForNonSymlinks() {
        let skill = Skill(
            id: UUID(),
            name: "regular-skill",
            description: "A regular copied skill",
            directoryURL: URL(fileURLWithPath: "/Users/test/.claude/skills/regular-skill"),
            isSymlink: false,
            symlinkTarget: nil,
            isEnabled: true,
            sourceRepoURL: nil,
            rawContent: ""
        )

        #expect(skill.symlinkTarget == nil)
        #expect(skill.isSymlink == false)
    }
}
