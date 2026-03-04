---
name: baoyu-post-to-wechat
description: Posts content to WeChat Official Account (微信公众号) via API. Supports article posting (文章) with HTML, markdown, or plain text input. Use when user mentions "发布公众号", "post to wechat", "微信公众号", or "文章".
---

# Post to WeChat Official Account

## Language

**Match user's language**: Respond in the same language the user uses. If user writes in Chinese, respond in Chinese. If user writes in English, respond in English.

## Script Directory

**Agent Execution**: Determine this SKILL.md directory as `SKILL_DIR`, then use `${SKILL_DIR}/scripts/<name>.ts`.

| Script | Purpose |
|--------|---------|
| `scripts/wechat-api.ts` | Article posting via API (文章) |
| `scripts/md-to-wechat.ts` | Markdown → WeChat-ready HTML with image placeholders |

## Preferences (EXTEND.md)

Use Bash to check EXTEND.md existence (priority order):

```bash
# Check project-level first
test -f .baoyu-skills/baoyu-post-to-wechat/EXTEND.md && echo "project"

# Then user-level (cross-platform: $HOME works on macOS/Linux/WSL)
test -f "$HOME/.baoyu-skills/baoyu-post-to-wechat/EXTEND.md" && echo "user"
```

┌────────────────────────────────────────────────────────┬───────────────────┐
│                          Path                          │     Location      │
├────────────────────────────────────────────────────────┼───────────────────┤
│ .baoyu-skills/baoyu-post-to-wechat/EXTEND.md           │ Project directory │
├────────────────────────────────────────────────────────┼───────────────────┤
│ $HOME/.baoyu-skills/baoyu-post-to-wechat/EXTEND.md     │ User home         │
└────────────────────────────────────────────────────────┴───────────────────┘

┌───────────┬───────────────────────────────────────────────────────────────────────────┐
│  Result   │                                  Action                                   │
├───────────┼───────────────────────────────────────────────────────────────────────────┤
│ Found     │ Read, parse, apply settings                                               │
├───────────┼───────────────────────────────────────────────────────────────────────────┤
│ Not found │ Run first-time setup ([references/config/first-time-setup.md](references/config/first-time-setup.md)) → Save → Continue │
└───────────┴───────────────────────────────────────────────────────────────────────────┘

**EXTEND.md Supports**: Default theme | Default color | Default author | Default open-comment switch | Default fans-only-comment switch

First-time setup: [references/config/first-time-setup.md](references/config/first-time-setup.md)

**Minimum supported keys** (case-insensitive, accept `1/0` or `true/false`):

| Key | Default | Mapping |
|-----|---------|---------|
| `default_author` | empty | Fallback for `author` when CLI/frontmatter not provided |
| `need_open_comment` | `1` | `articles[].need_open_comment` in `draft/add` request |
| `only_fans_can_comment` | `0` | `articles[].only_fans_can_comment` in `draft/add` request |

**Recommended EXTEND.md example**:

```md
default_theme: default
default_color: blue
default_author: 宝玉
need_open_comment: 1
only_fans_can_comment: 0
```

**Theme options**: default, grace, simple, modern

**Color presets**: blue, green, vermilion, yellow, purple, sky, rose, olive, black, gray, pink, red, orange (or hex value)

**Value priority**:
1. CLI arguments
2. Frontmatter
3. EXTEND.md
4. Skill defaults

## Article Posting Workflow (文章)

Copy this checklist and check off items as you complete them:

```
Publishing Progress:
- [ ] Step 0: Load preferences (EXTEND.md)
- [ ] Step 1: Determine input type
- [ ] Step 2: Configure API credentials
- [ ] Step 3: Resolve theme/color and validate metadata
- [ ] Step 4: Publish to WeChat
- [ ] Step 5: Report completion
```

### Step 0: Load Preferences

Check and load EXTEND.md settings (see Preferences section above).

**CRITICAL**: If not found, complete first-time setup BEFORE any other steps or questions.

Resolve and store these defaults for later steps:
- `default_theme` (default `default`)
- `default_color` (omit if not set — theme default applies)
- `default_author`
- `need_open_comment` (default `1`)
- `only_fans_can_comment` (default `0`)

### Step 1: Determine Input Type

