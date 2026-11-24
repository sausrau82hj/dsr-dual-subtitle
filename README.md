# Dual Subtitle — *DARK SOULS: REMASTERED*

Chinese and English in one dialogue entry: 中文 on top, English underneath. Text only — no
gameplay, balance or asset changes.

The same text is written into every language slot (`ENGLISH`, `SCHINESE`, `TCHINESE`), so the
pack works whether the game is set to English or Chinese. A Chinese dialogue font ships with it,
because the English client's font has no CJK glyphs.

**English** · [中文](#中文)

---

## English

### Install

DARK SOULS: REMASTERED ships its files unpacked, so there is no unpacker step — the packs are
read from the game folder as they are.

- **Direct:** back up `msg\`, then copy `msg\` and `font\` from this package into the
  `DARK SOULS REMASTERED` folder, overwriting (`robocopy msg "<game>\msg" /E`). Launch the game
  offline afterwards.
- **Mod Engine 2 / DSR Mod Engine:** put `msg\` and `font\` into the loader's `mod\` folder
  (`ModEngine2\mod\msg\...`, `ModEngine2\mod\font\...`) and start the game with its launch script
  instead of Steam.
- Playing in Chinese only? Then `font\` is optional — `msg\SCHINESE\` (or `msg\TCHINESE\`) is
  enough on its own. The font folder exists because the English language slot loads
  `font\ENGLISH\`, whose atlas carries no Chinese glyphs.
- Uninstall: copy `source\msg\` back over the game folder, or verify the game files in Steam.

### What it changes

| Path | Content |
| --- | --- |
| `msg/ENGLISH/menu.msgbnd.dcx` | `Conversation_.fmg` (NPC dialogue) + `Movie_subtitles_.fmg` (cutscene subtitles) |
| `msg/SCHINESE/menu.msgbnd.dcx` | same, Simplified Chinese on top |
| `msg/TCHINESE/menu.msgbnd.dcx` | same, Traditional Chinese on top |
| `font/ENGLISH/TalkFont24.*` | Chinese dialogue font for the English language slot |

3,285 dialogue entries and 35 subtitle entries per pack. The other 12 FMGs inside the pack
(menus, items, system messages, key prompts …) and `item.msgbnd.dcx` are untouched.

### Rebuild

Python 3.9+ and [Yabber](https://github.com/JKAnderson/Yabber/releases) extracted anywhere under
the package root.

```
python tools\dualsub.py
```

Defaults: reads `source\`, writes `msg\`. The font is copied from the installed game.

- `--source` / `--out` — other folders.
- `--game` — game folder, auto-detected otherwise.
- `--yabber` — Yabber outside the package root.
- `--primary` / `--secondary` — swap the language shown on top and the one underneath.
- `--filter "menu*"` — matching packs only.
- `--keep-work` — keep the intermediate files.

`tools\dualsub.config.json`:

- `primary` / `secondary` — language shown on top and the one appended, default `SCHINESE` /
  `ENGLISH`.
- `languages` — the packs actually written, default `ENGLISH`, `SCHINESE`, `TCHINESE`.
- `chinese_source` — which Chinese text a slot shows; `ENGLISH` uses `SCHINESE`.
- `separator` — separator inside one line, default `"\n"` (use `" / "` for one line).
- `categories` — `true` merge · `"off"` leave as-is · `"sec_only"` secondary only. Only
  `Dialogue` and `Cutscene Subtitles` are on by default.
- `files` — per-pack and per-FMG overrides, highest priority.
- `font` — the font pair copied out of the game into `font\<target>`.

`python tools\verify.py` re-opens the built packs and checks that every merged entry equals
Chinese + separator + English, that the entry ids are unchanged, and that every other FMG is
byte-identical to vanilla.

### Known limitations

- Text only: another `msg` mod will overwrite this one, and vice versa.
- Most entries fit two lines (Chinese + English). About 130 of them carry enough English text to
  reach four lines, which can sit tight against the bottom of the dialogue box.
- The English language slot renders with the Chinese font, so English dialogue in that slot is
  drawn with the Chinese typeface's Latin glyphs.

### Finer edits

[WitchyBND](https://github.com/ividyon/WitchyBND/releases): unpack one pack, edit entries, repack.

---

## 中文

### 安装

黑暗之魂：重制版的光盘文件本身就是解包状态，不需要再解包，文件按原位读取。

- **直接覆盖**：先备份游戏的 `msg\`，把本包的 `msg\` 和 `font\` 覆盖进 `DARK SOULS REMASTERED`
  目录（`robocopy msg "<游戏目录>\msg" /E`），然后离线启动游戏。
- **Mod Engine 2 / DSR Mod Engine**：把 `msg\` 和 `font\` 放进加载器的 `mod\` 目录
  （`ModEngine2\mod\msg\...`、`ModEngine2\mod\font\...`），用它自带的启动脚本进游戏，不走
  Steam 启动。
- 只玩中文的话 `font\` 可以不装，只放 `msg\SCHINESE\`（或 `msg\TCHINESE\`）就够。带字体是因为
  英文语言槽会读 `font\ENGLISH\`，那套字体图集里没有中文。
- 卸载：把 `source\msg\` 复制回去覆盖，或者在 Steam 里校验文件完整性。

### 改动内容

| 路径 | 内容 |
| --- | --- |
| `msg/ENGLISH/menu.msgbnd.dcx` | `Conversation_.fmg`（NPC 对话）+ `Movie_subtitles_.fmg`（过场动画字幕） |
| `msg/SCHINESE/menu.msgbnd.dcx` | 同上，简体中文在上 |
| `msg/TCHINESE/menu.msgbnd.dcx` | 同上，繁体中文在上 |
| `font/ENGLISH/TalkFont24.*` | 给英文语言槽用的中文字体 |

每个包 3,285 条对话、35 条字幕。包内其余 12 个 FMG（菜单、道具、系统提示、按键提示等）以及
`item.msgbnd.dcx` 都没有改动。

### 重新生成

需要 Python 3.9+ 和 [Yabber](https://github.com/JKAnderson/Yabber/releases)，解压到包内任意
位置即可。

```
python tools\dualsub.py
```

默认读包里的 `source\`、写回包里的 `msg\`。字体从已安装的游戏里复制。

- `--source` / `--out` — 换目录。
- `--game` — 游戏目录，默认自动查找。
- `--yabber` — Yabber 不在包内时。
- `--primary` / `--secondary` — 换主（在上）副（在下）语言。
- `--filter "menu*"` — 只重建匹配的包。
- `--keep-work` — 保留中间文件。

`tools\dualsub.config.json`：

- `primary` / `secondary` — 在上面显示的语言与跟在后面的语言，默认 `SCHINESE` / `ENGLISH`。
- `languages` — 实际写出的包，默认 `ENGLISH`、`SCHINESE`、`TCHINESE`。
- `chinese_source` — 某个槽用哪份中文；`ENGLISH` 用 `SCHINESE`。
- `separator` — 单行内的分隔符，默认 `"\n"`（想并成一行就写 `" / "`）。
- `categories` — `true` 合并 · `"off"` 原样 · `"sec_only"` 只留副语言。默认只开
  `Dialogue` 与 `Cutscene Subtitles`。
- `files` — 按包、按 FMG 覆盖，优先级最高。
- `font` — 从游戏复制到 `font\<target>` 的字体对。

`python tools\verify.py` 会重新拆开生成好的包，逐条核对“中文 + 分隔符 + 英文”、条目 id 是否
一致，以及其余 FMG 是否与原始文件逐字节相同。

### 已知限制

- 只改文本；别的 mod 也换 `msg` 时会互相覆盖。
- 绝大多数条目是两行（中文一行、英文一行）。大约 130 条英文较长，会占到四行，可能贴到对话框
  底边。
- 英文语言槽用中文字体渲染，所以那一槽的英文对话是中文字体里的西文字形。

### 更精细的修改

[WitchyBND](https://github.com/ividyon/WitchyBND/releases)：单独解包一个包，改完重新打包。

---

## Credits

- Sibling project: [Dual Subtitle for DARK SOULS III](https://github.com/sausrau82hj/darksoulsiii-dual-subtitle).
- [Yabber](https://github.com/JKAnderson/Yabber) for DCX / BND3 / FMG handling.

## License

[LICENSE](LICENSE) (MIT) covers the files written for this project — `tools\dualsub.py`, its
config, `tools\verify.py` and this README. It does not cover the game text or the font, which are
modified FromSoftware / Bandai Namco content; offline single-player use only. Not affiliated with
FromSoftware or Bandai Namco.
