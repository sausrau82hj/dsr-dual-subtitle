# DualSubtitle — Dark Souls: Remastered Chinese–English dual-language text · 中英双语文本

DARK SOULS: REMASTERED

中文 · [English](#Enlish)

---

## 中文

只改 NPC 对话（`Conversation_.fmg`）与过场动画字幕（`Movie_subtitles_.fmg`），中文在上、英文在下。菜单、道具、按键提示等其余文本保持原版。

两个语言槽（`ENGLISH`、`SCHINESE`）写的是同一份文本，游戏语言设成英文或中文都能用；繁中槽保持原版。

### 安装

先关游戏，装完离线启动。重制版本身就是散文件，不用解包：

- **替换文件**：把 `msg`、`font` 覆盖进 `DARK SOULS REMASTERED` 目录。
- **Mod Engine 2 / DSR Mod Engine**：把 `msg`、`font` 放进加载器的 `mod` 目录，用它自带的启动脚本进游戏。

只玩中文可以不放 `font`，`msg\SCHINESE` 单独就够。`font\ENGLISH` 是给英文语言槽补中文字形。

### 卸载

`msg` 换回 `source\msg`；覆盖过 `font` 的，Steam 校验文件完整性即可还原。

### 重新生成

需要 [Yabber](https://github.com/JKAnderson/Yabber/releases)，解压到包根目录即可。Windows 自带 PowerShell 就够，不用装 Python：

```
powershell -ExecutionPolicy Bypass -File tools\dualsub.ps1
```

不带参数就是重建本包：读包里的 `source\`，按 `tools\dualsub.config.json` 写回 `msg\` 和 `font\`。

参数只在需要时加：`-Source` / `-Out`、`-Game`、`-Yabber`、`-Filter "menu*"`、`-Config`、`-KeepWork`。

配置项：`languages`（写哪几个语言槽）、`chinese_source`（某个槽用哪份中文）、`separator`（单行文本的分隔符）、`categories`（`true` 合并 · `"off"` 原样 · `"sec_only"` 只留副语言）、`files`（按包、按 FMG 的例外）、`fit`（对话框放得下几行、多宽，放不下怎么排）、`font`（从游戏复制哪套字体）。

### 已知限制

- 只改文本；别的 mod 也换 `msg` 时，把它的文件放进 `source\` 再生成。
- 对话框只放得下 3 行。放不下的对话改成同行「中文 / English」，再放不下的（每语言 7 条）保留原文——中文槽是中文、英文槽是英文。行数与宽度在配置的 `fit` 里调。

### 致谢

[Yabber](https://github.com/JKAnderson/Yabber) 处理 DCX / BND3 / FMG；同系列：[DARK SOULS III 双语](https://github.com/sausrau82hj/darksoulsiii-dual-subtitle)。

---

## English

NPC dialogue (`Conversation_.fmg`) and cutscene subtitles (`Movie_subtitles_.fmg`) only, Chinese on top and English underneath. Menus, items and key prompts stay vanilla.

All two slots (`ENGLISH`, `SCHINESE`) hold the same text, so the pack works whether the game is set to English or Chinese; the Traditional Chinese slot stays vanilla.

### Install

Close the game first, start it offline afterwards. DSR ships unpacked, so there is no unpacker step:

- **Replace the files**: copy `msg` and `font` over the `DARK SOULS REMASTERED` folder.
- **Mod Engine 2 / DSR Mod Engine**: put `msg` and `font` into the loader's `mod` folder and start the game with its launch script.

Playing in Chinese only? Then `font` is optional — `msg\SCHINESE` alone is enough. `font\ENGLISH` only fills in the missing Chinese glyphs for the English slot.

### Uninstall

Put `source\msg` back; if you replaced `font`, verify the game files in Steam.

### Rebuild

Requires [Yabber](https://github.com/JKAnderson/Yabber/releases) extracted under the package root. Windows PowerShell is enough — no Python needed:

```
powershell -ExecutionPolicy Bypass -File tools\dualsub.ps1
```

No arguments rebuilds the package: it reads the bundled `source\` and writes `msg\` and `font\` with the shipped config.

Extra arguments only when needed: `-Source` / `-Out`, `-Game`, `-Yabber`, `-Filter "menu*"`, `-Config`, `-KeepWork`.

Config keys: `languages` (slots to write), `chinese_source` (which Chinese text a slot shows), `separator` (separator inside one line), `categories` (`true` merge · `"off"` untouched · `"sec_only"` secondary only), `files` (per-pack, per-FMG exceptions), `fit` (how many lines and how wide the dialogue box is, and what to do with what does not fit), `font` (which font pair to copy out of the game).

### Known limitations

- Text only. If another mod also replaces `msg`, put its files in `source\` and rebuild.
- The dialogue box holds three lines. Anything longer is put on one line, `中文 / English`; the seven per language that still do not fit keep the vanilla text — Chinese in the Chinese slot, English in the English slot. `fit` in the config sets the line count and width.

### Credits

[Yabber](https://github.com/JKAnderson/Yabber) for the DCX / BND3 / FMG work. Sibling project: [Dual Subtitle for DARK SOULS III](https://github.com/sausrau82hj/darksoulsiii-dual-subtitle).

---

## License / 许可证

MIT 只覆盖为这个项目写的脚本和 README（[LICENSE](LICENSE)）；`msg`、`source` 里的文本和 `font` 里的字体是修改过的 FromSoftware / Bandai Namco 内容，仅供离线单人使用。与原厂无关。

The MIT license in [LICENSE](LICENSE) covers only the scripts and README written for this project. The text under `msg` and `source`, and the font under `font`, are modified FromSoftware / Bandai Namco content for offline single-player use. Not affiliated with FromSoftware or Bandai Namco.