| Input Type | Detection | Action |
|------------|-----------|--------|
| HTML file | Path ends with `.html`, file exists | Skip to Step 3 |
| Markdown file | Path ends with `.md`, file exists | Continue to Step 2 |
| Plain text | Not a file path, or file doesn't exist | Save to markdown, continue to Step 2 |

**Plain Text Handling**:

1. Generate slug from content (first 2-4 meaningful words, kebab-case)
2. Create directory and save file:

```bash
mkdir -p "$(pwd)/post-to-wechat/$(date +%Y-%m-%d)"
# Save content to: post-to-wechat/yyyy-MM-dd/[slug].md
```

3. Continue processing as markdown file

**Slug Examples**:
- "Understanding AI Models" → `understanding-ai-models`
- "人工智能的未来" → `ai-future` (translate to English for slug)

### Step 2: Configure API Credentials

**Check Credentials**:

```bash
# Check project-level
test -f .baoyu-skills/.env && grep -q "WECHAT_APP_ID" .baoyu-skills/.env && echo "project"

# Check user-level
test -f "$HOME/.baoyu-skills/.env" && grep -q "WECHAT_APP_ID" "$HOME/.baoyu-skills/.env" && echo "user"
```

**If Missing - Guide Setup**:

```
WeChat API credentials not found.

To obtain credentials:
1. Visit https://mp.weixin.qq.com
2. Go to: 开发 → 基本配置
3. Copy AppID and AppSecret

Where to save?
A) Project-level: .baoyu-skills/.env (this project only)
B) User-level: ~/.baoyu-skills/.env (all projects)
```

After location choice, prompt for values and write to `.env`:

```
WECHAT_APP_ID=<user_input>
WECHAT_APP_SECRET=<user_input>
```

### Step 3: Resolve Theme/Color and Validate Metadata

1. **Resolve theme** (first match wins, do NOT ask user if resolved):
   - CLI `--theme` argument
   - EXTEND.md `default_theme` (loaded in Step 0)
   - Fallback: `default`

2. **Resolve color** (first match wins):
   - CLI `--color` argument
   - EXTEND.md `default_color` (loaded in Step 0)
   - Omit if not set (theme default applies)

3. **Validate metadata** from frontmatter (markdown) or HTML meta tags (HTML input):

| Field | If Missing |
|-------|------------|
| Title | Prompt: "Enter title, or press Enter to auto-generate from content" |
| Summary | Prompt: "Enter summary, or press Enter to auto-generate (recommended for SEO)" |
| Author | Use fallback chain: CLI `--author` → frontmatter `author` → EXTEND.md `default_author` |

**Auto-Generation Logic**:
- **Title**: First H1/H2 heading, or first sentence
- **Summary**: First paragraph, truncated to 120 characters

4. **Cover Image Check** (required for API `article_type=news`):
   1. Use CLI `--cover` if provided.
   2. Else use frontmatter (`coverImage`, `featureImage`, `cover`, `image`).
   3. Else check article directory default path: `imgs/cover.png`.
   4. Else fallback to first inline content image.
   5. If still missing, stop and request a cover image before publishing.

### Step 4: Publish to WeChat

**CRITICAL**: Publishing scripts handle markdown conversion internally. Do NOT pre-convert markdown to HTML — pass the original markdown file directly.

```bash
npx -y bun ${SKILL_DIR}/scripts/wechat-api.ts <file> --theme <theme> [--color <color>] [--title <title>] [--summary <summary>] [--author <author>] [--cover <cover_path>]
```

**CRITICAL**: Always include `--theme` parameter. Never omit it, even if using `default`. Only include `--color` if explicitly set by user or EXTEND.md.

**`draft/add` payload rules**:
- Use endpoint: `POST https://api.weixin.qq.com/cgi-bin/draft/add?access_token=ACCESS_TOKEN`
- `article_type`: `news` (default) or `newspic`
- For `news`, include `thumb_media_id` (cover is required)
- Always resolve and send:
  - `need_open_comment` (default `1`)
  - `only_fans_can_comment` (default `0`)
- `author` resolution: CLI `--author` → frontmatter `author` → EXTEND.md `default_author`

If script parameters do not expose the two comment fields, still ensure final API request body includes resolved values.

### Step 5: Completion Report

