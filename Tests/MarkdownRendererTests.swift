import Testing
import Foundation
@testable import AgentSkillManager

@Suite("MarkdownRenderer Tests")
struct MarkdownRendererTests {

    // MARK: - Basic Markdown to HTML

    @Test("Headings render as h1, h2, h3 etc.")
    func headingsRender() {
        let markdown = """
        # Heading 1
        ## Heading 2
        ### Heading 3
        """
        let html = MarkdownRenderer.renderHTMLFragment(markdown: markdown, includeFrontmatter: false)

        #expect(html.contains("<h1"))
        #expect(html.contains("Heading 1"))
        #expect(html.contains("<h2"))
        #expect(html.contains("Heading 2"))
        #expect(html.contains("<h3"))
        #expect(html.contains("Heading 3"))
    }

    @Test("Bold and italic render as strong and em")
    func boldAndItalicRender() {
        let markdown = "This is **bold** and *italic* text."
        let html = MarkdownRenderer.renderHTMLFragment(markdown: markdown, includeFrontmatter: false)

        #expect(html.contains("<strong>bold</strong>"))
        #expect(html.contains("<em>italic</em>"))
    }

    @Test("Lists render as ul, ol, li elements")
    func listsRender() {
        let markdown = """
        - Item one
        - Item two

        1. First
        2. Second
        """
        let html = MarkdownRenderer.renderHTMLFragment(markdown: markdown, includeFrontmatter: false)

        #expect(html.contains("<ul>"))
        #expect(html.contains("<li>"))
        #expect(html.contains("Item one"))
        #expect(html.contains("<ol>"))
        #expect(html.contains("First"))
    }

    @Test("Links render as anchor tags with href")
    func linksRender() {
        let markdown = "Visit [Example](https://example.com) for more."
        let html = MarkdownRenderer.renderHTMLFragment(markdown: markdown, includeFrontmatter: false)

        #expect(html.contains("<a"))
        #expect(html.contains("href=\"https://example.com\""))
        #expect(html.contains("Example"))
    }

    // MARK: - GFM Extensions

    @Test("GFM tables render as table elements with th and td")
    func tablesRender() {
        let markdown = """
        | Name | Value |
        |------|-------|
        | foo  | bar   |
        | baz  | qux   |
        """
        let html = MarkdownRenderer.renderHTMLFragment(markdown: markdown, includeFrontmatter: false)

        #expect(html.contains("<table"))
        #expect(html.contains("<th"))
        #expect(html.contains("<td"))
        #expect(html.contains("foo"))
        #expect(html.contains("bar"))
    }

    @Test("Strikethrough renders as del element")
    func strikethroughRenders() {
        let markdown = "This is ~~deleted~~ text."
        let html = MarkdownRenderer.renderHTMLFragment(markdown: markdown, includeFrontmatter: false)

        #expect(html.contains("<del>"))
        #expect(html.contains("deleted"))
    }

    // MARK: - Code Blocks

    @Test("Fenced code blocks render with pre and code with language class")
    func fencedCodeBlocksRender() {
        let markdown = """
        ```python
        def hello():
            print("world")
        ```
        """
        let html = MarkdownRenderer.renderHTMLFragment(markdown: markdown, includeFrontmatter: false)

        #expect(html.contains("<pre"))
        #expect(html.contains("<code"))
        #expect(html.contains("language-python"))
        #expect(html.contains("def hello()"))
    }

    // MARK: - Frontmatter Handling

    @Test("includeFrontmatter true with valid frontmatter renders frontmatter-card div")
    func includeFrontmatterTrue() {
        let markdown = """
        ---
        name: test-skill
        description: A test skill
        ---
        # Body Content
        Some instructions here.
        """
        let html = MarkdownRenderer.renderHTMLFragment(markdown: markdown, includeFrontmatter: true)

        #expect(html.contains("frontmatter-card"))
        #expect(html.contains("test-skill"))
        #expect(html.contains("Body Content"))
    }

    @Test("includeFrontmatter false with frontmatter strips frontmatter, renders only body")
    func includeFrontmatterFalse() {
        let markdown = """
        ---
        name: hidden-meta
        description: Should not appear
        ---
        # Visible Body
        Only this should render.
        """
        let html = MarkdownRenderer.renderHTMLFragment(markdown: markdown, includeFrontmatter: false)

        #expect(!html.contains("frontmatter-card"))
        #expect(html.contains("Visible Body"))
        #expect(html.contains("Only this should render"))
    }

    @Test("No frontmatter produces no frontmatter-card div, body renders normally")
    func noFrontmatter() {
        let markdown = """
        # Just a Heading
        Regular markdown content without any frontmatter.
        """
        let html = MarkdownRenderer.renderHTMLFragment(markdown: markdown, includeFrontmatter: true)

        #expect(!html.contains("frontmatter-card"))
        #expect(html.contains("Just a Heading"))
        #expect(html.contains("Regular markdown content"))
    }

    // MARK: - renderHTMLFragment vs renderHTML

    @Test("renderHTMLFragment returns fragment without DOCTYPE wrapper")
    func fragmentHasNoDoctype() {
        let markdown = "# Hello"
        let html = MarkdownRenderer.renderHTMLFragment(markdown: markdown, includeFrontmatter: false)

        #expect(!html.contains("<!DOCTYPE html>"))
        #expect(!html.contains("<html"))
        #expect(!html.contains("<head"))
        #expect(html.contains("<h1"))
    }

    @Test("renderHTML returns complete document with DOCTYPE, style, and script tags")
    func fullDocumentHasDoctype() {
        let markdown = "# Hello"
        let html = MarkdownRenderer.renderHTML(markdown: markdown, includeFrontmatter: false)

        #expect(html.contains("<!DOCTYPE html>"))
        #expect(html.contains("<style>"))
        #expect(html.contains("<script>"))
        #expect(html.contains("<h1"))
    }

    // MARK: - JavaScript Escaping

    @Test("escapeForJavaScript escapes backslashes, quotes, and newlines")
    func escapeForJavaScript() {
        let input = "line1\nline2\r\n\"quoted\" and 'single' with back\\slash"
        let escaped = MarkdownRenderer.escapeForJavaScript(input)

        // Backslashes should be escaped
        #expect(escaped.contains("\\\\"))
        // Double quotes should be escaped
        #expect(escaped.contains("\\\""))
        // Single quotes should be escaped
        #expect(escaped.contains("\\'"))
        // Newlines should be escaped
        #expect(escaped.contains("\\n"))
        // Carriage returns should be escaped
        #expect(escaped.contains("\\r"))
        // The original unescaped characters should not appear unescaped
        #expect(!escaped.contains("\n"))
        #expect(!escaped.contains("\r"))
    }
}
