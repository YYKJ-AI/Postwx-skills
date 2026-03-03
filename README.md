# Postwx

一键将 Markdown 文章发布到微信公众号草稿箱的命令行工具。

[![TypeScript](https://img.shields.io/badge/TypeScript-5-3178C6?style=flat-square&logo=typescript)](https://typescriptlang.org/)
[![Bun](https://img.shields.io/badge/Bun-Runtime-f9f1e1?style=flat-square&logo=bun)](https://bun.sh/)

## 功能

- 支持 Markdown / HTML / 纯文本输入
- 4 种排版主题（default、grace、simple、modern）+ 13 种配色
- 自动上传本地/远程图片到微信素材库
- 自动提取标题、摘要、封面图
- 支持 `--dry-run` 预览模式
- 零浏览器依赖，纯 API 调用

## 快速开始

### 1. 配置微信公众号凭证

前往 [微信公众平台](https://mp.weixin.qq.com) → 开发 → 基本配置，获取 AppID 和 AppSecret。

创建配置文件：

```bash
mkdir -p ~/.baoyu-skills
cat > ~/.baoyu-skills/.env << 'EOF'
WECHAT_APP_ID=你的AppID
WECHAT_APP_SECRET=你的AppSecret
EOF
```

### 2. 发布文章

```bash
# 基础用法
npx -y bun scripts/wechat-api.ts article.md

# 指定主题和配色
npx -y bun scripts/wechat-api.ts article.md --theme grace --color blue

# 自定义元数据
npx -y bun scripts/wechat-api.ts article.md --author "作者名" --cover cover.png

# 预览模式（不实际发布）
npx -y bun scripts/wechat-api.ts article.md --dry-run
```

### 3. Markdown frontmatter 示例

```markdown
---
title: 文章标题
author: 作者名
summary: 文章摘要
coverImage: imgs/cover.png
---

正文内容...
```

## License

MIT
