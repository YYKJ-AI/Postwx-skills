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
IMAGE_API_KEY=你的图片API密钥
EOF
```

> `IMAGE_API_KEY` 用于 AI 自动配图（使用 api.tu-zi.com），不配置则跳过配图。

### 2. 安装技能

将本项目的 `SKILL.md` 添加到 Claude Code 的 skills 配置中。

### 3. 开始使用

```bash
claude
```

然后只需一句话：

```
> 把 article.md 发到公众号
```

Claude 会自动完成全部流程：角色适配 → 去AI味 → 选主题配色 → 生成配图 → 发布。

## 核心能力

- **一句话发布** — 告诉 Claude "发到公众号"，自动完成全流程
- **角色定义** — 根据创作者角色、写作风格、目标受众自动适配内容
- **自动去AI味** — 24 种 AI 痕迹检测，每次发布自动执行
- **智能排版** — 根据文章内容自动选择最佳主题和配色
- **自动配图** — AI 分析文章内容，自动生成封面和插图
- **多格式输入** — Markdown / HTML / 纯文本

## License

MIT
