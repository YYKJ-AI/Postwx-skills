# Postwx

一个 Claude Code 技能（Skill），通过对话自动将文章发布到微信公众号草稿箱。

[![TypeScript](https://img.shields.io/badge/TypeScript-5-3178C6?style=flat-square&logo=typescript)](https://typescriptlang.org/)
[![Bun](https://img.shields.io/badge/Bun-Runtime-f9f1e1?style=flat-square&logo=bun)](https://bun.sh/)

## 核心能力

- **一句话发布** — 直接告诉 Claude "把这篇文章发到公众号"，自动完成全流程
- **多格式输入** — Markdown / HTML / 纯文本，自动识别处理
- **排版主题** — 4 种主题（default、grace、simple、modern）+ 13 种配色
- **AI 配图** — 在 Markdown 中用 `![描述](__generate:提示词__)` 自动生成并上传图片
- **去 AI 味** — 24 种 AI 痕迹检测，一键让文章更自然
- **零浏览器依赖** — 纯微信 API 调用，图片自动上传素材库

## 安装

将本项目作为 Claude Code Skill 使用：

```bash
# 将 SKILL.md 添加到 Claude Code 的 skills 配置中
# 详见 Claude Code 文档：https://docs.anthropic.com/en/docs/claude-code
```

## 配置

### 微信公众号凭证

前往 [微信公众平台](https://mp.weixin.qq.com) → 开发 → 基本配置，获取 AppID 和 AppSecret。

```bash
mkdir -p ~/.baoyu-skills
cat > ~/.baoyu-skills/.env << 'EOF'
WECHAT_APP_ID=你的AppID
WECHAT_APP_SECRET=你的AppSecret
EOF
```

### AI 配图（可选）

```bash
# 追加到 ~/.baoyu-skills/.env
IMAGE_API_KEY=sk-xxx
IMAGE_API_BASE=https://api.openai.com/v1  # 可选
IMAGE_MODEL=dall-e-3                       # 可选
```

## 使用方式

安装技能后，直接与 Claude 对话即可：

```
> 把 article.md 发到公众号

> 帮我用 grace 主题、蓝色配色发布这篇文章

> 发布前先去一下 AI 味

> 帮我在文章开头配一张科技风格的图
```

首次使用时 Claude 会引导你完成凭证配置和偏好设置。

### 也可直接命令行调用

```bash
npx -y bun scripts/wechat-api.ts article.md --theme grace --color blue
npx -y bun scripts/wechat-api.ts article.md --dry-run  # 预览模式
```

## 偏好配置

创建 `~/.baoyu-skills/baoyu-post-to-wechat/EXTEND.md` 设置默认值：

```md
default_theme: default
default_color: blue
default_author: 你的名字
need_open_comment: 1
only_fans_can_comment: 0
```

## License

MIT
