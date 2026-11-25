# Dual Subtitle — *DARK SOULS: REMASTERED*

Chinese on top and English underneath, in both language slots, so the game language does not change what the text says: dialogue, subtitles, event text, menus, key prompts, help, system messages, blood messages, items and the area titles.

**English** · [中文](#中文)

---

## English

### Install

Close the game. Copy `msg\`, `font\` and `menu\` over the `DARK SOULS REMASTERED` folder, overwriting. Start the game offline.

### Rebuild

Windows PowerShell (built in) and [Yabber](https://github.com/JKAnderson/Yabber/releases). Yabber goes in the package root (a folder named `Yabber*`, e.g. `Yabber 1.3.1\`) or under `tools\`; anywhere else, pass `-Yabber <folder>`.

```
powershell -ExecutionPolicy Bypass -File tools\dualsub.ps1
```

Defaults: reads `source\`, writes `msg\`. Options only when needed: `-Source` / `-Out`, `-Game`, `-Yabber`, `-Filter "menu"`, `-KeepWork`.

`tools\dualsub.config.json`:

- `separator` — separator inside one line, default `" / "`.
- `categories` — `true` merge · `"off"` leave as-is · `"en_only"` English only.
- `files` — per-pack and per-FMG overrides, highest priority:

```json
{
  "files": {
    "menu": {
      "fmg": {
        "Blood_writing_.fmg": { "separator": " ~ " },
        "Key_guide_.fmg": "en_only"
      }
    }
  }
}
```

`"enabled": false` on a pack skips the whole pack. Inside `fmg` a key takes a mode string (`"off"` / `"en_only"`) or `{ "separator": "…" }`. Keys are the pack name without `.msgbnd.dcx` and the FMG file name.

Text that already wraps keeps its newline. Dialogue and cutscene subtitles are fitted to their boxes: what does not fit goes on one line separated by ` / `.

### Notes

- The area title is drawn from `menu\<LANG>\menu_local.tpf.dcx` (`Menu20`/`Menu21` for the base game, `Menu30` for the DLC, the vanilla rule between the two languages), not from `msg`, so it ships as art; the same Chinese-first atlas goes into both slots. The build script writes `msg` and `font` only.
- One-line widgets take ` / ` between the languages, paragraphs a newline; a widget that already wraps keeps its own line breaks. Rows sized for one short label — key prompts, yes/no buttons, item names in a list — run wide or spill.
- Interaction prompts and menu labels sit in a field one label wide, so those keep the game's own language; longer prompt lines stay bilingual.
- The item detail panel takes about 18 lines: long descriptions keep the game's own language in full and cut the other one where the panel ends, with `...`.
- 7 dialogue entries still run past the bottom of the box.
- Another mod that also replaces `msg` or `menu` cannot be combined with this one.

---

## 中文

中文在上、英文在下，两个语言槽写的是同一份文本，切游戏语言不影响内容：对话、字幕、事件提示、菜单、按键提示、帮助、系统消息、血字、道具和地名标题全都覆盖。

### 安装

先关游戏。把 `msg\`、`font\`、`menu\` 三个文件夹拖进 `DARK SOULS REMASTERED` 目录覆盖，之后离线启动。

### 重新生成

Windows 自带的 PowerShell，加上 [Yabber](https://github.com/JKAnderson/Yabber/releases)。Yabber 解压到包根（目录名以 `Yabber` 开头，如 `Yabber 1.3.1\`）或 `tools\` 下都行；放在别处就用 `-Yabber <目录>` 指过去。

```
powershell -ExecutionPolicy Bypass -File tools\dualsub.ps1
```

默认读包里的 `source\`、写回包里的 `msg\`。要换路径或只重建一部分时才加参数：`-Source` / `-Out`、`-Game`、`-Yabber`、`-Filter "menu"`、`-KeepWork`。

`tools\dualsub.config.json`：

- `separator` — 单行内的分隔符，默认 `" / "`。
- `categories` — `true` 合并 · `"off"` 原样 · `"en_only"` 只留英文。
- `files` — 按包、按 FMG 覆盖，优先级最高：

```json
{
  "files": {
    "menu": {
      "fmg": {
        "Blood_writing_.fmg": { "separator": " ~ " },
        "Key_guide_.fmg": "en_only"
      }
    }
  }
}
```

包上写 `"enabled": false` 就整包跳过。`fmg` 里的键可以给模式字符串（`"off"` / `"en_only"`），也可以给 `{ "separator": "…" }`。键名是去掉 `.msgbnd.dcx` 的包名和 FMG 文件名。

原本带换行的文本固定保留换行。对话和字幕按框的容量排版：放不下的改成同一行，用 ` / ` 隔开。

### 注意

- 屏幕中央的地名是贴图，在 `menu\<LANG>\menu_local.tpf.dcx` 里（本体 `Menu20`/`Menu21`、DLC `Menu30`，中英之间用原版那条线分隔），不在 `msg` 里，所以以图片形式附带；两个语言槽用的是同一份中文优先的图集。生成脚本只写 `msg` 和 `font`。
- 单行控件用 ` / ` 连接，段落换行；原文本来带换行的保留自己的换行。按键提示、是/否按钮、列表里的道具名这些只有一格宽的框会变宽或溢出。
- 交互提示、菜单标签的框只有一个标签宽，这些保留游戏语言；较长的提示行仍然双语。
- 道具详情框大约放 18 行：长说明保留游戏语言全文，另一种语言在框底截断并加 `...`。
- 还有 7 条对话会顶到对话框下沿。
- 别的 mod 也换 `msg` 或 `menu` 时无法共存。

---

## Credits

Sibling project: [Dual Subtitle for DARK SOULS III](https://github.com/sausrau82hj/darksoulsiii-dual-subtitle). [Yabber](https://github.com/JKAnderson/Yabber) handles DCX / BND3 / FMG.

---

## License

[LICENSE](LICENSE) (MIT) covers the files written for this project — `tools/dualsub.ps1`, its config, this README. It does not cover the game text under `msg/` and `source/`, the font under `font/` or the atlases under `menu/` (modified FromSoftware / Bandai Namco content, offline single-player use only). Not affiliated with FromSoftware or Bandai Namco.
