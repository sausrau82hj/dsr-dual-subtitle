# DualSubtitle — Dark Souls: Remastered Chinese–English dual-language text · 中英双语文本

DARK SOULS: REMASTERED

中文 · English

---

## 中文

中文在上、英文在下，写进同一句对话里。只改文本，不动别的。

两个版本：

- **less** — NPC 对话（`Conversation_.fmg`）与过场字幕（`Movie_subtitles_.fmg`）。
- **all** — 再加上事件提示、菜单、按键提示、帮助文本、系统提示、血书。

三个语言槽（`ENGLISH`、`SCHINESE`、`TCHINESE`）写的是同一份文本，游戏语言设成英文或中文都能用。

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

不带参数就是 less 版：读包里的 `source\`，成品写回包里的 `msg\`。all 版换一份配置：

```
powershell -ExecutionPolicy Bypass -File tools\dualsub.ps1 -Config tools\dualsub-all.config.json -Out _work\all
```

参数只在需要时加：`-Source` / `-Out`、`-Game`、`-Yabber`、`-Filter "menu*"`、`-Config`、`-KeepWork`。自检用 `powershell -ExecutionPolicy Bypass -File tools\verify.ps1`（all 版加 `-Config tools\dualsub-all.config.json -PackDir _work\all`）。

配置项：`languages`（写哪几个语言槽）、`chinese_source`（某个槽用哪份中文）、`separator`（单行文本的分隔符）、`categories`（`true` 合并 · `"off"` 原样 · `"sec_only"` 只留副语言）、`files`（按包、按 FMG 的例外）、`font`（从游戏复制哪套字体）。

### 已知限制

- 只改文本；别的 mod 也换 `msg` 时，把它的文件放进 `source\` 再生成。
- all 版的菜单、按键提示是单行双语，个别按钮会偏挤。
- 英文较长的对话会占三四行，个别顶到对话框下沿。

### 更精细的修改

[WitchyBND](https://github.com/ividyon/WitchyBND/releases)：解包、修改、打包、替换。

### 致谢

[Yabber](https://github.com/JKAnderson/Yabber) 处理 DCX / BND3 / FMG；同系列：[DARK SOULS III 双语](https://github.com/sausrau82hj/darksoulsiii-dual-subtitle)。

---

## English

Chinese on top, English underneath, inside the same dialogue entry. Text only.

Two builds:

- **less** — NPC dialogue (`Conversation_.fmg`) and cutscene subtitles (`Movie_subtitles_.fmg`).
- **all** — the above plus event text, menus, key prompts, help text, system messages, blood messages.

All three slots (`ENGLISH`, `SCHINESE`, `TCHINESE`) hold the same text, so the pack works whether the game is set to English or Chinese.

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

No arguments builds the less pack from the bundled `source\` into the package's `msg\`. For the all build, use the other config:

```
powershell -ExecutionPolicy Bypass -File tools\dualsub.ps1 -Config tools\dualsub-all.config.json -Out _work\all
```

Extra arguments only when needed: `-Source` / `-Out`, `-Game`, `-Yabber`, `-Filter "menu*"`, `-Config`, `-KeepWork`. Check any build with `powershell -ExecutionPolicy Bypass -File tools\verify.ps1` (all build: add `-Config tools\dualsub-all.config.json -PackDir _work\all`).

Config keys: `languages` (slots to write), `chinese_source` (which Chinese text a slot shows), `separator` (separator inside one line), `categories` (`true` merge · `"off"` untouched · `"sec_only"` secondary only), `files` (per-pack, per-FMG exceptions), `font` (which font pair to copy out of the game).

### Known limitations

- Text only. If another mod also replaces `msg`, put its files in `source\` and rebuild.
- In the all build, menus and key prompts are bilingual on one line, so a few buttons get tight.
- A long English line can take a dialogue entry to three or four lines, and a few sit against the bottom of the box.

### Finer edits

[WitchyBND](https://github.com/ividyon/WitchyBND/releases): unpack, edit, pack, replace.

### Credits

[Yabber](https://github.com/JKAnderson/Yabber) for the DCX / BND3 / FMG work. Sibling project: [Dual Subtitle for DARK SOULS III](https://github.com/sausrau82hj/darksoulsiii-dual-subtitle).

---

## License / 许可证

MIT 只覆盖为这个项目写的脚本和 README（[LICENSE](LICENSE)）；`msg`、`source` 里的文本和 `font` 里的字体是修改过的 FromSoftware / Bandai Namco 内容，仅供离线单人使用。与原厂无关。

The MIT license in [LICENSE](LICENSE) covers only the scripts and README written for this project. The text under `msg` and `source`, and the font under `font`, are modified FromSoftware / Bandai Namco content for offline single-player use. Not affiliated with FromSoftware or Bandai Namco.