```
WeChat Publishing Complete!

Input: [type] - [path]
Theme: [theme name] [color if set]

Article:
• Title: [title]
• Summary: [summary]
• Images: [N] inline images
• Comments: [open/closed], [fans-only/all users]

Result:
✓ Draft saved to WeChat Official Account
• media_id: [media_id]

Next Steps:
→ Manage drafts: https://mp.weixin.qq.com (登录后进入「内容管理」→「草稿箱」)

Files created:
[• post-to-wechat/yyyy-MM-dd/slug.md (if plain text)]
[• slug.html (converted)]
```

## AI Image Generation (自动配图)

### Overview

自动配图支持三种方式为文章添加 AI 生成图片，生成后自动上传到微信素材库。

### Method 1: Natural Language (推荐)

Claude 读取文章 → 理解上下文 → 创建提示词 → 插入 Markdown → 发布时自动生成

```
用户: "帮我在文章开头配一张图"

Claude 自动处理:
1. 读取文章内容，理解主题
2. 确定最佳插入位置
3. 创建英文图片提示词
4. 在 Markdown 中插入: ![描述](__generate:A modern illustration of...__)
5. 发布时自动调用图片生成 API 并上传
```

### Method 2: Manual Markdown Syntax

```markdown
![科技封面](__generate:A futuristic tech illustration with blue neon lights, minimalist style, 16:9__)
```

### Syntax

```
![图片描述](__generate:英文提示词__)
```

- `__generate:` — 固定前缀，标识 AI 生成图片
- 提示词必须用英文，描述越具体越好
- 建议包含：风格(minimalist/flat/watercolor)、构图(wide/close-up)、色调(warm/blue)

### Image API Configuration

使用兼容 OpenAI 格式的图片生成 API。环境变量：

```
IMAGE_API_KEY=sk-xxx                       # 必填：API 密钥
IMAGE_API_BASE=https://api.openai.com/v1   # 可选：API 地址
IMAGE_MODEL=dall-e-3                       # 可选：模型名称
IMAGE_SIZE=1792x1024                       # 可选：默认尺寸
```

配置位置与微信凭证相同（环境变量 > `.baoyu-skills/.env` > `~/.baoyu-skills/.env`）

### Processing Pipeline

```
Markdown: ![alt](__generate:prompt__)
  ↓ 渲染
HTML: <img src="__generate:prompt__" alt="alt">
  ↓ wechat-api.ts 检测 __generate: 前缀
调用图片生成 API → 获取图片
  ↓
上传微信素材库 → 获取 CDN URL → 替换 src
```

**错误处理**: IMAGE_API_KEY 未配置时跳过生成并输出警告；API 失败时跳过该图片继续处理。

---

## AI Trace Removal (去AI味 / Humanizer)

### Overview

Humanizer 检测并去除文章中的 AI 写作痕迹，可独立使用或与发布流程组合。

### Trigger

| 用户输入 | 动作 |
|---------|------|
| "去AI味" / "去除AI痕迹" / "humanize" | 对文章执行去痕处理 |
| "润色" / "让文章更自然" | 去痕 + 风格优化 |
| 发布前附加 "去AI味" | 先去痕再发布 |

### Intensity Levels

| 级别 | 场景 | 说明 |
|------|------|------|
| gentle | 文本已较自然 | 只改明显问题 |
| **medium**（默认） | 大多数场景 | 标准去痕 |
| aggressive | AI味很重 | 深度去除 |

### 24 AI Trace Patterns

**内容模式（6种）**:

| # | 模式 | 示例 | 处理 |
|---|------|------|------|
| 1 | 过度强调意义/遗产 | "划时代的发现将永远改变人类" | 简化为客观陈述 |
| 2 | 过度强调知名度 | "业界公认的权威专家" | 去除不必要修饰 |
| 3 | 以-ing肤浅分析 | "引领着、推动着、改变着" | 用具体动词替代 |
| 4 | 宣传/广告式语言 | "革命性的、颠覆性的" | 替换为中性描述 |
| 5 | 模糊归因 | "据专家表示"、"研究表明" | 补充来源或删除 |
| 6 | 公式化总结 | "挑战与机遇并存" | 用具体结论替代 |

**语言模式（6种）**:

