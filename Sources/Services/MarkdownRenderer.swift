import Foundation
import cmark_gfm
import cmark_gfm_extensions

enum MarkdownRenderer {

    // MARK: - Public API

    static func renderHTML(markdown: String, includeFrontmatter: Bool) -> String {
        let fragment = renderHTMLFragment(markdown: markdown, includeFrontmatter: includeFrontmatter)
        let js = highlightJSSource
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="color-scheme" content="light dark">
        <style>\(cssStylesheet)</style>
        <script>\(js)</script>
        </head>
        <body>
        <div id="content">\(fragment)</div>
        <script>hljs.highlightAll();</script>
        </body>
        </html>
        """
    }

    static func renderHTMLFragment(markdown: String, includeFrontmatter: Bool) -> String {
        var result = ""
        if includeFrontmatter {
            result += renderFrontmatterCard(from: markdown)
        }
        let body = extractBody(from: markdown)
        result += markdownToHTML(body)
        return result
    }

    static func escapeForJavaScript(_ string: String) -> String {
        var escaped = string
        escaped = escaped.replacingOccurrences(of: "\\", with: "\\\\")
        escaped = escaped.replacingOccurrences(of: "\"", with: "\\\"")
        escaped = escaped.replacingOccurrences(of: "'", with: "\\'")
        escaped = escaped.replacingOccurrences(of: "\n", with: "\\n")
        escaped = escaped.replacingOccurrences(of: "\r", with: "\\r")
        return escaped
    }

    // MARK: - Internal

    private static func markdownToHTML(_ markdown: String) -> String {
        cmark_gfm_core_extensions_ensure_registered()

        let parser = cmark_parser_new(CMARK_OPT_DEFAULT)
        defer { cmark_parser_free(parser) }

        if let tableExt = cmark_find_syntax_extension("table") {
            cmark_parser_attach_syntax_extension(parser, tableExt)
        }
        if let strikethroughExt = cmark_find_syntax_extension("strikethrough") {
            cmark_parser_attach_syntax_extension(parser, strikethroughExt)
        }

        let bytes = markdown.utf8
        cmark_parser_feed(parser, markdown, bytes.count)

        guard let doc = cmark_parser_finish(parser) else {
            return ""
        }
        defer { cmark_node_free(doc) }

        let extensions = cmark_parser_get_syntax_extensions(parser)
        guard let cString = cmark_render_html(doc, CMARK_OPT_DEFAULT, extensions) else {
            return ""
        }
        let html = String(cString: cString)
        free(cString)
        return html
    }

    private static func renderFrontmatterCard(from content: String) -> String {
        guard let result = try? SkillParser.parse(content: content) else {
            return ""
        }

        // Re-parse to get all fields (SkillParser only exposes name/description)
        let lines = content.components(separatedBy: "\n")
        guard let openIndex = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else {
            return ""
        }
        let searchStart = openIndex + 1
        guard searchStart < lines.count,
              let closeIndex = lines[searchStart...].firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else {
            return ""
        }

        let frontmatterLines = Array(lines[searchStart..<closeIndex])
        var fields: [(String, String)] = []
        var currentKey: String?
        var currentValue: String = ""

        for line in frontmatterLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty, !trimmed.hasPrefix(" "), !trimmed.hasPrefix("\t"),
               let colonRange = trimmed.range(of: ":") {
                if let key = currentKey {
                    fields.append((key, currentValue.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
                let key = String(trimmed[trimmed.startIndex..<colonRange.lowerBound])
                    .trimmingCharacters(in: .whitespaces)
                let afterColon = String(trimmed[colonRange.upperBound...])
                    .trimmingCharacters(in: .whitespaces)
                currentKey = key
                currentValue = afterColon
            } else if currentKey != nil {
                if currentValue.isEmpty {
                    currentValue = trimmed
                } else {
                    currentValue += " " + trimmed
                }
            }
        }
        if let key = currentKey {
            fields.append((key, currentValue.trimmingCharacters(in: .whitespacesAndNewlines)))
        }

        guard !fields.isEmpty else { return "" }

        var html = "<div class=\"frontmatter-card\"><dl>"
        for (key, value) in fields {
            let escapedKey = escapeHTML(key)
            let escapedValue = escapeHTML(value)
            html += "<dt>\(escapedKey)</dt><dd>\(escapedValue)</dd>"
        }
        html += "</dl></div>"
        return html
    }

    private static func extractBody(from content: String) -> String {
        let lines = content.components(separatedBy: "\n")

        guard let openIndex = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else {
            return content
        }

        let searchStart = openIndex + 1
        guard searchStart < lines.count,
              lines[searchStart...].contains(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }),
              let closeIndex = lines[searchStart...].firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else {
            return content
        }

        let bodyStartIndex = closeIndex + 1
        if bodyStartIndex < lines.count {
            return lines[bodyStartIndex...].joined(separator: "\n")
        }
        return ""
    }

    private static func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    // MARK: - CSS

    private static var cssStylesheet: String {
        """
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
        h1 { font-size: 1.8em; font-weight: 700; border-bottom: 1px solid light-dark(#d1d1d6, #3a3a3c); padding-bottom: 8px; }
        h2 { font-size: 1.4em; font-weight: 600; border-bottom: 1px solid light-dark(#d1d1d6, #3a3a3c); padding-bottom: 6px; }
        h3 { font-size: 1.2em; font-weight: 600; }
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
        table { border-collapse: collapse; width: 100%; margin: 16px 0; }
        th, td { border: 1px solid light-dark(#d1d1d6, #3a3a3c); padding: 8px 12px; text-align: left; }
        th { background: light-dark(#f5f5f7, #2c2c2e); font-weight: 600; }
        blockquote {
            border-left: 4px solid light-dark(#007aff, #0a84ff);
            padding-left: 16px;
            margin-left: 0;
            color: light-dark(#6e6e73, #98989d);
        }
        ul, ol { padding-left: 24px; }
        li { margin: 4px 0; }
        a { color: light-dark(#007aff, #0a84ff); text-decoration: none; }
        a:hover { text-decoration: underline; }
        hr { border: none; border-top: 1px solid light-dark(#d1d1d6, #3a3a3c); margin: 24px 0; }
        .frontmatter-card {
            background: light-dark(#f5f5f7, #1c1c1e);
            border: 1px solid light-dark(#d1d1d6, #3a3a3c);
            border-radius: 8px;
            padding: 12px 16px;
            margin-bottom: 20px;
        }
        .frontmatter-card dt { font-weight: 600; color: light-dark(#6e6e73, #98989d); font-size: 0.85em; text-transform: uppercase; letter-spacing: 0.5px; }
        .frontmatter-card dd { margin: 0 0 8px 0; }
        """
    }

    // MARK: - Highlight.js

    nonisolated(unsafe) private static var _highlightJSSource: String?

    private static var highlightJSSource: String {
        if let cached = _highlightJSSource {
            return cached
        }
        let source: String
        if let url = Bundle.main.url(forResource: "highlight.min", withExtension: "js"),
           let contents = try? String(contentsOf: url) {
            source = contents
        } else {
            source = ""
        }
        _highlightJSSource = source
        return source
    }
}
