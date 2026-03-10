---
name: first-time-setup
description: First-time setup flow for Postwx preferences
---

# First-Time Setup

## Overview

When no EXTEND.md is found, guide user through preference setup.

**BLOCKING OPERATION**: This setup MUST complete before ANY other workflow steps. Do NOT:
- Ask about content or files to publish
- Ask about themes or publishing methods
- Proceed to content conversion or publishing

ONLY ask the questions in this setup flow, save EXTEND.md, then continue.

## Setup Flow

```
No EXTEND.md found
        |
        v
+---------------------+
| AskUserQuestion     |
| (all questions)     |
+---------------------+
        |
        v
+---------------------+
| Create EXTEND.md    |
+---------------------+
        |
        v
+---------------------+
| Check IMAGE_API_KEY |
+---------------------+
        |
        v
    Continue to Step 1
```

## Questions

**Language**: Use user's input language or saved language preference.

Use AskUserQuestion with ALL questions in ONE call:

### Question 1: Creator Role

```yaml
header: "Role"
question: "What type of content creator are you?"
options:
  - label: "Tech blogger (Recommended)"
    description: "科技博主 — 科技产品、编程、AI 等技术内容"
  - label: "Lifestyle writer"
    description: "生活作者 — 生活方式、旅行、美食等内容"
  - label: "Educator"
    description: "教育者 — 教程、知识科普、学习方法等内容"
  - label: "Business analyst"
    description: "商业分析 — 行业分析、商业评论、趋势洞察等内容"
```

### Question 2: Writing Style

```yaml
header: "Style"
question: "What writing style do you prefer?"
options:
  - label: "Professional (Recommended)"
    description: "专业严谨 — 清晰、准确、有深度"
  - label: "Casual"
    description: "轻松随和 — 亲切、易读、口语化"
  - label: "Humorous"
    description: "幽默风趣 — 有趣、生动、吸引眼球"
  - label: "Academic"
    description: "学术规范 — 引用、论证、严格逻辑"
```

### Question 3: Target Audience

```yaml
header: "Audience"
question: "Who is your target audience?"
options:
  - label: "General public (Recommended)"
    description: "大众读者 — 通俗易懂，面向所有人"
  - label: "Industry professionals"
    description: "行业人士 — 专业术语，面向从业者"
  - label: "Students"
    description: "学生群体 — 教学导向，循序渐进"
  - label: "Tech community"
    description: "技术社区 — 代码示例，面向开发者"
```

### Question 4: Default Author

```yaml
header: "Author"
question: "Default author name for articles?"
options:
  - label: "No default"
    description: "Leave empty, specify per article"
```

Note: User will likely choose "Other" to type their author name.

### Question 5: Open Comments

```yaml
header: "Comments"
question: "Enable comments on articles by default?"
options:
  - label: "Yes (Recommended)"
    description: "Allow readers to comment on articles"
  - label: "No"
    description: "Disable comments by default"
```

### Question 6: Fans-Only Comments

```yaml
header: "Fans only"
question: "Restrict comments to followers only?"
options:
  - label: "No (Recommended)"
    description: "All readers can comment"
  - label: "Yes"
    description: "Only followers can comment"
```

### Question 7: Save Location

```yaml
header: "Save"
question: "Where to save preferences?"
options:
  - label: "Project (Recommended)"
    description: ".baoyu-skills/ (this project only)"
  - label: "User"
    description: "~/.baoyu-skills/ (all projects)"
```

## Save Locations

| Choice | Path | Scope |
|--------|------|-------|
| Project | `.baoyu-skills/Postwx/EXTEND.md` | Current project |
| User | `~/.baoyu-skills/Postwx/EXTEND.md` | All projects |

## After Setup

1. Create directory if needed
2. Write EXTEND.md
3. Confirm: "Preferences saved to [path]"
4. **Check IMAGE_API_KEY**: Run `grep -q IMAGE_API_KEY` in `.baoyu-skills/.env` or `~/.baoyu-skills/.env`. If not configured, inform user:
   ```
   AI image generation requires IMAGE_API_KEY.
   Add to your .baoyu-skills/.env:
   IMAGE_API_KEY=sk-xxx
   ```
5. Continue to Step 0 (load the saved preferences)

## EXTEND.md Template

```md
creator_role: [tech-blogger/lifestyle-writer/educator/business-analyst]
writing_style: [professional/casual/humorous/academic]
target_audience: [general/industry/students/tech-community]
default_author: [author name or empty]
need_open_comment: [1/0]
only_fans_can_comment: [1/0]
```

## Modifying Preferences Later

Users can edit EXTEND.md directly or delete it to trigger setup again.
