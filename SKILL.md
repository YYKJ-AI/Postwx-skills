---
name: Postwx
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
test -f .baoyu-skills/Postwx/EXTEND.md && echo "project"

# Then user-level (cross-platform: $HOME works on macOS/Linux/WSL)
test -f "$HOME/.baoyu-skills/Postwx/EXTEND.md" && echo "user"
```

┌────────────────────────────────────────────────────────┬───────────────────┐
│                          Path                          │     Location      │
├────────────────────────────────────────────────────────┼───────────────────┤
│ .baoyu-skills/Postwx/EXTEND.md           │ Project directory │
├────────────────────────────────────────────────────────┼───────────────────┤
│ $HOME/.baoyu-skills/Postwx/EXTEND.md     │ User home         │
└────────────────────────────────────────────────────────┴───────────────────┘

┌───────────┬───────────────────────────────────────────────────────────────────────────┐
│  Result   │                                  Action                                   │
├───────────┼───────────────────────────────────────────────────────────────────────────┤
│ Found     │ Read, parse, apply settings                                               │
├───────────┼───────────────────────────────────────────────────────────────────────────┤
│ Not found │ Run first-time setup ([references/config/first-time-setup.md](references/config/first-time-setup.md)) → Save → Continue │
└───────────┴───────────────────────────────────────────────────────────────────────────┘

**EXTEND.md Supports**: Creator role | Writing style | Target audience | Default author | Comment switches

First-time setup: [references/config/first-time-setup.md](references/config/first-time-setup.md)

**Minimum supported keys** (case-insensitive, accept `1/0` or `true/false`):

| Key | Default | Description |
|-----|---------|-------------|
| `creator_role` | `tech-blogger` | Content creator type for role adaptation |
| `writing_style` | `professional` | Writing style for de-AI processing |
| `target_audience` | `general` | Target audience for tone adjustment |
| `default_author` | empty | Fallback for `author` when CLI/frontmatter not provided |
| `need_open_comment` | `1` | `articles[].need_open_comment` in `draft/add` request |
| `only_fans_can_comment` | `0` | `articles[].only_fans_can_comment` in `draft/add` request |

**Recommended EXTEND.md example**:

```md
creator_role: tech-blogger
writing_style: professional
target_audience: general
default_author: 宝玉
need_open_comment: 1
only_fans_can_comment: 0
```

## Article Posting Workflow (文章)

Copy this checklist and check off items as you complete them:

```
Publishing Progress:
- [ ] Step 0: Load preferences + check credentials
- [ ] Step 1: Determine input type
- [ ] Step 2: Role-based content adaptation
- [ ] Step 3: Auto de-AI processing
- [ ] Step 4: Auto theme & color selection
- [ ] Step 5: Auto image generation
- [ ] Step 6: Validate metadata + publish
- [ ] Step 7: Completion report
```

### Step 0: Load Preferences + Check Credentials

Check and load EXTEND.md settings (see Preferences section above).

**CRITICAL**: If not found, complete first-time setup BEFORE any other steps or questions.

Resolve and store these defaults for later steps:
- `creator_role` (default `tech-blogger`)
- `writing_style` (default `professional`)
- `target_audience` (default `general`)
- `default_author`
- `need_open_comment` (default `1`)
- `only_fans_can_comment` (default `0`)

**Check Credentials**:

```bash
# Check WeChat credentials
test -f .baoyu-skills/.env && grep -q "WECHAT_APP_ID" .baoyu-skills/.env && echo "wechat-project"
test -f "$HOME/.baoyu-skills/.env" && grep -q "WECHAT_APP_ID" "$HOME/.baoyu-skills/.env" && echo "wechat-user"

