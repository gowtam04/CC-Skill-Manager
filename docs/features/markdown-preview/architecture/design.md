# Markdown Preview — Technical Design

## Overview

Add rendered markdown viewing via WKWebView in two locations: (1) a toggle in the editor between raw editing and rendered preview, and (2) a "Content" tab in the detail panel. Markdown is converted to HTML by cmark-gfm (C library via SPM), rendered in a WKWebView with highlight.js for syntax coloring and a custom CSS stylesheet for light/dark mode theming.

## Requirements Reference

`docs/features/markdown-preview/requirements/requirements.md`

## Tech Stack

**New dependency:**
- `apple/swift-cmark` (SPM) — wraps the cmark-gfm C library. Provides `cmark_gfm` module for markdown-to-HTML conversion with GFM extensions (tables, strikethrough). Apple-maintained, no transitive dependencies.

**Bundled resources:**
- `highlight.min.js` — custom build of highlight.js (~35KB) with languages: Python, Bash, Swift, JavaScript, TypeScript, YAML, JSON, Markdown.
- CSS stylesheet embedded in the HTML template (no separate CSS file — simplifies resource loading).

**Frameworks:**
- `WebKit` — for `WKWebView` (already available on macOS, no additional linking needed beyond `import WebKit`).

## Data Model

No changes to the `Skill` model. The rendered HTML is a derived view computed on-demand from `skill.rawContent` (for the detail panel) and `viewModel.editorContent` (for the editor preview).

## Component Design

### MarkdownRenderer (new service)

A stateless service (enum with static methods) consistent with the `SkillParser` pattern. Converts markdown to a complete HTML document ready for WKWebView.

**Responsibility:** Markdown → HTML conversion, frontmatter detection and styled rendering, HTML template assembly with CSS and highlight.js.

**Interface:**
```swift
enum MarkdownRenderer {

    /// Converts markdown to a complete HTML document with embedded CSS and highlight.js.
    ///
    /// - Parameters:
    ///   - markdown: Raw markdown string (may include YAML frontmatter)
    ///   - includeFrontmatter: If true, renders frontmatter as a styled key-value card
    ///     above the body. If false, strips frontmatter and renders only the body.
    /// - Returns: Complete HTML document string (<!DOCTYPE html>...) ready for WKWebView.
    static func renderHTML(markdown: String, includeFrontmatter: Bool) -> String

    /// Converts markdown to an HTML fragment (no <html>/<head>/<body> wrapper).
    /// Used for incremental content updates via JavaScript injection.
    ///
    /// - Parameters:
    ///   - markdown: Raw markdown string
    ///   - includeFrontmatter: Whether to include frontmatter card
    /// - Returns: HTML fragment string for innerHTML injection.
    static func renderHTMLFragment(markdown: String, includeFrontmatter: Bool) -> String
}
```

**Internal implementation details:**

1. **Frontmatter extraction:** Uses `SkillParser.parse(content:)` to detect and extract frontmatter fields. If parsing fails (no frontmatter), treats the entire input as markdown body. This reuses the existing parser rather than duplicating YAML detection logic.

2. **Markdown → HTML:** Calls cmark-gfm C API:
   ```swift
   // Pseudocode — exact API depends on swift-cmark version
   cmark_gfm_core_extensions_ensure_registered()
   let parser = cmark_parser_new(CMARK_OPT_DEFAULT)
   // Attach table + strikethrough extensions
   let tableExt = cmark_find_syntax_extension("table")
   cmark_parser_attach_syntax_extension(parser, tableExt)
   let strikethroughExt = cmark_find_syntax_extension("strikethrough")
   cmark_parser_attach_syntax_extension(parser, strikethroughExt)
   cmark_parser_feed(parser, markdown, markdown.utf8.count)
   let doc = cmark_parser_finish(parser)
   let html = String(cString: cmark_render_html(doc, CMARK_OPT_DEFAULT, nil))
   ```

