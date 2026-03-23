# Drag & Drop Import — Business Requirements

## Overview

Allow users to import skills by dragging folders from Finder directly onto the Agent Skill Manager window, providing a faster alternative to the existing "Add Skill" sheet workflow. The import behavior is identical to the current folder import — this feature adds a new entry point, not new import logic.

## Users and Personas

The sole user is the same as the broader app: a developer managing their Claude Code agent skills. They expect standard macOS drag-and-drop behavior — dragging a folder onto an app window to import it is a well-established convention.

## User Stories

### US-DD-1: Single folder drop
**As a** user, **I want to** drag a skill folder from Finder onto the app window **so that** I can import it without opening the Add Skill sheet.

**Acceptance criteria:**
- Dragging a folder containing `SKILL.md` from Finder onto the app window imports the skill into `~/.claude/skills/`.
- The import behavior (copy, duplicate detection, confirmation dialog) is identical to the existing "Import from Folder" flow.
- The skill list refreshes and the newly imported skill appears in the sidebar.

### US-DD-2: Multiple folder drop
**As a** user, **I want to** drag multiple folders at once **so that** I can batch-import skills efficiently.

**Acceptance criteria:**
- Dragging multiple folders onto the app window imports all valid skills.
- Duplicate detection runs against all dropped folders collectively (same as existing multi-import behavior).
- If some folders are valid and others are not, valid ones are imported and errors are reported for the invalid ones.

### US-DD-3: Visual drop feedback
**As a** user, **I want to** see clear visual feedback when dragging over the app **so that** I know the app will accept my drop.

**Acceptance criteria:**
- When dragging a compatible item over the app window, a semi-transparent overlay appears covering the content area, with a visible border and an import icon (e.g., a "+" badge or a down-arrow).
- The overlay disappears when the drag exits the window or the drop completes.

### US-DD-4: Invalid folder handling
**As a** user, **I want to** see an error message when I drop a folder without a SKILL.md **so that** I understand why the import failed.

**Acceptance criteria:**
- If a dropped folder does not contain a `SKILL.md` file, the existing error alert is shown: "The selected directory does not contain a SKILL.md file."
- If multiple folders are dropped and some are invalid, errors are collected and displayed together (consistent with existing multi-import error handling).

## Functional Requirements

### FR-DD-1: Drop target
The entire app window acts as a drop target for folder imports. The drop zone is registered at the `ContentView` level so it covers the sidebar, detail panel, and any empty states.

### FR-DD-2: Accepted drop types
The app accepts only file/folder URLs from the Finder (UTType `.fileURL` / `NSPasteboard` file URLs). Other drop types (text, URLs from browsers, images) are ignored — the cursor should show the standard "not allowed" indicator for unsupported types.

### FR-DD-3: Import flow
Dropped folders are processed through the existing `AppViewModel.addSkillsFromFiles(urls:)` method, which handles:
- Validation (`SKILL.md` existence check)
- Duplicate name detection with confirmation dialog
- Copy to `~/.claude/skills/`
- Skill list reload

### FR-DD-4: Visual overlay
When a valid drag enters the window:
- A semi-transparent overlay (e.g., system accent color at ~15% opacity) covers the content area.
- A border (e.g., dashed or solid, 2pt, accent color) frames the drop zone.
- An icon and/or label (e.g., "Drop to import") indicates the action.

When the drag leaves the window or the drop completes, the overlay is removed.

### FR-DD-5: Interaction with existing UI state
- If the Add Skill sheet is already open, the drop should still work (the sheet should dismiss or the drop should be queued — but it should not be silently ignored).
- If the editor has unsaved changes, the existing unsaved-changes flow applies (the import happens independently of editor state — it does not navigate away from the current skill).

## Non-Functional Requirements

### NFR-DD-1: Platform
macOS 14+ (Sonoma). Uses SwiftUI's `.onDrop` or `dropDestination` modifier.

### NFR-DD-2: Performance
Drag hover feedback must appear within one frame (~16ms). The import itself may take longer for large skill directories, consistent with existing behavior.

## Out of Scope
- Dragging URLs from a browser to clone git repos (only Finder folders are accepted).
- Dragging `.zip` files to extract and import.
- Drag-to-reorder skills within the sidebar.
- Dragging skills out of the app to export.