# Check image API key
test -f .baoyu-skills/.env && grep -q "IMAGE_API_KEY" .baoyu-skills/.env && echo "image-project"
test -f "$HOME/.baoyu-skills/.env" && grep -q "IMAGE_API_KEY" "$HOME/.baoyu-skills/.env" && echo "image-user"
```

**If WeChat credentials missing** — guide setup:

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

**If IMAGE_API_KEY missing** — warn but continue (images will be skipped):

```
IMAGE_API_KEY not configured. AI image generation will be skipped.
Add to your .baoyu-skills/.env:
IMAGE_API_KEY=sk-xxx
```

### Step 1: Determine Input Type

| Input Type | Detection | Action |
|------------|-----------|--------|
| HTML file | Path ends with `.html`, file exists | Skip to Step 6 |
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

### Step 2: Role-Based Content Adaptation

Based on EXTEND.md `creator_role`, `writing_style`, and `target_audience`, adapt the article content:

| Role | Adaptation |
|------|-----------|
| `tech-blogger` | 技术术语保留，加入实用性观点，结构清晰 |
| `lifestyle-writer` | 口语化，加入个人感受，场景描写 |
| `educator` | 层次分明，循序渐进，加入总结要点 |
| `business-analyst` | 数据支撑，行业视角，趋势分析 |

| Style | Adaptation |
|-------|-----------|
| `professional` | 严谨用词，逻辑清晰，适度使用专业术语 |
| `casual` | 亲切自然，适当口语化，拉近距离 |
| `humorous` | 加入巧妙比喻，轻松表达，保持信息量 |
| `academic` | 规范引用，严格论证，学术用语 |

| Audience | Adaptation |
|----------|-----------|
| `general` | 通俗易懂，避免术语堆砌 |
| `industry` | 行业术语，深度分析 |
| `students` | 教学口吻，知识点标注 |
| `tech-community` | 代码示例，技术深度 |

**处理方式**: Claude 直接根据角色定义调整文章内容，不询问用户确认。修改后的内容用于后续步骤。

### Step 3: Auto De-AI Processing

**强制执行**: 每次发布自动执行去AI味处理，不询问用户。

1. 扫描 24 种 AI 痕迹模式（见下方 AI Trace Removal 章节）
2. 使用 `medium` 强度级别处理
3. 根据 `writing_style` 调整处理策略：
   - `professional`: 保留专业表述，去除AI套话
   - `casual`: 更口语化替换
   - `humorous`: 保留生动表达，去除模板化语言
   - `academic`: 保留学术用语，去除AI填充词
4. 5 维度评分
5. 输出简要修改报告（修改数量 + 评分）

### Step 4: Auto Theme & Color Selection

**自动选择**: Claude 根据文章内容智能匹配主题和配色，不询问用户。

**匹配规则**:

| 文章类型 | 推荐主题 | 推荐配色 |
|---------|---------|---------|
| 技术/编程 | `default` | `blue` |
| 生活/情感 | `grace` | `purple` 或 `rose` |
| 教程/教学 | `simple` | `green` |
| 商业/分析 | `modern` | `orange` 或 `black` |
| 设计/创意 | `grace` | `vermilion` 或 `pink` |
| 科普/知识 | `default` | `sky` 或 `green` |

Claude 分析文章内容，综合考虑：
- 文章主题和领域
- `creator_role` 偏好
- 内容的情感基调
- 目标受众特征

选定后在完成报告中说明选择理由。

**Theme options**: default, grace, simple, modern

**Color presets**: blue, green, vermilion, yellow, purple, sky, rose, olive, black, gray, pink, red, orange (or hex value)

### Step 5: Auto Image Generation

**自动执行**: Claude 分析文章内容，自动选择图片风格，生成封面图和插图。

**流程**:

1. **选择风格**: 根据文章内容和 `creator_role` 自动匹配图片风格（见下方 6 种预设）
2. **封面图**: 根据文章标题和主题，使用选定风格的提示词模板生成封面
3. **插图**: 分析文章结构，在适当位置插入 AI 生成图片（如有需要）
4. 在 Markdown 中插入: `![描述](__generate:提示词__)`
5. 发布时 `wechat-api.ts` 自动调用图片生成 API 并上传

#### 6 种图片风格预设

| 风格 ID | 名称 | 适用场景 | 色彩方案 |
|---------|------|---------|---------|
| `vector` | 扁平矢量 | 技术文章、教程、知识科普 | Cream 底(#F5F0E6), Coral(#E07A5F), Mint(#81B29A), Mustard(#F2CC8F), Blue(#577590) |
| `watercolor` | 水彩手绘 | 生活方式、旅行、情感散文 | Earth 色系, 柔和边缘, 自然暖调 |
| `minimal` | 极简留白 | 观点文章、深度思考、哲理 | Mono 黑白(#000000, #374151), 白底(#FFFFFF), 60%+ 留白 |
| `warm` | 温暖手绘 | 个人故事、成长经历、生活感悟 | Cream 底(#FFFAF0), Warm Orange(#ED8936), Golden(#F6AD55), Terracotta(#C05621) |
| `blueprint` | 技术蓝图 | API 文档、系统设计、技术深度 | Off-White 底(#FAF8F5), Engineering Blue(#2563EB), Navy, Amber |
| `notion` | 极简线条 | 产品指南、工具教程、SaaS 介绍 | White/Off-White 底, 黑色文字(#1A1A1A), 淡蓝/淡黄/淡粉点缀 |

#### 风格自动匹配规则

| 文章内容信号 | 推荐风格 |
|-------------|---------|
| API、代码、系统架构、技术原理 | `blueprint` |
| 编程教程、操作指南、知识科普 | `vector` |
| 产品介绍、工具评测、SaaS | `notion` |
| 个人故事、成长、情感 | `warm` |
| 旅行、美食、生活方式 | `watercolor` |
| 观点评论、深度分析、哲理思考 | `minimal` |
| 商业分析、行业报告 | `vector` 或 `blueprint` |

#### 提示词模板

**通用结构** — 所有提示词必须包含以下要素：

```
[风格描述]. [主题内容]. [构图要求]. [色彩方案]. Clean composition with generous white space. Simple or no background. Human figures: simplified stylized silhouettes, not photorealistic.
```

**`vector` 风格模板**:

```
Flat vector illustration. Clean black outlines on all elements. [主题描述]. Geometric simplified icons, no gradients. Colors: Cream background (#F5F0E6), Coral Red (#E07A5F), Mint Green (#81B29A), Mustard Yellow (#F2CC8F). Centered composition with white space.
```

**`watercolor` 风格模板**:

```
Soft watercolor illustration with natural warmth. [主题描述]. Gentle brush strokes, soft edges, organic flow. Earthy warm tones with muted greens and browns. Light paper texture background. Dreamy atmospheric quality.
```

**`minimal` 风格模板**:

```
Ultra-minimalist illustration. [主题描述]. Single focal element centered, 60%+ white space. Black and dark gray (#374151) on pure white background. Clean geometric shapes, no decoration. Zen-like simplicity.
```

**`warm` 风格模板**:

```
Warm hand-drawn illustration with friendly feel. [主题描述]. Sketchy organic strokes, variable line weights. Colors: Cream background (#FFFAF0), Warm Orange (#ED8936), Golden Yellow (#F6AD55), Terracotta (#C05621). Cozy inviting atmosphere.
```

**`blueprint` 风格模板**:

```
Technical blueprint-style diagram. [主题描述]. Precise lines, grid overlay, 90-degree angles. Colors: Off-White background (#FAF8F5), Engineering Blue (#2563EB), Navy Blue, Light Blue accents, Amber highlights. Schematic aesthetic.
```

**`notion` 风格模板**:

```
Minimalist hand-drawn line art in Notion style. [主题描述]. Simple black outlines (#1A1A1A) on white background. Pastel blue, yellow, pink accents only. Clean layout, generous spacing, doodle aesthetic.
```

**IMAGE_API_KEY 未配置时**: 跳过图片生成，输出警告，继续发布流程。

**API 配置**: 固定使用 `https://api.tu-zi.com/v1`，模型 `gpt-image-1`，只需配置 `IMAGE_API_KEY`。

### Step 6: Validate Metadata + Publish

1. **Validate metadata** from frontmatter (markdown) or HTML meta tags:

| Field | If Missing |
|-------|------------|
| Title | Prompt: "Enter title, or press Enter to auto-generate from content" |
| Summary | Auto-generate: first paragraph, truncated to 120 characters |
| Author | Use fallback chain: CLI `--author` → frontmatter `author` → EXTEND.md `default_author` |

**Auto-Generation Logic**:
- **Title**: First H1/H2 heading, or first sentence
- **Summary**: First paragraph, truncated to 120 characters

2. **Cover Image Check** (required for API `article_type=news`):
   1. Use CLI `--cover` if provided.
   2. Else use frontmatter (`coverImage`, `featureImage`, `cover`, `image`).
   3. Else use Step 5 generated cover image.
   4. Else check article directory default path: `imgs/cover.png`.
   5. Else fallback to first inline content image.
   6. If still missing, stop and request a cover image before publishing.

3. **Publish**:

**CRITICAL**: Publishing scripts handle markdown conversion internally. Do NOT pre-convert markdown to HTML — pass the original markdown file directly.

```bash
npx -y bun ${SKILL_DIR}/scripts/wechat-api.ts <file> --theme <theme> [--color <color>] [--title <title>] [--summary <summary>] [--author <author>] [--cover <cover_path>]
```

**CRITICAL**: Always include `--theme` parameter. Never omit it, even if using `default`. Only include `--color` if explicitly set.

**`draft/add` payload rules**:
- Use endpoint: `POST https://api.weixin.qq.com/cgi-bin/draft/add?access_token=ACCESS_TOKEN`
- `article_type`: `news` (default) or `newspic`
- For `news`, include `thumb_media_id` (cover is required)
- Always resolve and send:
  - `need_open_comment` (default `1`)
  - `only_fans_can_comment` (default `0`)
- `author` resolution: CLI `--author` → frontmatter `author` → EXTEND.md `default_author`

### Step 7: Completion Report

```
WeChat Publishing Complete!

Input: [type] - [path]

Role Adaptation:
• Creator: [creator_role]
• Style: [writing_style]
• Audience: [target_audience]

De-AI Processing:
• Changes: [N] modifications
• Score: [score]/50 ([rating])

Theme: [theme name] + [color]
• Reason: [why this theme/color was chosen]

Article:
• Title: [title]
• Summary: [summary]
• Cover: [generated/provided/fallback]
• Images: [N] AI-generated + [N] inline images
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

发布流程中自动为文章生成封面和插图。Claude 分析文章内容，从 6 种预设风格中自动匹配，使用对应提示词模板生成图片。

详见 Step 5 中的**6 种图片风格预设**、**风格自动匹配规则**和**提示词模板**。

### Syntax

```
![图片描述](__generate:英文提示词__)
```

- `__generate:` — 固定前缀，标识 AI 生成图片
- 提示词必须用英文，使用 Step 5 中的风格模板构建
- 必须包含：风格描述、主题内容、构图要求、色彩方案

### Image API Configuration

固定使用 `https://api.tu-zi.com/v1`，模型 `gpt-image-1`。

```
IMAGE_API_KEY=sk-xxx    # 必填：API 密钥（配置在 .baoyu-skills/.env）
```

配置位置与微信凭证相同（环境变量 > `.baoyu-skills/.env` > `~/.baoyu-skills/.env`）

### Processing Pipeline

```
Claude 分析文章 → 创建提示词 → 插入 Markdown
  ↓
Markdown: ![alt](__generate:prompt__)
  ↓ 渲染
HTML: <img src="__generate:prompt__" alt="alt">
  ↓ wechat-api.ts 检测 __generate: 前缀
调用 api.tu-zi.com (gpt-image-1) → 获取图片
  ↓
上传微信素材库 → 获取 CDN URL → 替换 src
```

**错误处理**: IMAGE_API_KEY 未配置时跳过生成并输出警告；API 失败时跳过该图片继续处理。

---

## AI Trace Removal (去AI味 / Humanizer)

### Overview

每次发布自动执行。Humanizer 检测并去除文章中的 AI 写作痕迹，强制集成在发布流程 Step 3 中。

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
| Themes (auto-selected) | ✓ |
| Auto-generate metadata | ✓ |
| Default cover fallback (`imgs/cover.png`) | ✓ |
| Comment control (`need_open_comment`, `only_fans_can_comment`) | ✓ |
| Role-based content adaptation (角色适配) | ✓ |
| AI trace removal - auto (去AI味) | ✓ |
| AI image generation - auto (自动配图) | ✓ |
| Smart theme & color selection (智能排版) | ✓ |

## Prerequisites

- WeChat Official Account API credentials
- `IMAGE_API_KEY` for AI image generation (optional but recommended)
- Guided setup in Step 0, or manually set in `.baoyu-skills/.env`

**Config File Locations** (priority order):
1. Environment variables
2. `<cwd>/.baoyu-skills/.env`
3. `~/.baoyu-skills/.env`

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Missing API credentials | Follow guided setup in Step 0 |
| Access token error | Check if API credentials are valid and not expired |
| Title/summary missing | Use auto-generation or provide manually |
| No cover image | Auto-generated in Step 5, or add frontmatter cover or place `imgs/cover.png` in article directory |
| Wrong comment defaults | Check `EXTEND.md` keys `need_open_comment` and `only_fans_can_comment` |
| Image generation skipped | Check `IMAGE_API_KEY` in `.baoyu-skills/.env` |

## Extension Support

Custom configurations via EXTEND.md. See **Preferences** section for paths and supported options.
