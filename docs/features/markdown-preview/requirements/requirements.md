# Markdown Preview — Business Requirements

## Overview

Add rendered markdown viewing to two areas of the app: (1) a toggle in the editor to switch between raw editing and rendered preview, and (2) a new "Content" tab in the detail panel that shows the rendered SKILL.md body. This gives users a way to see how their skill content looks without leaving the app.

## Users and Personas

The same developer persona as the broader app. They author SKILL.md files using markdown and want to verify formatting (headings, code blocks, lists, tables) without switching to an external previewer.

## User Stories

### US-MP-1: Editor preview toggle
**As a** user editing a SKILL.md, **I want to** toggle between the raw editor and a rendered preview **so that** I can verify my markdown formatting while writing.

**Acceptance criteria:**
- A segmented control or toggle button (labeled "Edit" / "Preview") appears in the editor toolbar alongside Cancel and Save.
- Clicking "Preview" replaces the text editor with a rendered view of the current content.
- Clicking "Edit" returns to the text editor with the cursor/scroll position preserved.
- The rendered state updates live as the user types, so switching to Preview feels instant with no rendering delay.

### US-MP-2: Detail panel content tab
**As a** user viewing a skill, **I want to** see the rendered SKILL.md content in the detail panel **so that** I can read the skill's documentation in a formatted view.

**Acceptance criteria:**
- The detail panel has two tabs: "Info" and "Content".
- "Info" contains the existing metadata grid (name, description, path, type, source, status), action buttons, and the file tree — no changes to current layout.
- "Content" shows the rendered body of the SKILL.md (everything after the YAML frontmatter closing `---`). The frontmatter is not rendered here since it is already surfaced as structured metadata in the Info tab.
- The Content tab is read-only (not editable).

### US-MP-3: Standard markdown rendering
**As a** user, **I want** headings, text formatting, lists, links, blockquotes, and horizontal rules to render correctly **so that** the preview matches what I expect from standard markdown.

**Acceptance criteria:**
- `#` through `######` render as appropriately sized headings.
- `**bold**`, `*italic*`, `~~strikethrough~~` render with correct formatting.
- Ordered and unordered lists render with proper indentation and nesting.
- `[links](url)` render as clickable links (opening in the default browser).
- `> blockquotes` render with visual distinction (indent and/or background).
- `---` renders as a horizontal rule.

### US-MP-4: Code block rendering with syntax highlighting
**As a** user, **I want** fenced code blocks to render with syntax highlighting **so that** code examples in my skill docs are easy to read.

**Acceptance criteria:**
- Fenced code blocks (` ``` `) render in a monospace font with a distinct background.
- Language-tagged blocks (` ```python `, ` ```bash `, ` ```swift `, etc.) render with syntax coloring.
- Inline code (`` `code` ``) renders in a monospace font with a subtle background.

### US-MP-5: Table rendering
**As a** user, **I want** GitHub-flavored markdown tables to render as formatted tables **so that** tabular data in my skill docs is readable.

**Acceptance criteria:**
- Pipe-delimited tables render as properly aligned rows and columns with borders or visual separation.
- Header rows are visually distinct from body rows.

### US-MP-6: YAML frontmatter rendering
**As a** user viewing the editor preview, **I want** the YAML frontmatter block to be rendered as a styled metadata card **so that** it looks structured rather than raw YAML.

**Acceptance criteria:**
- The `---` delimited frontmatter at the top of the file is rendered as a visually distinct block (e.g., a card or panel with key-value pairs).
- This styled rendering appears in the editor's preview mode (where the full file content is shown).
- In the detail panel's Content tab, frontmatter is omitted (it is already shown in the Info tab).

## Functional Requirements

### FR-MP-1: Editor toggle control
A segmented control with two segments — "Edit" and "Preview" — is placed in the editor's header bar between the Cancel and Save buttons. The active segment is visually indicated. The Save button remains functional in both modes (saves the current editor content regardless of which view is active).

### FR-MP-2: Editor state management
- The raw text content is the source of truth at all times. The preview is a derived view.
- Switching to Preview does not modify the text content.
- Switching back to Edit restores the editor with the same content.
- The rendered preview is kept up to date with the current editor text so the toggle feels instant.

### FR-MP-3: Detail panel tabs
A `TabView` or segmented control at the top of the detail panel provides "Info" and "Content" tabs.
- **Info tab:** Contains all existing detail panel content (metadata grid, action buttons, file tree disclosure group). No layout changes.
- **Content tab:** Contains a scrollable rendered view of the SKILL.md body (post-frontmatter). Read-only. Uses the same rendering engine as the editor preview.
- Tab selection is per-skill (switching skills resets to the default tab, or preserves the last-selected tab — either is acceptable).

### FR-MP-4: Markdown rendering engine
The rendering engine must support:
- **Block elements:** headings (h1-h6), paragraphs, blockquotes, ordered lists, unordered lists (with nesting), fenced code blocks, horizontal rules, tables (GFM).
- **Inline elements:** bold, italic, strikethrough, inline code, links.
- **Code highlighting:** syntax coloring for common languages (at minimum: Python, Bash/Shell, Swift, JavaScript, TypeScript, YAML, JSON, Markdown).
- **YAML frontmatter:** detected and rendered as a styled key-value card when present.

### FR-MP-5: Link handling
Links in the rendered preview open in the user's default browser via `NSWorkspace.shared.open()`. They do not navigate within the app.

### FR-MP-6: Rendering consistency
The same rendering logic is used in both the editor preview and the detail panel Content tab, so formatting looks identical in both contexts.

## Non-Functional Requirements

### NFR-MP-1: Platform
macOS 14+ (Sonoma). SwiftUI-native rendering preferred. The app currently has no external dependencies — if an external markdown library is needed, it should be a Swift package with no transitive dependencies.

### NFR-MP-2: Performance
Live rendering must not introduce noticeable lag while typing. For typical SKILL.md files (under 500 lines), the preview should update within 100ms of each keystroke. Debouncing is acceptable if needed for very large files.

### NFR-MP-3: Visual consistency
The rendered output should respect the system appearance (light/dark mode) and use colors and typography consistent with the rest of the app.

## Constraints and Preferences

- The app currently has zero external dependencies. Adding a Swift package for markdown parsing and/or syntax highlighting is acceptable if it significantly reduces implementation effort, but a no-dependency approach is preferred if feasible within reasonable scope.
- The YAML frontmatter parser already exists in `SkillParser.swift` and can be reused for detecting and extracting frontmatter for the styled card rendering.

## Open Questions

1. **Syntax highlighting library:** Should syntax highlighting use a bundled library (e.g., Splash, Highlightr) or a simpler approach (e.g., regex-based coloring for a limited set of languages)? This is a technical decision for the architect.
2. **Default tab:** When selecting a skill in the sidebar, should the detail panel default to the "Info" tab or the "Content" tab? (Either is acceptable per the interview.)

## Out of Scope
- Editing markdown in the detail panel Content tab (it is read-only).
- Image rendering in markdown (SKILL.md files do not typically contain images).
- Mermaid diagrams or other extended markdown features.
- Exporting the rendered preview as PDF or HTML.
- Syntax highlighting for every possible language — a curated set of common languages is sufficient.
