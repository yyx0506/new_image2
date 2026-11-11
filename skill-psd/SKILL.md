---
name: "nana_image2_psd"
description: "Dedicated PSD toolbox: inspect, split (export layers), and compose layered Photoshop files, optionally piping layers through AI image generation. Use when the user mentions psd/PSD/图层/拆图层/分层/合成 PSD or wants generated assets delivered as a layered file."
---

# nana_image2_psd - PSD 拆解与合成工具箱

专职处理分层 PSD，全部离线、不碰凭证。复用 nana_image2 的启动器（同一安装包）：

- macOS / Linux: `"$HOME/.codex/skills/nana_image2/scripts/run"`
- Windows: `"%USERPROFILE%\.codex\skills\nana_image2\scripts\run.cmd"`

若启动器不存在，提示用户重装 nana_image2 安装包（技能同包发行）。

## 三个核心动作

**1. 拆解（先看再导）**——列层是即时的（不解码像素）：

```bash
RUN psd-layers 海报.psd                      # 名称/序号/位置/可见性/有无像素
RUN psd-export 海报.psd --all --outdir 拆解/  # 每层一张 PNG（序号_图层名）
RUN psd-export 海报.psd --name 背景 --out 背景.png   # 只导某一层（重名用 --index）
```

**2. 合成（新文件，原文件永不修改）**：

```bash
RUN psd-compose --layer "背景=背景新.png" --layer "产品=产品.png" --out 成品.psd
```

所有图层 PNG 必须同一画布尺寸（先统一尺寸再合成）；底层在前。

**3. 联动生图（付费环节走 nana_image2 的规则）**：

导出层 → `$nana_image2`（或 `$nana_image2_raw`）编辑该层 → psd-compose 装回新 PSD。
用户说"把某层换成 XX"时就是这个三步链路；出图那一步的降级检测/回退规则照旧。

## 边界（照实报告，不猜）

- 支持：8-bit RGB；raw/RLE/ZIP/ZIP+预测 压缩；写出 Photoshop/Photopea/Krita/Affinity 可开的分层 PSD
- 不支持（明确报错）：PSB、16/32 位深、CMYK；调整层/文字层只导出渲染位图；蒙版不单独导出；不写回原文件

## 性能提示

列层毫秒级；导出单层通常 <100ms；合成大画布（>3MP 且含半透明层）数秒（检测到 numpy 会自动加速）。超大文件（>200MB）先提示用户可能耗时，再执行。
