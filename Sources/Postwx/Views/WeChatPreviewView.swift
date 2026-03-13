import SwiftUI
import WebKit

// MARK: - WeChat Phone Preview

struct WeChatPreviewView: View {
    let content: String
    let title: String
    let author: String
    let theme: Theme
    let color: ThemeColor
    let inputFormat: InputFormat

    var body: some View {
        GeometryReader { geo in
            let phoneWidth = min(geo.size.width - 32, 390)
            let phoneHeight = geo.size.height - 24

            ZStack {
                // Phone bezel
                RoundedRectangle(cornerRadius: 44)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 44)
                            .stroke(Color.black.opacity(0.12), lineWidth: 1)
                    )

                // Screen content
                VStack(spacing: 0) {
                    // Status bar
                    wechatStatusBar
                    // WebView content
                    WeChatWebView(
                        content: content,
                        title: title,
                        author: author,
                        theme: theme,
                        color: color,
                        inputFormat: inputFormat
                    )
                    // Bottom action bar
                    wechatBottomBar
                    // Home indicator
                    homeIndicator
                }
                .clipShape(RoundedRectangle(cornerRadius: 42))
                .padding(2)
            }
            .frame(width: phoneWidth, height: phoneHeight)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Status Bar

    private var wechatStatusBar: some View {
        HStack {
            Text("9:41")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            HStack(spacing: 5) {
                // Signal bars
                Image(systemName: "cellularbars")
                    .font(.system(size: 12))
                // WiFi
                Image(systemName: "wifi")
                    .font(.system(size: 12))
                // Battery
                Image(systemName: "battery.100")
                    .font(.system(size: 14))
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 6)
        .background(Color.white)
    }

    // MARK: - Bottom Action Bar

    private var wechatBottomBar: some View {
        HStack(spacing: 0) {
            // Like button
            HStack(spacing: 4) {
                Image(systemName: "heart")
                    .font(.system(size: 16))
                Text("喜欢")
                    .font(.system(size: 13))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)

            // Comment button
            HStack(spacing: 4) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 16))
                Text("评论")
                    .font(.system(size: 13))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)

            // Share button
            HStack(spacing: 4) {
                Image(systemName: "arrowshape.turn.up.right")
                    .font(.system(size: 16))
                Text("分享")
                    .font(.system(size: 13))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)

            // Collect button
            HStack(spacing: 4) {
                Image(systemName: "star")
                    .font(.system(size: 16))
                Text("收藏")
                    .font(.system(size: 13))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 10)
        .background(Color.white)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.black.opacity(0.06)).frame(height: 0.5)
        }
    }

    // MARK: - Home Indicator

    private var homeIndicator: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.black.opacity(0.2))
                .frame(width: 134, height: 5)
                .padding(.vertical, 8)
        }
        .background(Color.white)
    }
}

// MARK: - WKWebView Wrapper

struct WeChatWebView: NSViewRepresentable {
    let content: String
    let title: String
    let author: String
    let theme: Theme
    let color: ThemeColor
    let inputFormat: InputFormat

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        loadContent(webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        loadContent(webView)
    }

    private func loadContent(_ webView: WKWebView) {
        let html = buildHTML()
        webView.loadHTMLString(html, baseURL: nil)
    }

    // MARK: - HTML Builder

