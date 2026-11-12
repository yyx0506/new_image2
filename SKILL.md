---
name: "new_image2"
description: "智能画图（默认）：AI 优化提示词后通过当前 Codex provider 生成/编辑图片，内置八大风格方向，适合绝大多数出图需求。Generate or edit raster images with AI-beautified prompts through the current Codex custom provider; use for image assets, not for SVG/HTML/code-native visuals."
---

# Sub2API Image Generation

Use the bundled dependency-free client instead of the system `imagegen` CLI. It reads the active provider's `base_url`, `experimental_bearer_token`, and `http_headers` from Codex config, falling back to the adjacent `auth.json` top-level `OPENAI_API_KEY` when no environment/config key is set, then sends a non-SDK User-Agent to avoid the known sub2api/Cloudflare SDK-header block.

## Workflow

1. Select the model using the prompt-routing rules below, then resolve `<skill-dir>` as the directory containing this `SKILL.md`. Run the no-cost connectivity check:

   ```bash
   "<skill-dir>/scripts/run" doctor --model <selected-model>   # Windows: "<skill-dir>\scripts\run.cmd" doctor --model <selected-model>
   ```

   Commands go through the bundled launcher (`scripts/run`, Windows `scripts\run.cmd`): it uses a system Python 3.9+ when present and otherwise the private runtime installed with the skill - no Python installation is required on the user's machine, and the launcher runs the interpreter with `-E -s` so developer environments (conda/pyenv) are never touched. On Python 3.9/3.10 the config parser falls back to a minimal TOML-subset reader; anything richer fails with a clear message.

