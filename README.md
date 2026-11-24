# DualSubtitle — Dark Souls: Remastered Chinese–English dialogue

DARK SOULS: REMASTERED

中文 · English

---

## 中文

NPC 对话和过场动画字幕，中英对照，同一段文本里：游戏语言是哪种，哪种就在上面。

只改文本，别的都不动——菜单、道具、按键提示、事件提示全是原版。包里只有两个语言槽的 `menu.msgbnd.dcx`（外加一份给英文槽用的中文字体）：

| 游戏语言 | 用的文件 | 效果 |
| --- | --- | --- |
| 简体中文 | `msg\SCHINESE\menu.msgbnd.dcx` | 中文在上，英文在下 |
| 英文 | `msg\ENGLISH\menu.msgbnd.dcx` + `font\ENGLISH\TalkFont24.*` | 英文在上，中文在下 |

英文槽要放字体，因为原版英文字体没有汉字字形。

### 安装

先关游戏，装完离线启动。把 `msg`、`font` 拖进 `DARK SOULS REMASTERED` 目录覆盖即可（重制版本身就是散文件，不用解包）。

### 卸载

Steam 里校验一次文件完整性，或者从备份还原 `msg\menu.msgbnd.dcx`。

### 已知

- 对话和字幕按框的容量排版：放不下的会改成同一行、用 ` / ` 隔开，再放不下的保留原语言。
- 只覆盖对话与字幕。别的 mod 也换 `msg` 时无法共存。

---

## English

NPC dialogue and cutscene subtitles, both languages in the same entry — the game's own language on top.

Text only: menus, items, key prompts and notifications stay vanilla. The package holds one `menu.msgbnd.dcx` per slot, plus the Chinese font the English slot needs:

| Game language | Files used | Result |
| --- | --- | --- |
| Simplified Chinese | `msg\SCHINESE\menu.msgbnd.dcx` | Chinese on top, English underneath |
| English | `msg\ENGLISH\menu.msgbnd.dcx` + `font\ENGLISH\TalkFont24.*` | English on top, Chinese underneath |

The English slot needs the font because the vanilla English atlas has no CJK glyphs.

### Install

Close the game first, start it offline afterwards. Copy `msg` and `font` over the `DARK SOULS REMASTERED` folder — DSR ships unpacked, so there is no unpacker step.

### Uninstall

Verify the game files in Steam, or restore `msg\menu.msgbnd.dcx` from a backup.

### Notes

- Dialogue and subtitles are fitted to their boxes: what does not fit goes on one line separated by ` / `, and what still does not fit keeps the vanilla text.
- Dialogue and subtitles only. Another mod that replaces `msg` cannot be combined with this one.

---

## License / 许可证

The MIT license in [LICENSE](LICENSE) covers this README. The text under `msg` and the font under `font` are modified FromSoftware / Bandai Namco content, offline single-player use only. Not affiliated with FromSoftware or Bandai Namco.