3. **Frontmatter card HTML:** When `includeFrontmatter: true`, generates a `<div class="frontmatter-card">` with key-value pairs in a definition list (`<dl><dt>name</dt><dd>value</dd>...</dl>`).

4. **HTML template:** `renderHTML` wraps the fragment in a full HTML document:
   ```html
   <!DOCTYPE html>
   <html>
   <head>
     <meta charset="utf-8">
     <meta name="color-scheme" content="light dark">
     <style>/* embedded CSS — see CSS Design section */</style>
     <script>/* embedded highlight.min.js */</script>
   </head>
   <body>
     <div id="content">
       <!-- frontmatter card (optional) -->
       <!-- rendered markdown body -->
     </div>
     <script>hljs.highlightAll();</script>
   </body>
   </html>
   ```

   CSS and JS are embedded directly in the HTML string (not loaded from external files) to avoid WKWebView base URL / resource loading issues. The highlight.js source is read from the bundle once and cached in a static property.

### MarkdownWebView (new view)

An `NSViewRepresentable` wrapping `WKWebView`. Used by both the editor preview and the detail panel Content tab.

**Responsibility:** Display rendered HTML, handle link clicks (open in browser), support content updates without page reload flickering.

**Interface:**
```swift
struct MarkdownWebView: NSViewRepresentable {
    /// Complete HTML document string (from MarkdownRenderer.renderHTML)
    let html: String

    func makeNSView(context: Context) -> WKWebView
    func updateNSView(_ webView: WKWebView, context: Context)
    func makeCoordinator() -> Coordinator

    class Coordinator: NSObject, WKNavigationDelegate {
        /// Intercepts link clicks and opens them in the default browser
        /// via NSWorkspace.shared.open(). Allows "about:blank" and
        /// initial loads; blocks all other navigation.
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void)
    }
}
```

**Update strategy for avoiding flicker:**

Calling `loadHTMLString` on every content change causes visible flashing. Instead:

1. **Initial load:** `makeNSView` creates the WKWebView and loads the full HTML document via `loadHTMLString`. This sets up the CSS, JS, and DOM structure.
2. **Subsequent updates:** `updateNSView` detects content changes (by comparing the new HTML against a stored hash in the Coordinator). When content changes, it calls `evaluateJavaScript` to update only the content div:
   ```javascript
   document.getElementById('content').innerHTML = '<escaped HTML fragment>';
   hljs.highlightAll();
   ```