2. Beautify the user's request into a concise photographic prompt (see "Prompt handling"); verbatim requests belong to the sibling $new_image2_raw skill.
3. Generate or edit exactly once, explicitly passing the same `--model <selected-model>` used for doctor. A user request to create/edit an image authorizes that call; diagnostics alone do not authorize a billed smoke test.
4. Read the output carefully. When an explicit size was requested, the client prints a final JSON verdict line: if it says `"degraded": true`, the upstream accepted the request but returned a different size/model (known sub2api silent downgrade, issues #6120/#3302/#7119) — report the ACTUAL size to the user along with the verdict's advice instead of claiming success. Inspect the saved image with `view_image`. Retry only for a specific defect the user asked to fix.
5. Report the model, the user's original words, the final prompt actually sent, and the absolute saved path. For project assets, save under the project's `output/imagegen/` or the user-named path.

Streaming rules (important, both are workaround-driven):

- `generate` streams automatically for slow jobs (quality high/xhigh/max, or explicit size ≥2MP such as 4K): slow generations can outrun the proxy's ~100s origin timeout (Cloudflare 524) unless bytes flow early. `--stream on|off` forces it; `--save-partials` keeps intermediate images from the stream.
- `edit` NEVER streams. sub2api issue #8027: edits+stream returns 502 and the failover drains the whole account pool. This client sends no stream flag on the edits path — do not work around that by hand.

## Prompt handling (this skill = beautify)

This skill beautifies: expand the user's idea into a full photographic prompt using the five rules that fight the "AI look": (1) 光 one single light source, soft and scattered; (2) 瑕 give every object one imperfection - rust, cracks, folds, wilt; (3) 机 camera anchors (35mm, f/4, handheld, a named film stock); (4) 灰 "overall muted, highlights not blown, shadow detail retained" beats mood adjectives; (5) 粒 film grain/noise as a realism signal. HARD GUARDRAIL: beautify may restructure and add physical detail, but the subject, style and composition intent must come from the user's own words - never swap or "improve" what they asked for.

When the user wants their prompt passed through EXACTLY as written (原样 / 逐字 / verbatim / as-is), that is the sibling skill's job: switch to `$new_image2_raw` instead of changing modes here.

## Style directions (风格方向)

Dedicated sibling skills exist for direct selection (each with a Chinese description): $image-jishi 纪实摄影 / $image-dianying 电影感 / $image-chanpin 商业产品 / $image-renxiang 人像写真 / $image-chahua 插画扁平 / $image-3d 3D 渲染 / $image-shuimo 国风水墨 / $image-fugu 复古胶片. When the user names one of those skills, it handles everything; when they only describe content, THIS skill infers the direction itself using the table below.

Beautify picks ONE direction - the user's explicit choice wins; otherwise infer from the content; default to 写实纪实. Apply the direction's rules on top of the five base rules (光/瑕/机/灰/粒), and state which direction was used in the report.

| # | Direction / 触发词 | Key rules beyond the base five |
|---|---|---|
| 1 | **写实纪实**（纪实/抓拍/documentary，默认） | 五条基础规则全套；35mm f/4 手持；自然光；不加戏剧化 |
| 2 | **电影感**（电影/cinematic/剧照） | 宽画幅构图；一个主光+轮廓光；青橙/低饱和调色；浅景深；体积光雾 |
| 3 | **商业产品**（产品/电商/product shot） | 无缝背景/纯色背景；柔光箱+反光板（金属高光有渐变）；100mm 微距；产品居中或三分；可加轻微倒影 |
| 4 | **人像写真**（人像/肖像/portrait） | 85mm f/1.8；眼神光（catchlight）；保留皮肤纹理（雀斑/毛孔，禁磨皮）；背景分离虚化；自然姿态 |
| 5 | **插画扁平**（插画/扁平/vector） | 关闭摄影锚点（不写相机/胶片）；有限配色 4-6 色；几何化的瑕疵感（手绘线条不闭合）；留白构图 |
| 6 | **3D 渲染**（3D/渲染/C4D/render） | 材质描述（哑光/磨砂/次表面散射）；三点布光+软阴影；微噪点抗塑料感；octane 风格但不写引擎名 |
| 7 | **国风水墨**（水墨/国画/工笔） | 大量留白；笔触干湿浓淡；墨分五色的灰阶；一枚朱印位置；生宣质感（边缘洇墨） |
| 8 | **老照片胶片**（老照片/怀旧/复古/vintage） | 指定胶片型号（Kodak Gold 200 / Fuji Superia）；褪色偏色（黄青漂）；更强颗粒；白边划痕可选 |

Rules that apply to ALL directions: the subject/composition intent stays the user's own words; one light logic; every object keeps one imperfection; report the chosen direction with the final prompt.

## Transport modes

- Default (`--via images`): the Images API endpoints. Best general compatibility.
- `--via tool`: the request goes to `/v1/responses` with model/size/quality/output_format placed INSIDE the image tool config - the route upstream historically honours explicit parameters (same shape as codex-image-4k). Use it when the user needs exact dimensions or reports size drift on the default transport; n=1 only; a text driver model is auto-picked (override with --driver-model). If the returned image still misses the requested size, the client corrects it locally (bilinear resize) and prints a `corrected` note - report the correction.

## Safety blocks

A `moderation_blocked` response (structured JSON + an `.error.json` sidecar next to the output path) means the provider's safety filter rejected the prompt. Tell the user plainly which prompt was flagged and suggest rephrasing. Never retry automatically, never attempt to evade the filter - that is upstream policy.

## Prompt routing

- An explicit Flare, Sunburst, full model ID, or dated snapshot requested by the user takes precedence over inferred intent. Map Flare to `gpt-image-2.5-flare` and Sunburst to `gpt-image-2.5-sunburst`; preserve explicitly requested full IDs/snapshots.
- Without an explicit model, use Flare for speed, drafts, or everyday generation requests; use Sunburst for precise editing, preserving subject/text details, or when no preference is given. If both speed and detail are requested without a model, prefer Sunburst for preservation-critical edits.
- Both models support generation and editing. Choose `generate` versus `edit` from whether the user wants a new image or an edit/reference workflow, not from the model name. Never send a reference image when the user requests text-only generation.
- Pass the selected full ID via `--model` to both doctor and generate/edit. Merely mentioning a model in `--prompt` does not route the Python client.
- Model availability fallback (never silent): a user-picked model that the provider does not list - or rejects with a model-not-found error - is retried ONCE with the default sibling (sunburst <-> flare, or `--fallback MODEL`), and the client prints a `{"fallback": {...}}` JSON note. When you see it, tell the user which model actually produced the image. `--no-fallback` restores strict fail-fast for both commands.

Generate:

```bash
"<skill-dir>/scripts/run" generate \
  --model gpt-image-2.5-flare \
  --prompt "A ceramic coffee mug in soft studio light; no logo, text, or watermark" \
  --quality medium \
  --out output/imagegen/mug.png
```

Edit:

```bash
"<skill-dir>/scripts/run" edit \
  --model gpt-image-2.5-sunburst \
  --image input.png \
  --prompt "Replace only the background with a warm sunset; keep the product and edges unchanged" \
  --out output/imagegen/sunset-edit.png
```

Use `--dry-run` to inspect a redacted request without network or cost. Use `--provider NAME` or `--config PATH` only when the active Codex provider is not the intended route. `OPENAI_BASE_URL` and `OPENAI_API_KEY` override config values when set.

The config path is `--config`, then `$CODEX_HOME/config.toml`, then `~/.codex/config.toml`. Key precedence is environment, provider token, then `auth.json` beside the selected config. Only the top-level `OPENAI_API_KEY` is read, never OAuth tokens. The endpoint must still come from environment/config; auth fallback never switches providers or defaults to an official endpoint. Ensure the key belongs to that endpoint.

## PSD layer workflow

When the user mentions a PSD file, layers (图层), or wants generated assets delivered as a layered file, use the offline PSD helpers first; they never touch the provider or credentials.

```bash
# 1. Inspect: list layers (name/index/bbox/visibility) — always start here
"<skill-dir>/scripts/run" psd-layers poster.psd

# 2. Extract one layer as PNG to feed generate/edit (or --all --outdir DIR)
"<skill-dir>/scripts/run" psd-export poster.psd --name 背景 --out output/bg.png

# 3. Generate/edit with the exported layer as the reference image (billed, same rules as above)
"<skill-dir>/scripts/run" edit --image output/bg.png \
  --model gpt-image-2.5-sunburst --prompt "..." --out output/bg-new.png

# 4. Compose a NEW layered PSD (bottom layer first); original file is never modified
"<skill-dir>/scripts/run" psd-compose \
  --layer "背景=output/bg-new.png" --layer "产品=output/product.png" --out output/poster-v2.psd
```

Rules and boundaries — state them plainly rather than working around them:

- Supported: 8-bit RGB PSDs, layer records and bitmap pixels, raw/RLE/ZIP/ZIP-with-prediction compression; writing new layered PSDs (RLE channels) that Photoshop, Photopea, Krita and Affinity open.
- Not supported (the command fails with a clear error, never silently): PSB, 16/32-bit depth, CMYK/grayscale modes, layer masks as separate exports, writing back into the existing PSD (`psd-compose` always produces a new file).
- Layers without pixel data (adjustment layers) are listed with `pixels: false` and skipped on export; text layers come out as their rendered bitmap only.
- All layer PNGs in `psd-compose` must share one canvas size; resize first or pick one canvas.
- For "分层出图" requests (background/subject/decoration as separate images), generate each image at the same size, then compose.

## Resolution

- Default model: `gpt-image-2.5-sunburst`, size `auto`. Choose `--model gpt-image-2.5-flare` for fast everyday generation; Sunburst prioritizes editing precision. Both support generation and editing, and dated `-2026-09-08` snapshots. All commands accept `--model`; no separate variant parameter is needed. The bare `gpt-image-2.5` is only a provider-specific alias, warns when explicitly used, and must never be reported as a verified official variant.
- Official 2.5 quality settings: `low`, `medium`, `high`, `xhigh`, `max`, `auto`. Client default remains `medium` (official default is `auto`). Both models have equal token rates, not necessarily equal per-image costs.
- Official 2.5 size constraints: multiples of 16, max edge 3840, aspect ratio 1:3 to 3:1, 655,360–8,294,400 pixels; above 2560x1440 is experimental. Transparent output supports PNG/WebP. Source: [Image generation guide](https://developers.openai.com/api/docs/guides/image-generation), checked 2026-09-27.
- Provider-returned bytes are authoritative. The client reports any requested/actual mismatch and never upscales, resamples, or pads locally.

## Boundaries

- Never print, persist, or ask the user to paste a token. Do not copy credentials into project files.
- Never auto-retry a paid request. Surface the API error and change only the demonstrated cause.
- Never claim requested dimensions are actual dimensions; report the decoded/API-reported output size.
- Do not overwrite an existing file unless the user requested replacement; otherwise choose a versioned filename. `--force` is explicit overwrite authorization.
- Both GPT Image 2.5 variants support transparent output. Keep the selected model and pass `--background transparent --output-format png` (or `webp`).
- Prefer the built-in `image_gen` tool when it is actually available and working. This skill exists for the custom-provider fallback path.
