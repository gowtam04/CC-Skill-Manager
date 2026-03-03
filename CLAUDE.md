# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

This project uses XcodeGen to generate the Xcode project from `project.yml`. Always regenerate after changing the project configuration or adding/removing source files.

```bash
# Regenerate Xcode project (required after adding/removing files)
xcodegen generate

# Build
xcodebuild build -project CCSkillManager.xcodeproj -scheme CCSkillManager -destination 'platform=macOS'

# Run all tests (109 tests across 8 suites)
xcodebuild test -project CCSkillManager.xcodeproj -scheme CCSkillManager -destination 'platform=macOS'

# Run a single test suite
xcodebuild test -project CCSkillManager.xcodeproj -scheme CCSkillManager -destination 'platform=macOS' -only-testing:CCSkillManagerTests/SkillParserTests

# Run a single test
xcodebuild test -project CCSkillManager.xcodeproj -scheme CCSkillManager -destination 'platform=macOS' -only-testing:CCSkillManagerTests/SkillParserTests/testParseValidFrontmatter
```

Note: The test target is `CCSkillManagerTests` but runs under the `CCSkillManager` scheme (no separate test scheme).

## Architecture

Three-layer architecture with unidirectional data flow:

```
Views → AppViewModel → SkillManager → { FileSystemManager, GitManager, SkillParser, MetadataStore }
                                         ↕                    ↕
                                    ~/.claude/skills/     git CLI (Process)
```

- **Models** (`Sources/Models/`): `Skill` (core data type) and `SkillMetadata` (Codable struct for metadata.json entries). All `Sendable`.
- **Services** (`Sources/Services/`): Business logic layer. `SkillManager` is the main orchestrator (`@MainActor @Observable`), coordinating `FileSystemManager` (directory scanning, copy/move/delete, symlink ops), `GitManager` (git clone/pull via `Process`), `SkillParser` (YAML frontmatter extraction), and `MetadataStore` (JSON persistence).
- **ViewModels** (`Sources/ViewModels/`): Single `AppViewModel` (`@MainActor @Observable`) wrapping `SkillManager`, adding UI-specific state (search, selection, editor, sheet/alert flags).
- **Views** (`Sources/Views/`): SwiftUI views using `NavigationSplitView`. `ContentView` is the root container; `SidebarView`, `DetailPanelView`, `EditorView`, `AddSkillView` are composed within it.

## Key Conventions

- **Swift 6 strict concurrency** — `SWIFT_STRICT_CONCURRENCY: complete` in project.yml. All models are `Sendable`. `SkillManager` and `AppViewModel` are `@MainActor`.
- **Swift Testing framework** — Tests use `import Testing` with `@Suite`, `@Test`, `#expect`, `#require` (not XCTest). Use `@testable import CCSkillManager`.
- **No external dependencies** — YAML parsing is hand-written. Git operations shell out via `Process`. No SPM packages, CocoaPods, or frameworks beyond Foundation and SwiftUI.
- **macOS 14+ (Sonoma)** — Uses `@Observable` (Observation framework), `NavigationSplitView`, and other macOS 14+ APIs.
- **Module name** — `PRODUCT_MODULE_NAME: CCSkillManager` (explicit because the product name "CC Skill Manager" has spaces).

## File System Paths

The app manages skills across these directories:

| Path | Purpose |
|------|---------|
| `~/.claude/skills/` | Active (enabled) skills |
| `~/.claude/skills-disabled/` | Disabled skills |
| `~/Library/Application Support/CC-Skill-Manager/repos/` | Cloned Git repos for URL-installed skills |
| `~/Library/Application Support/CC-Skill-Manager/metadata.json` | Install metadata (source URLs, timestamps) |

## Requirements

Full requirements document at `docs/reqdocs/requirements.md` covering FR-1 through FR-9 (functional) and NFR-1 through NFR-4 (non-functional). Build progress and deferred SHOULD-FIX items tracked in `docs/progress/build-progress.md`.