3. **Full reload trigger:** If the HTML template itself changes (which shouldn't happen at runtime), falls back to `loadHTMLString`.

The Coordinator stores the last-loaded HTML hash to avoid redundant updates.

**WKWebView configuration:**
- Background color: `.clear` (transparent, to blend with the SwiftUI background)
- `isInspectable`: `false` in production
- Scrolling: Handled by the WKWebView's internal scroll view (not wrapped in a SwiftUI ScrollView)
- Text selection: Enabled (users should be able to copy text from the preview)

### EditorView changes

**New state in the toolbar:**
```swift
// In the HStack toolbar, between the title and Cancel/Save buttons:
Picker("Mode", selection: $viewModel.editorMode) {
    Text("Edit").tag(EditorMode.edit)
    Text("Preview").tag(EditorMode.preview)
}
.pickerStyle(.segmented)
.frame(width: 140)
```

**Content area swap:**
```swift
// Replace the current TextEditor with:
if viewModel.editorMode == .edit {
    TextEditor(text: $viewModel.editorContent)
        .font(.system(.body, design: .monospaced))
        .scrollContentBackground(.visible)
        .padding(4)
} else {
    MarkdownWebView(
        html: MarkdownRenderer.renderHTML(
            markdown: viewModel.editorContent,
            includeFrontmatter: true  // Editor shows full file including frontmatter
        )
    )
}
```

The `Save` button works in both modes — it always saves `editorContent` regardless of which mode is visible.

### DetailPanelView changes

**Tab control at the top of the detail view:**
```swift
// After the name/copy/export HStack, before the Divider:
Picker("Tab", selection: $viewModel.detailPanelTab) {
    Text("Info").tag(DetailTab.info)
    Text("Content").tag(DetailTab.content)
}
.pickerStyle(.segmented)
.frame(width: 160)
```

**Content switching:**
```swift
if viewModel.detailPanelTab == .info {
    // Existing metadata grid, file tree, action buttons — unchanged
} else {
    MarkdownWebView(
        html: MarkdownRenderer.renderHTML(
            markdown: skill.rawContent,
            includeFrontmatter: false  // Frontmatter is in the Info tab
        )
    )
}
```

The skill name header, copy button, and export button remain visible above the tab picker in both tabs (they are not part of either tab's content).

### AppViewModel changes

**New types:**
```swift
enum EditorMode: Sendable {
    case edit, preview
}

enum DetailTab: String, Sendable {
    case info, content
}
```

**New state:**
```swift
var editorMode: EditorMode = .edit
var detailPanelTab: DetailTab  // Initialized from UserDefaults in init()
```

**Tab persistence:**
```swift
// In init():
let savedTab = UserDefaults.standard.string(forKey: "detailPanelTab")
detailPanelTab = DetailTab(rawValue: savedTab ?? "") ?? .info

// Observed via didSet or a property observer pattern:
// When detailPanelTab changes, persist to UserDefaults.
// Since @Observable doesn't support didSet, use withObservationTracking
// or simply persist in the view's .onChange modifier.
```

**Modified methods:**
- `startEditing()`: Reset `editorMode = .edit` (always start in edit mode).
- `cancelEditing()`: Reset `editorMode = .edit`.

## CSS Design

The embedded CSS provides GitHub-style markdown rendering with system-native feel:

```css
:root {
    color-scheme: light dark;
}
body {
    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
    font-size: 14px;
    line-height: 1.6;
    color: light-dark(#1d1d1f, #f5f5f7);
    background: transparent;
    padding: 16px;
    max-width: 100%;
}
/* Headings */
h1 { font-size: 1.8em; font-weight: 700; border-bottom: 1px solid light-dark(#d1d1d6, #3a3a3c); padding-bottom: 8px; }
h2 { font-size: 1.4em; font-weight: 600; border-bottom: 1px solid light-dark(#d1d1d6, #3a3a3c); padding-bottom: 6px; }
h3 { font-size: 1.2em; font-weight: 600; }
/* Code blocks */
pre {
    background: light-dark(#f5f5f7, #1c1c1e);
    border: 1px solid light-dark(#d1d1d6, #3a3a3c);
    border-radius: 8px;
    padding: 12px;
    overflow-x: auto;
}
code { font-family: "SF Mono", Menlo, monospace; font-size: 0.9em; }
p code, li code {
    background: light-dark(#f5f5f7, #1c1c1e);
    padding: 2px 6px;
    border-radius: 4px;
}
/* Tables (GFM) */
table { border-collapse: collapse; width: 100%; margin: 16px 0; }
th, td { border: 1px solid light-dark(#d1d1d6, #3a3a3c); padding: 8px 12px; text-align: left; }
th { background: light-dark(#f5f5f7, #2c2c2e); font-weight: 600; }
/* Blockquotes */
blockquote {
    border-left: 4px solid light-dark(#007aff, #0a84ff);
    padding-left: 16px;
    margin-left: 0;
    color: light-dark(#6e6e73, #98989d);
}
/* Lists */
ul, ol { padding-left: 24px; }
li { margin: 4px 0; }
/* Links */
a { color: light-dark(#007aff, #0a84ff); text-decoration: none; }
a:hover { text-decoration: underline; }
/* Horizontal rules */
hr { border: none; border-top: 1px solid light-dark(#d1d1d6, #3a3a3c); margin: 24px 0; }
/* Frontmatter card */
.frontmatter-card {
    background: light-dark(#f5f5f7, #1c1c1e);
    border: 1px solid light-dark(#d1d1d6, #3a3a3c);
    border-radius: 8px;
    padding: 12px 16px;
    margin-bottom: 20px;
}
.frontmatter-card dt { font-weight: 600; color: light-dark(#6e6e73, #98989d); font-size: 0.85em; text-transform: uppercase; letter-spacing: 0.5px; }
.frontmatter-card dd { margin: 0 0 8px 0; }
```

Highlight.js theme: Use the `github` / `github-dark` theme pair, or a single adaptive theme. The highlight.js CSS is embedded alongside the main stylesheet and uses the same `light-dark()` approach for adaptive colors.

## File Structure

```
Sources/
├── Services/
│   └── MarkdownRenderer.swift               (NEW — markdown → HTML conversion)
├── Views/
│   ├── ContentView.swift                     (UNCHANGED by this feature)
│   ├── DetailPanelView.swift                 (MODIFIED — add tab picker + Content tab)
│   ├── EditorView.swift                      (MODIFIED — add segmented control + preview)
│   └── MarkdownWebView.swift                 (NEW — NSViewRepresentable for WKWebView)
├── ViewModels/
│   └── AppViewModel.swift                    (MODIFIED — add EditorMode, DetailTab, persistence)
├── Resources/
│   └── highlight.min.js                      (NEW — bundled highlight.js custom build)
project.yml                                   (MODIFIED — add swift-cmark SPM dep, Resources dir)

Tests/
├── MarkdownRendererTests.swift               (NEW)
├── AppViewModelTests.swift                   (MODIFIED — add editor mode + tab tests)
```

### project.yml changes

```yaml
# Add at top level:
packages:
  swift-cmark:
    url: https://github.com/apple/swift-cmark
    from: "0.6.0"

# In the AgentSkillManager target, add:
    dependencies:
      - package: swift-cmark
        product: cmark-gfm
    resources:
      - path: Sources/Resources
        buildPhase: resources
```

## Interface Definitions

### MarkdownRenderer (high detail — non-obvious cmark-gfm usage)

```swift
import Foundation

enum MarkdownRenderer {

    /// Full HTML document with embedded CSS and highlight.js.
    /// Call this for the initial WKWebView load.
    static func renderHTML(markdown: String, includeFrontmatter: Bool) -> String

    /// HTML fragment (no <html>/<head> wrapper) for JavaScript innerHTML injection.
    /// Call this for incremental updates to avoid page reload flicker.
    static func renderHTMLFragment(markdown: String, includeFrontmatter: Bool) -> String

    // MARK: - Internal

    /// Cached highlight.js source, loaded from bundle once on first access.
    private static var highlightJSSource: String { get }

    /// Converts markdown body (no frontmatter) to HTML using cmark-gfm.
    /// Registers table + strikethrough extensions.
    private static func markdownToHTML(_ markdown: String) -> String

    /// Generates a frontmatter card HTML fragment from parsed YAML fields.
    /// Returns empty string if parsing fails (no frontmatter present).
    private static func renderFrontmatterCard(from content: String) -> String

    /// Extracts the body portion of markdown (everything after the closing --- delimiter).
    /// If no frontmatter is detected, returns the full input unchanged.
    private static func extractBody(from content: String) -> String

    /// The complete CSS stylesheet string (main + highlight.js theme).
    private static var cssStylesheet: String { get }

    /// Escapes a string for safe embedding in JavaScript string literals.
    /// Escapes: backslash, single quotes, double quotes, newlines, carriage returns.
    static func escapeForJavaScript(_ string: String) -> String
}
```

### MarkdownWebView (high detail — WKWebView lifecycle is tricky)

```swift
import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> WKWebView
    // Creates WKWebView with:
    //   - Transparent background
    //   - Navigation delegate set to Coordinator
    //   - Loads initial HTML via loadHTMLString
    //   - Stores initial html hash in coordinator

    func updateNSView(_ webView: WKWebView, context: Context)
    // Compares html.hashValue against coordinator.lastHTMLHash.
    // If different:
    //   - Extracts the <div id="content">...</div> innerHTML from the new HTML
    //   - Calls webView.evaluateJavaScript to replace content + re-run hljs
    //   - Updates coordinator.lastHTMLHash
    // If same: no-op

    func makeCoordinator() -> Coordinator

    class Coordinator: NSObject, WKNavigationDelegate {
        var lastHTMLHash: Int = 0

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void)
        // Allow: .other (initial load), navigationType == .other
        // Block + open externally: .linkActivated → NSWorkspace.shared.open(url)
        // Block: everything else
    }
}
```

### AppViewModel additions (light detail — standard state management)

```swift
// New types
enum EditorMode: Sendable { case edit, preview }
enum DetailTab: String, Sendable { case info, content }

// New properties
var editorMode: EditorMode = .edit
var detailPanelTab: DetailTab  // Persisted via UserDefaults key "detailPanelTab"
var isDropTargeted: Bool = false  // (from drag-drop feature)

// New methods
func handleDroppedURLs(_ urls: [URL]) async  // (from drag-drop feature)

// Modified methods
// startEditing(): add editorMode = .edit
// cancelEditing(): add editorMode = .edit
```

**Tab persistence:** The detail panel's `.onChange(of: viewModel.detailPanelTab)` modifier in DetailPanelView writes the raw value to `UserDefaults.standard`. The initial value is read from UserDefaults in `AppViewModel.init()`.

## Implementation Phases

### Phase 1: MarkdownRenderer service + tests

**What gets built:**
- `Sources/Services/MarkdownRenderer.swift` — all static methods
- `Sources/Resources/highlight.min.js` — downloaded custom build from highlightjs.org with: Python, Bash, Swift, JavaScript, TypeScript, YAML, JSON, Markdown
- `project.yml` — add `swift-cmark` SPM package dependency, add `Resources` directory to sources
- `Tests/MarkdownRendererTests.swift`

**Depends on:** Nothing.

**Produces:** A tested service that converts markdown strings to HTML. No UI yet.

**Parallel opportunities:** Downloading/generating highlight.js custom build and writing the renderer code are independent.

**Test focus:**
- Basic markdown → HTML (headings, bold, italic, lists, links)
- GFM tables render as `<table>` elements
- Strikethrough renders as `<del>` elements
- Fenced code blocks render with `<pre><code class="language-X">` for highlight.js
- Frontmatter card: valid frontmatter renders as `.frontmatter-card` div with key-value pairs
- Frontmatter card: no frontmatter → no card, body renders normally
- `includeFrontmatter: false` strips frontmatter, renders body only
- `includeFrontmatter: true` renders card + body
- `escapeForJavaScript` handles quotes, newlines, backslashes
- Full HTML document includes CSS and highlight.js script tag

### Phase 2: MarkdownWebView component

**What gets built:**
- `Sources/Views/MarkdownWebView.swift` — NSViewRepresentable + Coordinator

**Depends on:** Phase 1 (needs MarkdownRenderer to generate test HTML).

**Produces:** A reusable SwiftUI view that displays rendered HTML. Not yet wired into any existing views.

**Test focus:**
- Visual verification: render a sample markdown document, confirm headings/tables/code blocks display correctly
- Link click: verify links open in default browser (not in WebView)
- Dark mode: verify CSS adapts when system appearance changes
- Content update: verify updating the `html` property changes the displayed content without page flash

### Phase 3: Editor preview toggle

**What gets built:**
- `Sources/ViewModels/AppViewModel.swift` — add `EditorMode` enum, `editorMode` property, reset in `startEditing()`/`cancelEditing()`
- `Sources/Views/EditorView.swift` — add segmented control picker, conditional content (TextEditor vs MarkdownWebView)
- `Tests/AppViewModelTests.swift` — add editor mode tests

**Depends on:** Phase 2 (MarkdownWebView must exist).

**Produces:** Working editor with Edit/Preview toggle.

**Parallel opportunities:** ViewModel changes and view changes are tightly coupled — build sequentially.

**Test focus:**
- `editorMode` starts as `.edit` when `startEditing()` is called
- `editorMode` resets to `.edit` when `cancelEditing()` is called
- `editorMode` resets to `.edit` when `saveEditing()` completes
- Save works in both modes (saves `editorContent` regardless of mode)
- Visual: toggle between edit and preview, confirm content matches
- Visual: type in editor, switch to preview, confirm changes are reflected

### Phase 4: Detail panel tabs

**What gets built:**
- `Sources/ViewModels/AppViewModel.swift` — add `DetailTab` enum, `detailPanelTab` property, UserDefaults persistence
- `Sources/Views/DetailPanelView.swift` — add segmented picker, tab content switching
- `Tests/AppViewModelTests.swift` — add tab persistence tests

**Depends on:** Phase 2 (MarkdownWebView must exist).

**Produces:** Complete detail panel with Info and Content tabs. Feature complete.

**Parallel opportunities:** Can be built in parallel with Phase 3 since both depend on Phase 2 but not on each other. The ViewModel changes overlap (both modify AppViewModel.swift) but affect different properties with no interaction — coordinate at merge time.

**Test focus:**
- `detailPanelTab` defaults to persisted value from UserDefaults (or `.info` if none)
- Changing `detailPanelTab` persists to UserDefaults
- Info tab shows existing metadata grid and file tree (unchanged)
- Content tab shows rendered markdown body (no frontmatter)
- Content tab for skill with no frontmatter shows full rendered content
- Switching skills preserves the tab selection

## Technical Decisions

| Decision | Choice | Alternatives Considered | Rationale |
|----------|--------|------------------------|-----------|
| Rendering engine | WKWebView + cmark-gfm + highlight.js | (a) swift-markdown + SwiftUI views, (b) NSAttributedString hand-rolled | WKWebView provides the best rendering quality with the least code. GFM tables and syntax highlighting come essentially for free. |
| MD → HTML | cmark-gfm via `apple/swift-cmark` SPM | marked.js bundled in WebView | Native C performance (~1ms), Apple-maintained, HTML output feeds directly to WebView. Avoids JS string escaping for markdown input. |
| Syntax highlighting | highlight.js custom build (bundled) | Regex-based Swift coloring, Splash/Highlightr SPM packages | highlight.js supports 40+ languages out of the box. Custom build keeps size to ~35KB. No additional SPM dependency. |
| CSS embedding | Inline in HTML string | Separate .css file loaded via WKWebView baseURL | Avoids WKWebView resource loading path issues. Single string output from MarkdownRenderer simplifies the interface. |
| Content update strategy | JavaScript innerHTML injection | loadHTMLString on every change | Avoids page reload flicker. highlight.js re-run after injection is fast. |
| Tab persistence | UserDefaults | @AppStorage, file-based | UserDefaults is the standard approach for simple UI preferences. @AppStorage is just a wrapper; using UserDefaults directly works in the ViewModel (which isn't a View). |
| Default tab | Last used (persisted), falling back to Info | Always Info, always Content | User preference — remembering the last tab reduces friction for users who prefer one view. |

## Resolved Open Questions

1. **Syntax highlighting library:** Resolved — use highlight.js (bundled JS, custom build with 8 core languages). No additional SPM dependency needed beyond swift-cmark.
2. **Default tab:** Resolved — remember last used tab via UserDefaults, default to Info on first launch.
