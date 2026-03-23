# Drag & Drop Import — Technical Design

## Overview

Add a whole-window drop target that accepts folders dragged from Finder and imports them through the existing `addSkillsFromFiles(urls:)` pipeline. This feature adds a new entry point to existing import logic — no new business logic is needed.

## Requirements Reference

`docs/features/drag-drop-import/requirements/requirements.md`

## Tech Stack

No new dependencies. Uses SwiftUI's `.dropDestination(for:action:isTargeted:)` modifier (macOS 14+).

## Component Design

### DropOverlayView (new)

A full-window overlay that appears during drag hover. Purely presentational — no logic.

**Responsibility:** Render a semi-transparent overlay with a border, icon, and "Drop to import" label.

**Interface:**
```swift
struct DropOverlayView: View {
    // No inputs — this is a static visual indicator
    var body: some View  // ZStack with:
                         //   - Color.accentColor.opacity(0.12) background
                         //   - RoundedRectangle stroke (2pt, accent color, dashed)
                         //   - VStack: SF Symbol "plus.circle" (44pt) + "Drop to import" label
}
```

### ContentView changes

The drop destination is registered at the `NavigationSplitView` level so it covers the entire window. The `isTargeted` callback drives overlay visibility.

**New modifier chain on NavigationSplitView:**
```swift
.overlay {
    if viewModel.isDropTargeted {
        DropOverlayView()
    }
}
.dropDestination(for: URL.self) { urls, _ in
    Task { await viewModel.handleDroppedURLs(urls) }
    return true
} isTargeted: { targeted in
    viewModel.isDropTargeted = targeted
}
```

### AppViewModel changes

**New state:**
```swift
var isDropTargeted: Bool = false
```

**New method:**
```swift
func handleDroppedURLs(_ urls: [URL]) async {
    // 1. Filter to only directory URLs (skip files)
    // 2. If no directories remain, set errorMessage and return
    // 3. Call addSkillsFromFiles(urls: directoryURLs)
    //    (this already handles SKILL.md validation, duplicate detection, etc.)
}
```

The method filters dropped URLs to directories only (users might accidentally include files in a multi-select drag), then delegates to `addSkillsFromFiles(urls:)` which already handles the full import pipeline including duplicate detection with the confirmation dialog.

**FR-DD-5 (interaction with existing UI state):** If the Add Skill sheet is open when a drop occurs, `isShowingAddSheet` is set to `false` to dismiss it before processing the drop. The editor's unsaved-changes flow is not affected because drops don't change the selected skill.

## File Structure

```
Sources/
├── Views/
│   ├── ContentView.swift          (MODIFIED — add .dropDestination + overlay)
│   └── DropOverlayView.swift      (NEW — visual overlay during drag hover)
├── ViewModels/
│   └── AppViewModel.swift         (MODIFIED — add isDropTargeted, handleDroppedURLs)
```

## Implementation Phases

### Phase 1: Drop handling + overlay (single phase — this feature is small enough)

**What gets built:**
- `DropOverlayView.swift` — new view file
- `AppViewModel.swift` — add `isDropTargeted` property and `handleDroppedURLs(_:)` method
- `ContentView.swift` — add `.dropDestination` modifier and overlay

**Depends on:** Nothing (existing `addSkillsFromFiles` is already implemented and tested).

**Produces:** Complete drag-and-drop import feature.

**Parallel opportunities:** The overlay view and the viewmodel changes are independent and can be written simultaneously.

**Test focus:**
- `AppViewModelTests`: Test `handleDroppedURLs` with directory URLs (should call through to import), with file URLs (should be filtered out), with mixed URLs (directories imported, files ignored), with empty array (no-op). Test that `isDropTargeted` state toggles correctly.
- Visual verification: drag a folder onto the window, confirm overlay appears, confirm import completes.

## Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| SwiftUI API | `.dropDestination(for: URL.self)` | Modern macOS 14+ API with built-in `isTargeted` callback. Cleaner than `.onDrop(of:)`. |
| Drop target scope | Entire NavigationSplitView | Maximizes drop target area per FR-DD-1. Applied as a modifier on the outermost view. |
| URL filtering | Filter to directories in `handleDroppedURLs` | Finder multi-select drags may include non-directory items. Filtering at the viewmodel level keeps ContentView simple. |
| Import delegation | Reuse `addSkillsFromFiles(urls:)` | No new import logic needed. Duplicate detection, SKILL.md validation, and error handling are already implemented. |
