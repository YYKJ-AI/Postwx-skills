# Article Posting (文章发表)

Post markdown articles to WeChat Official Account via API with full formatting support.

## Usage

```bash
# Post markdown article
npx -y bun ./scripts/wechat-api.ts article.md

# With theme
npx -y bun ./scripts/wechat-api.ts article.md --theme grace

# With explicit options
npx -y bun ./scripts/wechat-api.ts article.md --author "作者名" --summary "摘要"
```

## Parameters

| Parameter | Description |
|-----------|-------------|
| `<file>` | Markdown (.md) or HTML (.html) file |
| `--theme <name>` | Theme: default, grace, simple, modern |
| `--color <name\|hex>` | Primary color (blue, green, vermilion, etc. or hex) |
| `--title <text>` | Override title (auto-extracted from markdown) |
| `--author <name>` | Author name |
| `--summary <text>` | Article summary |
| `--cover <path>` | Cover image path (local or URL) |
| `--dry-run` | Parse and render only, don't publish |

## Markdown Format

```markdown
---
title: Article Title
author: Author Name
---

# Title (becomes article title)

Regular paragraph with **bold** and *italic*.

## Section Header

![Image description](./image.png)

- List item 1
- List item 2

> Blockquote text

[Link text](https://example.com)
```

## Image Handling

1. **Parse**: Images in markdown are detected
2. **Upload**: Each image is uploaded to WeChat via API, returning a WeChat URL
3. **Replace**: Image `src` in HTML is replaced with the WeChat URL
4. **Publish**: Final HTML with WeChat image URLs is submitted to draft

## Scripts

| Script | Purpose |
|--------|---------|
| `wechat-api.ts` | Main article publishing script (API) |
| `md-to-wechat.ts` | Markdown to HTML with image placeholders |
| `md/render.ts` | Markdown rendering with themes |

## Example Session

```
User: /post-to-wechat article.md

Claude:
1. Parses markdown, finds 5 images
2. Renders HTML with theme
3. Uploads images to WeChat API
4. Publishes draft with processed HTML
5. Reports: "Draft saved. media_id: xxx"
```
