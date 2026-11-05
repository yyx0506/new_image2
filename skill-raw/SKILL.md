---
name: "nana_image2_raw"
description: "Generate images through the current Codex provider with the user's prompt EXACTLY as written - no rewriting, no beautification, nothing added. Use when the user asks for 原样/逐字/不要改提示词/别美化/verbatim/as-is, or explicitly names this skill."
---

# nana_image2 raw mode

One hard rule: **`--prompt` receives the user's words byte-for-byte.** Trim surrounding whitespace only. Keep their language (Chinese stays Chinese). Do not translate, expand, "improve", or restructure. If you feel the prompt is weak, say so in your reply - do NOT fix it silently.

This skill reuses the sibling nana_image2 installation (same installer, same CLI):

- macOS / Linux: `"$HOME/.codex/skills/nana_image2/scripts/run"`
- Windows: `"%USERPROFILE%\.codex\skills\nana_image2\scripts\run.cmd"`

If that launcher is missing, tell the user to re-install the nana_image2 package (both skills ship together).

## Workflow

1. (Optional, free) connectivity check with the selected model:
   `"$HOME/.codex/skills/nana_image2/scripts/run" doctor --model gpt-image-2.5-sunburst`
2. Generate or edit exactly once, passing the user's text verbatim:

```bash
"$HOME/.codex/skills/nana_image2/scripts/run" generate \
  --model gpt-image-2.5-sunburst \
  --prompt "<the user's exact words>" \
  --out /absolute/path/output.png
```

3. Read the last JSON line of the output: `"degraded": true` means the upstream downgraded size/model - report the ACTUAL output. A `"fallback"` line means the requested model was unavailable and the CLI switched once - report which model actually produced the image.
4. Report: raw mode was used, the prompt (unchanged), the model, the absolute saved path. Show the saved image.

## Model routing

- Default: `gpt-image-2.5-sunburst`. An explicitly requested model (Flare / Sunburst / full ID / anything the provider lists) is preserved; the CLI's loud fallback rules apply unchanged.
- `edit` works the same with `--image input.png`; `--prompt` is still the user's exact words describing the change.
- PSD helpers (psd-layers / psd-export / psd-compose) are available through the same launcher when the user mentions layered files.
