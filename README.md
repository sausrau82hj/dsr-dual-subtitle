# Dual Subtitle — *DARK SOULS: REMASTERED*

NPC dialogue, cutscene subtitles and the area title that appears after warping: Chinese on top, English underneath. Both language slots carry the same text, so the game language does not change what it says.

**English** · [中文](#中文)

---

## English

### Install

Close the game and back up `msg\`, `font\` and `menu\`. Copy the three folders over the `DARK SOULS REMASTERED` folder, overwriting. Start the game offline. Undo by copying the backup back or by verifying the files in Steam.

### What each folder covers

| Path | Covers |
| --- | --- |
| `msg\SCHINESE\menu.msgbnd.dcx` | NPC dialogue and cutscene subtitles |
| `msg\ENGLISH\menu.msgbnd.dcx` | the same text, for the English language slot |
| `font\ENGLISH\` | the Chinese font the English slot has no glyphs for |
| `menu\SCHINESE\menu_local.tpf.dcx` | the big area title, Chinese slot |
| `menu\ENGLISH\menu_local.tpf.dcx` | the big area title, English slot |

Everything else stays vanilla: menus, items (the bonfire warp list included), key prompts, tutorials, system messages and blood messages.

### Notes

- The area title is art, not text: it is drawn from `menu\<LANG>\menu_local.tpf.dcx`, so it ships as a texture and the script never touches it.
- The English slot draws Chinese with the Chinese font, so those glyphs look a little heavier than in the Chinese slot.
- Another mod that also replaces `msg` or `menu` cannot be combined with this one.

---

## 中文

NPC 对话、过场动画字幕、传送后出现的地区名字：中文在上、英文在下。两个语言槽写的是同一份文本，切游戏语言不影响内容。

### 安装

先关游戏，备份 `msg\`、`font\`、`menu\`。再把这三个文件夹拖进 `DARK SOULS REMASTERED` 目录覆盖，之后离线启动。还原就是把备份盖回去，或在 Steam 里校验文件。

### 每个文件夹管什么

| 路径 | 作用 |
| --- | --- |
| `msg\SCHINESE\menu.msgbnd.dcx` | NPC 对话与过场动画字幕 |
| `msg\ENGLISH\menu.msgbnd.dcx` | 同一份文本，给英文语言槽 |
| `font\ENGLISH\` | 英文槽缺的中文字形 |
| `menu\SCHINESE\menu_local.tpf.dcx` | 屏幕中央的地区名大字，中文槽 |
| `menu\ENGLISH\menu_local.tpf.dcx` | 屏幕中央的地区名大字，英文槽 |

其余全部保持原版：菜单、道具（含篝火传送列表）、按键提示、教学、系统消息、血字。

### 注意

- 地区名大字是贴图不是文本，在 `menu\<LANG>\menu_local.tpf.dcx` 里，由脚本之外单独替换。
- 英文槽是用中文字体的字形画中文，看起来比中文槽略粗。
- 别的 mod 也换 `msg` 或 `menu` 时无法共存。

---

## License / 许可证

[LICENSE](LICENSE) (MIT) covers this README. It does not cover the game text under `msg/`, the font under `font/` or the atlases under `menu/` (modified FromSoftware / Bandai Namco content, offline single-player use only). Not affiliated with FromSoftware or Bandai Namco.