    private func buildHTML() -> String {
        let primaryColor = color.hexValue
        let articleContent: String
        if inputFormat == .html {
            articleContent = content
        } else {
            // Use JS-based markdown rendering
            articleContent = "__MD_CONTENT__"
        }

        let dateStr = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: Date())
        }()

        let displayTitle = title.isEmpty ? "未命名文章" : title
        let displayAuthor = author.isEmpty ? "作者" : author
        let themeCSS = cssForTheme(theme)
        let escapedContent = content
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system-font, BlinkMacSystemFont, "Helvetica Neue", "PingFang SC", "Hiragino Sans GB", "Microsoft YaHei UI", Arial, sans-serif;
            background: #fff;
            color: #333;
            -webkit-font-smoothing: antialiased;
            overflow-x: hidden;
        }

        /* WeChat Article Header */
        .wx-header {
            padding: 16px 16px 12px;
            border-bottom: 0.5px solid rgba(0,0,0,0.06);
        }
        .wx-account {
            display: flex;
            align-items: center;
            gap: 10px;
        }
        .wx-avatar {
            width: 36px;
            height: 36px;
            border-radius: 4px;
            background: linear-gradient(135deg, #07C160, #06AD56);
            display: flex;
            align-items: center;
            justify-content: center;
            color: #fff;
            font-size: 16px;
            font-weight: bold;
            flex-shrink: 0;
        }
        .wx-account-info {
            flex: 1;
            min-width: 0;
        }
        .wx-account-name {
            font-size: 15px;
            font-weight: 600;
            color: #333;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
        }
        .wx-account-meta {
            font-size: 12px;
            color: #999;
            margin-top: 2px;
        }
        .wx-follow-btn {
            padding: 4px 12px;
            background: #07C160;
            color: #fff;
            font-size: 12px;
            font-weight: 500;
            border-radius: 4px;
            flex-shrink: 0;
        }

        /* Article Title */
        .wx-title {
            padding: 20px 16px 8px;
            font-size: 22px;
            font-weight: bold;
            line-height: 1.4;
            color: #111;
        }
        .wx-byline {
            padding: 0 16px 16px;
            font-size: 12px;
            color: #999;
        }
        .wx-byline-author {
            color: #576b95;
        }

        /* Article Content Container */
        .wx-content {
            padding: 0 16px 24px;
        }

        /* Theme CSS Variables */
        :root {
            --md-primary-color: \(primaryColor);
            --md-font-family: -apple-system-font, BlinkMacSystemFont, "Helvetica Neue", "PingFang SC", "Hiragino Sans GB", "Microsoft YaHei UI", Arial, sans-serif;
            --md-font-size: 16px;
            --foreground: 0 0% 3.9%;
            --blockquote-background: #f7f7f7;
            --md-accent-color: #6B7280;
            --md-container-bg: transparent;
        }

        /* Base CSS */
        \(Self.baseCSS)

        /* Theme CSS */
        \(themeCSS)

        /* Override for preview container */
        #output {
            max-width: 100%;
        }

        /* Empty state */
        .wx-empty {
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            min-height: 200px;
            color: #ccc;
            font-size: 14px;
        }
        .wx-empty-icon {
            font-size: 48px;
            margin-bottom: 12px;
        }
        </style>
        </head>
        <body>
        <!-- WeChat Article Header -->
        <div class="wx-header">
            <div class="wx-account">
                <div class="wx-avatar">\(String(displayAuthor.prefix(1)))</div>
                <div class="wx-account-info">
                    <div class="wx-account-name">\(escapeHTML(displayAuthor))</div>
                    <div class="wx-account-meta">\(dateStr)</div>
                </div>
                <div class="wx-follow-btn">关注</div>
            </div>
        </div>

        <!-- Article Title -->
        <div class="wx-title">\(escapeHTML(displayTitle))</div>
        <div class="wx-byline">
            <span class="wx-byline-author">\(escapeHTML(displayAuthor))</span> · \(dateStr)
        </div>

        <!-- Article Content -->
        <div class="wx-content">
            <div id="output">
                \(inputFormat == .html ? articleContent : "")
            </div>
        </div>

        \(inputFormat != .html ? """
        <script>
        // Minimal Markdown to HTML converter
        function md2html(md) {
            // Protect code blocks
            var codeBlocks = [];
            md = md.replace(/```(\\w*)\\n([\\s\\S]*?)```/g, function(_, lang, code) {
                codeBlocks.push('<pre class="code__pre"><code>' + escHtml(code.trim()) + '</code></pre>');
                return '%%CODEBLOCK' + (codeBlocks.length - 1) + '%%';
            });

            // Protect inline code
            var inlineCodes = [];
            md = md.replace(/`([^`]+)`/g, function(_, code) {
                inlineCodes.push('<code>' + escHtml(code) + '</code>');
                return '%%INLINE' + (inlineCodes.length - 1) + '%%';
            });

            var lines = md.split('\\n');
            var html = '';
            var inList = false;
            var listType = '';
            var inBlockquote = false;
            var bqContent = '';

            for (var i = 0; i < lines.length; i++) {
                var line = lines[i];

                // Headers
                var hMatch = line.match(/^(#{1,6})\\s+(.+)$/);
                if (hMatch) {
                    if (inList) { html += '</' + listType + '>'; inList = false; }
                    if (inBlockquote) { html += '<blockquote><p>' + bqContent + '</p></blockquote>'; inBlockquote = false; bqContent = ''; }
                    var level = hMatch[1].length;
                    html += '<h' + level + '>' + inline(hMatch[2]) + '</h' + level + '>';
                    continue;
                }

                // Blockquote
                var bqMatch = line.match(/^>\\s*(.*)$/);
                if (bqMatch) {
                    if (inList) { html += '</' + listType + '>'; inList = false; }
                    if (inBlockquote) {
                        bqContent += '<br>' + inline(bqMatch[1]);
                    } else {
                        inBlockquote = true;
                        bqContent = inline(bqMatch[1]);
                    }
                    continue;
                } else if (inBlockquote) {
                    html += '<blockquote><p>' + bqContent + '</p></blockquote>';
                    inBlockquote = false;
                    bqContent = '';
                }

                // HR
                if (line.match(/^[-*_]{3,}\\s*$/)) {
                    if (inList) { html += '</' + listType + '>'; inList = false; }
                    html += '<hr>';
                    continue;
                }

                // Unordered list
                var ulMatch = line.match(/^[-*+]\\s+(.+)$/);
                if (ulMatch) {
                    if (!inList || listType !== 'ul') {
                        if (inList) html += '</' + listType + '>';
                        html += '<ul>';
                        inList = true;
                        listType = 'ul';
                    }
                    html += '<li>' + inline(ulMatch[1]) + '</li>';
                    continue;
                }

                // Ordered list
                var olMatch = line.match(/^\\d+\\.\\s+(.+)$/);
                if (olMatch) {
                    if (!inList || listType !== 'ol') {
                        if (inList) html += '</' + listType + '>';
                        html += '<ol>';
                        inList = true;
                        listType = 'ol';
                    }
                    html += '<li>' + inline(olMatch[1]) + '</li>';
                    continue;
                }

                // Close list if line doesn't match
                if (inList && line.trim() === '') {
                    html += '</' + listType + '>';
                    inList = false;
                    continue;
                }

                // Empty line
                if (line.trim() === '') continue;

                // Paragraph
                if (inList) { html += '</' + listType + '>'; inList = false; }
                html += '<p>' + inline(line) + '</p>';
            }

            if (inList) html += '</' + listType + '>';
            if (inBlockquote) html += '<blockquote><p>' + bqContent + '</p></blockquote>';

            // Restore code blocks
            for (var j = 0; j < codeBlocks.length; j++) {
                html = html.replace('%%CODEBLOCK' + j + '%%', codeBlocks[j]);
            }
            for (var k = 0; k < inlineCodes.length; k++) {
                html = html.replace('%%INLINE' + k + '%%', inlineCodes[k]);
            }

            return html;
        }

        function inline(text) {
            return text
                .replace(/!\\[([^\\]]*)\\]\\(([^)]+)\\)/g, '<img src="$2" alt="$1">')
                .replace(/\\[([^\\]]+)\\]\\(([^)]+)\\)/g, '<a href="$2">$1</a>')
                .replace(/\\*\\*(.+?)\\*\\*/g, '<strong>$1</strong>')
                .replace(/\\*(.+?)\\*/g, '<em>$1</em>')
                .replace(/~~(.+?)~~/g, '<del>$1</del>');
        }

        function escHtml(s) {
            return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
        }

        // Render markdown content
        var content = `\(escapedContent)`;
        document.getElementById('output').innerHTML = md2html(content);
        </script>
        """ : "")
        </body>
        </html>
        """
    }

    private func escapeHTML(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
         .replacingOccurrences(of: "\"", with: "&quot;")
    }

    // MARK: - CSS

    private func cssForTheme(_ theme: Theme) -> String {
        switch theme {
        case .default_: Self.defaultThemeCSS
        case .grace: Self.graceThemeCSS
        case .simple: Self.simpleThemeCSS
        case .modern: Self.modernThemeCSS
        }
    }

    // Base CSS (from base.css)
    static let baseCSS = """
    section, container {
        font-family: var(--md-font-family);
        font-size: var(--md-font-size);
        line-height: 1.75;
        text-align: left;
    }
    #output {
        font-family: var(--md-font-family);
        font-size: var(--md-font-size);
        line-height: 1.75;
        text-align: left;
    }
    blockquote { margin: 0; }
    #output section > :first-child { margin-top: 0 !important; }
    pre.code__pre, .hljs.code__pre {
        font-size: 90%; overflow-x: auto; border-radius: 8px;
        padding: 0 !important; line-height: 1.5; margin: 10px 8px;
        box-shadow: inset 0 0 10px rgba(0,0,0,0.05);
    }
    img { display: block; max-width: 100%; margin: 0.1em auto 0.5em; border-radius: 4px; }
    ol { padding-left: 1em; margin-left: 0; color: hsl(var(--foreground)); }
    ul { list-style: circle; padding-left: 1em; margin-left: 0; color: hsl(var(--foreground)); }
    li { display: block; margin: 0.2em 8px; color: hsl(var(--foreground)); }
    p.footnotes { margin: 0.5em 8px; font-size: 80%; color: hsl(var(--foreground)); }
    figure { margin: 1.5em 8px; color: hsl(var(--foreground)); }
    figcaption, .md-figcaption { text-align: center; color: #888; font-size: 0.8em; }
    hr { border-style: solid; border-width: 2px 0 0; border-color: rgba(0,0,0,0.1); height: 0.4em; margin: 1.5em 0; }
    code { font-size: 90%; color: #d14; background: rgba(27,31,35,0.05); padding: 3px 5px; border-radius: 4px; }
    pre.code__pre > code, .hljs.code__pre > code {
        display: -webkit-box; padding: 0.5em 1em 1em; overflow-x: auto;
        text-indent: 0; color: inherit; background: none; white-space: nowrap; margin: 0;
    }
    em { font-style: italic; font-size: inherit; }
    a { color: #576b95; text-decoration: none; }
    strong { color: var(--md-primary-color); font-weight: bold; font-size: inherit; }
    table { color: hsl(var(--foreground)); }
    thead { font-weight: bold; color: hsl(var(--foreground)); }
    th { border: 1px solid #dfdfdf; padding: 0.25em 0.5em; color: hsl(var(--foreground)); word-break: keep-all; background: rgba(0,0,0,0.05); }
    td { border: 1px solid #dfdfdf; padding: 0.25em 0.5em; color: hsl(var(--foreground)); word-break: keep-all; }
    """

    // Default theme CSS
    static let defaultThemeCSS = """
    h1 { display: table; padding: 0 1em; border-bottom: 2px solid var(--md-primary-color); margin: 2em auto 1em; color: hsl(var(--foreground)); font-size: calc(var(--md-font-size) * 1.2); font-weight: bold; text-align: center; }
    h2 { display: table; padding: 0 0.2em; margin: 4em auto 2em; color: #fff; background: var(--md-primary-color); font-size: calc(var(--md-font-size) * 1.2); font-weight: bold; text-align: center; }
    h3 { padding-left: 8px; border-left: 3px solid var(--md-primary-color); margin: 2em 8px 0.75em 0; color: hsl(var(--foreground)); font-size: calc(var(--md-font-size) * 1.1); font-weight: bold; line-height: 1.2; }
    h4 { margin: 2em 8px 0.5em; color: var(--md-primary-color); font-size: calc(var(--md-font-size) * 1); font-weight: bold; }
    h5 { margin: 1.5em 8px 0.5em; color: var(--md-primary-color); font-size: calc(var(--md-font-size) * 1); font-weight: bold; }
    h6 { margin: 1.5em 8px 0.5em; font-size: calc(var(--md-font-size) * 1); color: var(--md-primary-color); }
    p { margin: 1.5em 8px; letter-spacing: 0.1em; color: hsl(var(--foreground)); }
    blockquote { font-style: normal; padding: 1em; border-left: 4px solid var(--md-primary-color); border-radius: 6px; color: hsl(var(--foreground)); background: var(--blockquote-background); margin-bottom: 1em; }
    blockquote > p { display: block; font-size: 1em; letter-spacing: 0.1em; color: hsl(var(--foreground)); margin: 0; }
    """

    // Grace theme CSS
    static let graceThemeCSS = """
    h1 { padding: 0.5em 1em; border-bottom: 2px solid var(--md-primary-color); font-size: calc(var(--md-font-size) * 1.4); text-shadow: 2px 2px 4px rgba(0,0,0,0.1); display: table; margin: 2em auto 1em; color: hsl(var(--foreground)); font-weight: bold; text-align: center; }
    h2 { padding: 0.3em 1em; border-radius: 8px; font-size: calc(var(--md-font-size) * 1.3); box-shadow: 0 4px 6px rgba(0,0,0,0.1); display: table; margin: 4em auto 2em; color: #fff; background: var(--md-primary-color); font-weight: bold; text-align: center; }
    h3 { padding-left: 12px; font-size: calc(var(--md-font-size) * 1.2); border-left: 4px solid var(--md-primary-color); border-bottom: 1px dashed var(--md-primary-color); margin: 2em 8px 0.75em 0; color: hsl(var(--foreground)); font-weight: bold; line-height: 1.2; }
    h4 { font-size: calc(var(--md-font-size) * 1.1); margin: 2em 8px 0.5em; color: var(--md-primary-color); font-weight: bold; }
    h5 { font-size: var(--md-font-size); margin: 1.5em 8px 0.5em; color: var(--md-primary-color); font-weight: bold; }
    h6 { font-size: var(--md-font-size); margin: 1.5em 8px 0.5em; color: var(--md-primary-color); }
    p { margin: 1.5em 8px; letter-spacing: 0.1em; color: hsl(var(--foreground)); }
    blockquote { font-style: italic; padding: 1em 1em 1em 2em; border-left: 4px solid var(--md-primary-color); border-radius: 6px; color: rgba(0,0,0,0.6); box-shadow: 0 4px 6px rgba(0,0,0,0.05); margin-bottom: 1em; }
    blockquote > p { display: block; font-size: 1em; letter-spacing: 0.1em; color: rgba(0,0,0,0.6); margin: 0; }
    img { border-radius: 8px; box-shadow: 0 4px 8px rgba(0,0,0,0.1); }
    li { margin: 0.5em 8px; }
    """

    // Simple theme CSS
    static let simpleThemeCSS = """
    h1 { padding: 0.5em 1em; font-size: calc(var(--md-font-size) * 1.4); text-shadow: 1px 1px 3px rgba(0,0,0,0.05); display: table; border-bottom: 2px solid var(--md-primary-color); margin: 2em auto 1em; color: hsl(var(--foreground)); font-weight: bold; text-align: center; }
    h2 { padding: 0.3em 1.2em; font-size: calc(var(--md-font-size) * 1.3); border-radius: 8px 24px 8px 24px; box-shadow: 0 2px 6px rgba(0,0,0,0.06); display: table; margin: 4em auto 2em; color: #fff; background: var(--md-primary-color); font-weight: bold; text-align: center; }
    h3 { padding-left: 12px; font-size: calc(var(--md-font-size) * 1.2); border-radius: 6px; line-height: 2.4em; border-left: 4px solid var(--md-primary-color); margin: 2em 8px 0.75em 0; color: hsl(var(--foreground)); font-weight: bold; }
    h4 { font-size: calc(var(--md-font-size) * 1.1); border-radius: 6px; margin: 2em 8px 0.5em; color: var(--md-primary-color); font-weight: bold; }
    h5 { font-size: var(--md-font-size); border-radius: 6px; margin: 1.5em 8px 0.5em; color: var(--md-primary-color); font-weight: bold; }
    h6 { font-size: var(--md-font-size); border-radius: 6px; margin: 1.5em 8px 0.5em; color: var(--md-primary-color); }
    p { margin: 1.5em 8px; letter-spacing: 0.1em; color: hsl(var(--foreground)); }
    blockquote { font-style: italic; padding: 1em 1em 1em 2em; color: rgba(0,0,0,0.6); border-left: 4px solid var(--md-primary-color); border-radius: 6px; background: var(--blockquote-background); margin-bottom: 1em; }
    blockquote > p { display: block; font-size: 1em; letter-spacing: 0.1em; color: rgba(0,0,0,0.6); margin: 0; }
    img { border-radius: 8px; }
    li { margin: 0.5em 8px; }
    """

    // Modern theme CSS
    static let modernThemeCSS = """
    section, container { line-height: 2; letter-spacing: 0px; font-weight: 400; background-color: var(--md-container-bg); border: 1px solid rgba(255,255,255,0.01); border-radius: 25px; padding: 12px; }
    #output { line-height: 2; }
    h1 { display: table; padding: 0.3em 1em; margin: 20px auto; color: hsl(var(--foreground)); background: var(--md-primary-color); border-radius: 15px; font-size: 28px; font-weight: bold; text-align: center; border-bottom: none; }
    h2 { display: block; padding: 0.2em 0; margin: 0 auto 20px; width: 100%; color: var(--md-primary-color); font-size: 20px; font-weight: bold; letter-spacing: 0.578px; line-height: 1.7; border-bottom: 2px solid var(--md-accent-color); text-align: left; background: none; }
    h3 { padding-left: 10px; border-left: 4px solid var(--md-primary-color); border-radius: 2px; margin: 0 8px 10px; color: hsl(var(--foreground)); font-size: 20px; font-weight: bold; line-height: 1.2; }
    h4 { margin: 0 8px 10px; color: var(--md-primary-color); font-size: 16px; font-weight: bold; }
    h5 { display: inline-block; margin: 0 8px 10px; padding: 4px 12px; color: hsl(var(--foreground)); background: rgba(255,255,255,0.7); border: 1px solid rgb(189,224,254); border-radius: 20px; font-size: 16px; font-weight: 500; }
    h6 { margin: 0 8px 10px; color: var(--md-primary-color); font-size: 16px; font-weight: bold; }
    p { margin: 20px 0; letter-spacing: 0px; color: hsl(var(--foreground)); line-height: 2; font-size: 15px; font-weight: 400; }
    blockquote { font-style: normal; padding: 15px 0; margin: 12px 0; border-left: 7px solid var(--md-accent-color); border-radius: 10px; color: hsl(var(--foreground)); background-color: var(--blockquote-background); }
    blockquote > p { display: block; font-size: 1em; letter-spacing: 0.1em; color: hsl(var(--foreground)); margin: 0; }
    img { border-radius: 10px; }
    ol, ul { line-height: 2; }
    hr { border-width: 1px 0 0; border-color: var(--md-accent-color); }
    """
}

// MARK: - ThemeColor Hex Values

extension ThemeColor {
    var hexValue: String {
        switch self {
        case .blue: "#0F4C81"
        case .green: "#009874"
        case .vermilion: "#FA5151"
        case .yellow: "#FECE00"
        case .purple: "#92617E"
        case .sky: "#55C9EA"
        case .rose: "#B76E79"
        case .olive: "#556B2F"
        case .black: "#333333"
        case .gray: "#A9A9A9"
        case .pink: "#FFB7C5"
        case .red: "#A93226"
        case .orange: "#D97757"
        }
    }
}
