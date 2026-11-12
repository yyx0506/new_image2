---
name: "image-chahua"
description: "插画扁平风格画图：插画/扁平/矢量 风格出图。提示词按本风格规则优化，主体与意图严格来自用户原话。用户点名本风格或本技能时使用；报告注明所用风格与最终提示词。"
---

# 插画扁平风格画图（$image-chahua）

复用主技能 CLI（同一安装包）：

- macOS / Linux: `"$HOME/.codex/skills/new_image2/scripts/run"`
- Windows: `"%USERPROFILE%\.codex\skills\new_image2\scripts\run.cmd"`

## 出图规则

- 基础五条（所有风格通用）：**光**（单一散射光源）/ **瑕**（每物一缺陷）/ **机**（相机锚点）/ **灰**（克制曝光）/ **粒**（颗粒感）
- 本风格专属：关闭相机锚点（不写相机/胶片）、4-6 色限色、手绘线条不闭合、大量留白
- 硬护栏：只重组结构与补物理细节，主体/风格/构图意图必须来自用户原话

## 用法

```bash
RUN generate --model gpt-image-2.5-sunburst --quality high --prompt "<按本风格规则组织的提示词>" --out 输出.png
```

出图后报告：所用风格、用户原话、最终提示词、保存路径；`degraded`/`fallback`/`corrected` JSON 行照主技能规则如实转述。