| # | 模式 | 示例 | 处理 |
|---|------|------|------|
| 7 | AI高频词 | "此外、至关重要、深入探讨、彰显、赋能、助力" | 替换日常用语 |
| 8 | 系动词回避 | "作为…的存在"（回避"是"） | 恢复自然"是"字句 |
| 9 | 否定式排比 | "不仅…而且…更是…" | 简化直接陈述 |
| 10 | 三段式过度使用 | 每观点三个并列 | 打破固定结构 |
| 11 | 刻意换词 | 同概念反复换词指代 | 统一用词 |
| 12 | 虚假范围 | "从…到…，从…到…" | 聚焦具体点 |

**风格模式（4种）**:

| # | 模式 | 处理 |
|---|------|------|
| 13 | 破折号过度 | 保留关键，简化其余 |
| 14 | 粗体过度 | 仅保留核心关键词 |
| 15 | 正文列表化 | 恢复段落叙述 |
| 16 | 表情符号装饰 | 去除（除非刻意保留） |

**填充词（4种）**:

| # | 模式 | 示例 | 处理 |
|---|------|------|------|
| 17 | 填充短语 | "为了实现这一目标"、"在当今时代" | 删除 |
| 18 | 过度限定 | "在某种程度上来说" | 简化/删除 |
| 19 | 通用积极结论 | "总之，未来可期" | 具体结论替代 |
| 20 | 绕圈回避 | 长句绕开直接表态 | 直接表述 |

**交流痕迹（4种）**:

| # | 模式 | 示例 | 处理 |
|---|------|------|------|
| 21 | 协作痕迹 | "希望对您有帮助" | 删除 |
| 22 | 截止免责 | "截至我所知…" | 删除 |
| 23 | 谄媚语气 | "非常好的问题" | 删除 |
| 24 | 交流特征 | "让我来为您解释" | 删除 |

### Quality Scoring (5 Dimensions, Total 50)

| 维度 | 满分 | 10分标准 | 1分标准 |
|------|------|---------|---------|
| 直接性 | 10 | 直截了当 | 铺垫绕圈 |
| 节奏感 | 10 | 长短交错 | 机械等长 |
| 信任度 | 10 | 简洁尊重读者 | 过度解释 |
| 真实性 | 10 | 像真人说话 | 机械生硬 |
| 精炼度 | 10 | 无冗余 | 大量废话 |

**评级**: 45-50 优秀 | 35-44 良好 | <35 需修订

### Workflow

```
输入文章
  ↓
扫描 24 种 AI 痕迹模式
  ↓
根据强度级别修改文本
  ↓
5 维度评分
  ↓
输出: 修改后文章 + 修改报告 + 评分
```

**修改报告格式**:
```
1. [填充短语] "为了实现这一目标" → 删除
2. [AI高频词] "深入探讨" → "聊聊"
3. [过度强调] "划时代里程碑" → "重要进展"

评分: 直接性8 + 节奏9 + 信任8 + 真实9 + 精炼8 = 42/50 (良好)
```

### Combined Usage

去AI味可在发布前自动执行：
1. 用户请求发布并提到"去AI味"
2. Claude 先对文章内容执行 Humanizer
3. 输出修改报告和评分
4. 用修改后的内容继续发布流程

---

## Detailed References

| Topic | Reference |
|-------|-----------|
| Article themes, image handling | [references/article-posting.md](references/article-posting.md) |

## Features

| Feature | Supported |
|---------|-----------|
| Plain text input | ✓ |
| HTML input | ✓ |
| Markdown input | ✓ |
| Inline images | ✓ |
| Themes | ✓ |
| Auto-generate metadata | ✓ |
| Default cover fallback (`imgs/cover.png`) | ✓ |
| Comment control (`need_open_comment`, `only_fans_can_comment`) | ✓ |
| AI image generation (自动配图) | ✓ |
| AI trace removal (去AI味) | ✓ |

## Prerequisites

- WeChat Official Account API credentials
- Guided setup in Step 2, or manually set in `.baoyu-skills/.env`

**Config File Locations** (priority order):
1. Environment variables
2. `<cwd>/.baoyu-skills/.env`
3. `~/.baoyu-skills/.env`

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Missing API credentials | Follow guided setup in Step 2 |
| Access token error | Check if API credentials are valid and not expired |
| Title/summary missing | Use auto-generation or provide manually |
| No cover image | Add frontmatter cover or place `imgs/cover.png` in article directory |
| Wrong comment defaults | Check `EXTEND.md` keys `need_open_comment` and `only_fans_can_comment` |

## Extension Support

Custom configurations via EXTEND.md. See **Preferences** section for paths and supported options.
