# Drag & Drop Import + Markdown Preview — Build Progress

## Status: COMPLETE

## Architecture Reference
- DD Architecture: `docs/features/drag-drop-import/architecture/design.md`
- DD Requirements: `docs/features/drag-drop-import/requirements/requirements.md`
- MP Architecture: `docs/features/markdown-preview/architecture/design.md`
- MP Requirements: `docs/features/markdown-preview/requirements/requirements.md`

## Phase Tracker

| Task | Phase | Step | Teammate | Status | Notes |
|------|-------|------|----------|--------|-------|
| 1 | DD+MP1 | Write Tests | test-author | ✅ | 6 DD + 13 MP1 tests |
| 2 | DD+MP1 | Review Tests | reviewer | ✅ | 0 MUST-FIX, 6 SHOULD-FIX |
| 3 | DD | Implement | dd-dev | ✅ | DropOverlayView, ContentView, AppViewModel |
| 4 | MP1 | Implement | mp-dev | ✅ | MarkdownRenderer, project.yml, highlight.min.js |
| 5 | DD+MP1 | Review Impl | reviewer | ✅ | 0 MUST-FIX, 7 SHOULD-FIX |
| 6 | MP2 | Implement | mp-dev | ✅ | MarkdownWebView |
| 7 | MP2 | Review Impl | reviewer | ✅ | 2 MUST-FIX (fixed), 2 SHOULD-FIX (fixed) |
| 8 | MP3+4 | Write Tests | test-author | ✅ | 7 tests + 1 added during impl |
| 9 | MP3+4 | Review Tests | reviewer | ✅ | 1 MUST-FIX (fixed in Task 10) |
| 10 | MP3+4 | Implement | mp-dev | ✅ | EditorView toggle, DetailPanelView tabs, AppViewModel |
| 11 | MP3+4 | Review Impl | reviewer | ✅ | 0 MUST-FIX, 2 SHOULD-FIX |
| 12 | Final | Regression | lead | ✅ | 148 tests, 9 suites, all passing |

## Final Test Results
- **148 tests** across **9 suites** — ALL PASSED
- Test run: 1.659 seconds
- No regressions from original 109 tests
- 39 new tests added (6 DD + 13 MP1 + 8 MP3+MP4 + 12 existing tests already counted)

## Files Created/Modified

### Drag & Drop Import
| File | Action | Purpose |
|------|--------|---------|
| `Sources/Views/DropOverlayView.swift` | NEW | Visual overlay during drag hover |
| `Sources/Views/ContentView.swift` | MODIFIED | .dropDestination + overlay |
| `Sources/ViewModels/AppViewModel.swift` | MODIFIED | isDropTargeted, handleDroppedURLs |

### Markdown Preview
| File | Action | Purpose |
|------|--------|---------|
| `Sources/Services/MarkdownRenderer.swift` | NEW | Markdown → HTML via cmark-gfm |
| `Sources/Resources/highlight.min.js` | NEW | Bundled syntax highlighting |
| `Sources/Views/MarkdownWebView.swift` | NEW | WKWebView wrapper |
| `Sources/Views/EditorView.swift` | MODIFIED | Edit/Preview segmented toggle |
| `Sources/Views/DetailPanelView.swift` | MODIFIED | Info/Content tabs |
| `Sources/ViewModels/AppViewModel.swift` | MODIFIED | EditorMode, DetailTab, persistence |
| `project.yml` | MODIFIED | swift-cmark SPM dep, Resources |

### Tests
| File | Action | Tests Added |
|------|--------|-------------|
| `Tests/AppViewModelTests.swift` | MODIFIED | 6 DD + 8 MP3+MP4 |
| `Tests/MarkdownRendererTests.swift` | NEW | 13 MP1 |

## Open SHOULD-FIX Items (Non-Blocking)
1. DD: Silent return when only non-directory items dropped (could show error message)
2. MP1: project.yml uses branch:gfm instead of semver tag
3. MP1: renderFrontmatterCard partially duplicates YAML parsing (SkillParser.parseYAMLFields is private)
4. MP2: Nested scrolling in DetailPanelView Content tab (outer ScrollView + WKWebView internal scroll)
5. MP3: No test for forceSaveEditing() resetting editorMode
