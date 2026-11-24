# DualSubtitle — Dark Souls: Remastered Chinese–English dual-language text · 中英双语文本

DARK SOULS: REMASTERED

中文 · [English](#english)

---

## 中文

只改 NPC 对话（`Conversation_.fmg`）与过场动画字幕（`Movie_subtitles_.fmg`）：两句语言同屏，游戏用哪种语言，哪种就在上面。菜单、道具、按键提示等其余文本保持原版。

`msg\ENGLISH`、`msg\SCHINESE` 两个语言槽都已写好，主副语言在 `tools\dualsub.config.json` 的 `primary` / `secondary` 里换。`msg` 里同时带着未改动的 `item.msgbnd.dcx`，整个文件夹覆盖也不会缺文件。

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

参数只在需要时加：`-Source` / `-Out`、`-Game`、`-Yabber`、`-Config`、`-KeepWork`。

配置项：`primary` / `secondary`（这一对语言，默认 `SCHINESE` / `ENGLISH`，可对调）、`separator`（单行文本的分隔符，默认换行）、`categories`（`true` 合并 · `"off"` 原样 · `"sec_only"` 只留第二语言）、`files`（按包、按 FMG 的例外）。

默认只开 `Dialogue` 与 `Cutscene Subtitles`。别的类别想双语就把对应的值改成 `true`：工具会照配置直接合并，不再替排版做取舍。

### 已知限制

- 只改文本；别的 mod 也换 `msg` 时，把它的文件放进 `source\` 再生成。
- 对话和字幕这两个框会按容量排版：放不下的改成同一行、中间用 ` / ` 隔开，再放不下的保留原文。其他类别不受保护——开了以后框小的地方（菜单行、按钮、按键提示）会压字。

### 致谢

[Yabber](https://github.com/JKAnderson/Yabber) 处理 DCX / BND3 / FMG；同系列：[DARK SOULS III 双语](https://github.com/sausrau82hj/darksoulsiii-dual-subtitle)。

---

## English

NPC dialogue (`Conversation_.fmg`) and cutscene subtitles (`Movie_subtitles_.fmg`) only: both languages in one entry, the game's own language on top. Menus, items and key prompts stay vanilla.

`msg\ENGLISH` and `msg\SCHINESE` are both written; swap the pair in `tools\dualsub.config.json` (`primary` / `secondary`). `msg` also carries the untouched `item.msgbnd.dcx`, so replacing the whole folder leaves no gap.

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

Extra arguments only when needed: `-Source` / `-Out`, `-Game`, `-Yabber`, `-Config`, `-KeepWork`.

Config keys: `primary` / `secondary` (the pair, default `SCHINESE` / `ENGLISH`, swap freely), `separator` (separator inside one line, newline by default), `categories` (`true` merge · `"off"` untouched · `"sec_only"` second language only), `files` (per-pack, per-FMG exceptions).

Only `Dialogue` and `Cutscene Subtitles` are on by default. Set another category to `true` and the tool merges it as configured — it does not second-guess the layout for you.

### Known limitations

- Text only. If another mod also replaces `msg`, put its files in `source\` and rebuild.
- The dialogue and subtitle boxes are fitted: anything longer goes on one line separated by ` / `, and what still does not fit keeps the vanilla text. Other categories get no such protection — small boxes (menu rows, buttons, key prompts) will overlap once you enable them.

### Credits

[Yabber](https://github.com/JKAnderson/Yabber) for the DCX / BND3 / FMG work. Sibling project: [Dual Subtitle for DARK SOULS III](https://github.com/sausrau82hj/darksoulsiii-dual-subtitle).

---

## License / 许可证

MIT 只覆盖为这个项目写的脚本和 README（[LICENSE](LICENSE)）；`msg`、`source` 里的文本和 `font` 里的字体是修改过的 FromSoftware / Bandai Namco 内容，仅供离线单人使用。与原厂无关。

The MIT license in [LICENSE](LICENSE) covers only the scripts and README written for this project. The text under `msg` and `source`, and the font under `font`, are modified FromSoftware / Bandai Namco content for offline single-player use. Not affiliated with FromSoftware or Bandai Namco.
