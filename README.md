# Postwx

一个 Claude Code 技能（Skill），通过对话自动将文章发布到微信公众号草稿箱。

## 什么是 Claude Code

[Claude Code](https://docs.anthropic.com/en/docs/claude-code) 是 Anthropic 官方的命令行工具，让你在终端中直接与 Claude 对话完成编程和自动化任务。

### 安装

```bash
npm install -g @anthropic-ai/claude-code
```

### 基本使用

```bash
# 在任意项目目录下启动
claude

# 然后直接用自然语言对话
> 帮我修复这个 bug
> 把这个函数重构一下
> 写一个单元测试
```

### 常用命令

| 命令 | 说明 |
|------|------|
| `claude` | 启动交互式对话 |
| `claude "你的问题"` | 单次提问 |
| `claude -c` | 继续上次对话 |
| `/help` | 查看帮助 |
| `/clear` | 清空对话 |
| `Ctrl+C` | 中断当前操作 |
| `Ctrl+D` | 退出 |

### 什么是 Skill

Skill 是 Claude Code 的技能扩展，通过一个 `SKILL.md` 文件定义 Claude 的专属能力。本项目就是一个 Skill，让 Claude 学会"发布微信公众号文章"。

## 使用本项目

### 1. 配置微信凭证

前往 [微信公众平台](https://mp.weixin.qq.com) → 开发 → 基本配置，获取 AppID 和 AppSecret。

```bash
mkdir -p ~/.baoyu-skills
cat > ~/.baoyu-skills/.env << 'EOF'
WECHAT_APP_ID=你的AppID
WECHAT_APP_SECRET=你的AppSecret
EOF
```

### 2. 安装技能

将本项目的 `SKILL.md` 添加到 Claude Code 的 skills 配置中。

### 3. 开始使用

```bash
claude
```

然后直接对话：

```
> 把 article.md 发到公众号
> 帮我用 grace 主题发布这篇文章
> 发布前先去一下 AI 味
> 帮我在文章开头配一张科技风格的图
```

## 核心能力

- **一句话发布** — 告诉 Claude "把这篇文章发到公众号"，自动完成全流程
- **多格式输入** — Markdown / HTML / 纯文本
- **排版主题** — 4 种主题 + 13 种配色
- **AI 配图** — 用 `![描述](__generate:提示词__)` 自动生成图片
- **去 AI 味** — 24 种 AI 痕迹检测，让文章更自然

## License

MIT
