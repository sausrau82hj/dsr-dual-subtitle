#!/usr/bin/env python3
"""DARK SOULS: REMASTERED dual-language text builder.

Reads the msg packs from <package>/source, merges the Chinese and English text entry by
entry (Chinese on top, English underneath), writes the repacked packs into <package>/msg
and copies the Chinese font into the English slot, which has no CJK glyphs of its own.

All container work (DCX, BND3, FMG) is done by Yabber; this script only walks folders,
edits the FMG XML and calls Yabber to repack.

    python tools/dualsub.py
    python tools/dualsub.py --filter menu
    python tools/dualsub.py --source "D:/.../DARK SOULS REMASTERED" --out stage
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

SLOTS = ("ENGLISH", "SCHINESE")
CJK_SLOT = "SCHINESE"

CATEGORY_RULES = [
    ("Dialogue", ("Conversation_*",)),
    ("Cutscene Subtitles", ("Movie_subtitles_*",)),
    ("Dialogue Boxes", ("Dialogue_*",)),
    ("Event Text", ("Event_text_*",)),
    ("Menu Text", ("Menu_general_text_*", "Menu_others_*", "Ingame_menu_*", "Text_display_*")),
    ("Key Prompts", ("Key_guide_*",)),
    ("Help Text", ("Item_help_*", "Single_line_help_*")),
    ("System Messages", ("System_message_*", "System_specific_tags_*")),
    ("Blood Messages", ("Blood_writing_*",)),
    ("Item Names", ("*_name_*",)),
    ("Item Descriptions", ("*_description_*", "*_long_desc_*")),
]

DEFAULT_CATEGORIES = [
    ("Dialogue", True),
    ("Cutscene Subtitles", True),
]

# Paragraph widgets keep a newline between the languages; one-line widgets take the inline
# separator; anything else follows the entry itself.
MULTILINE = ("Conversation_*", "Movie_subtitles_*", "Dialogue_*", "*_long_desc_*")
ONELINE = (
    "*_name_*", "Place_name_*", "NPC_name_*", "Key_guide_*", "Single_line_help_*",
    "Item_help_*", "*_description_*", "System_specific_tags_*", "Text_display_tag_list_*",
    "Menu_general_text_*", "Menu_others_*", "Ingame_menu_*", "Event_text_*",
)

NULL_MARKERS = ("", "null", "%null%")
YABBER_HELP = """Yabber not found.
  Extract Yabber anywhere under this package's root folder, or pass --yabber <dir>,
  set "yabber_dir" in the config, or set the YABBER_DIR environment variable.
  The folder must hold both Yabber.exe and Yabber.DCX.exe.
  Download: https://github.com/JKAnderson/Yabber/releases
"""


def log(msg: str = "") -> None:
    print(msg, flush=True)


def fail(msg: str) -> "None":
    print(msg, flush=True)
    sys.exit(1)


def wild(name: str, patterns) -> bool:
    from fnmatch import fnmatchcase

    base = os.path.basename(name)
    return any(fnmatchcase(base, p) for p in patterns)


def stem(path: str) -> str:
    name = os.path.basename(path)
    for suffix in (".msgbnd.dcx", ".msgbnd"):
        if name.lower().endswith(suffix):
            return name[: -len(suffix)]
    return os.path.splitext(name)[0]


# ---- yabber / game ---------------------------------------------------------------------


def find_yabber(pack_root: str, script_dir: str, hint: str = "") -> str:
    candidates = []
    if hint:
        candidates.append(hint)
    if os.environ.get("YABBER_DIR"):
        candidates.append(os.environ["YABBER_DIR"])
    roots = [pack_root, script_dir, os.path.expandvars(r"%LOCALAPPDATA%"),
             os.path.join(os.path.expanduser("~"), "Downloads"), os.path.expanduser("~"),
             r"D:\game\TOOL", r"D:\Tools", r"D:\tool", r"C:\Tools", r"C:\tool"]
    for root in roots:
        if not root or not os.path.isdir(root):
            continue
        try:
            entries = sorted(os.listdir(root))
        except OSError:
            continue
        for name in entries:
            full = os.path.join(root, name)
            if os.path.isdir(full) and name.lower().startswith("yabber"):
                candidates.append(full)
            elif os.path.isdir(full):
                try:
                    for inner in sorted(os.listdir(full)):
                        deep = os.path.join(full, inner)
                        if os.path.isdir(deep) and inner.lower().startswith("yabber"):
                            candidates.append(deep)
                except OSError:
                    pass
    for cand in candidates:
        if (os.path.isfile(os.path.join(cand, "Yabber.exe"))
                and os.path.isfile(os.path.join(cand, "Yabber.DCX.exe"))):
            return os.path.abspath(cand)
    fail(YABBER_HELP)


def default_game() -> str:
    env = os.environ.get("DSR_GAME_DIR", "")
    if env and os.path.isfile(os.path.join(env, "DarkSoulsRemastered.exe")):
        return env
    roots = []
    try:
        import winreg

        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Software\Valve\Steam") as key:
            steam = winreg.QueryValueEx(key, "SteamPath")[0]
        roots.append(steam)
        vdf = os.path.join(steam, "steamapps", "libraryfolders.vdf")
        if os.path.isfile(vdf):
            import re

            with open(vdf, "r", encoding="utf-8", errors="ignore") as fh:
                for m in re.finditer(r'"path"\s+"([^"]+)"', fh.read()):
                    roots.append(m.group(1).replace("\\\\", "\\"))
    except Exception:
        pass
    roots += [r"D:\steam\steamapps\common", r"E:\steam\steamapps\common",
              r"F:\steam\steamapps\common", r"C:\Program Files (x86)\Steam\steamapps\common"]
    for root in roots:
        cand = os.path.join(root, "DARK SOULS REMASTERED")
        if os.path.isfile(os.path.join(cand, "DarkSoulsRemastered.exe")):
            return cand
    return r"D:\steam\steamapps\common\DARK SOULS REMASTERED"


def run_yabber(tool: str, path: str) -> None:
    proc = subprocess.run([tool, path], capture_output=True, text=True)
    if proc.returncode != 0:
        raise RuntimeError(f"Yabber failed: {path} (exit {proc.returncode})\n{proc.stdout}{proc.stderr}")


def expand_pack(yabber: dict, dcx_path: str, work_dir: str) -> dict:
    os.makedirs(work_dir, exist_ok=True)
    dcx = os.path.join(work_dir, os.path.basename(dcx_path))
    shutil.copyfile(dcx_path, dcx)
    run_yabber(yabber["dcx"], dcx)
    msgbnd = dcx[:-4]
    run_yabber(yabber["exe"], msgbnd)
    unpacked = os.path.join(work_dir, os.path.splitext(os.path.basename(msgbnd))[0] + "-msgbnd")
    fmg_dir = None
    for root, _dirs, files in os.walk(unpacked):
        if any(f.lower().endswith(".fmg") for f in files):
            fmg_dir = root
            break
    if fmg_dir is None:
        raise RuntimeError(f"No FMG found in {unpacked}")
    return {"unpacked": unpacked, "fmg_dir": fmg_dir, "msgbnd": msgbnd}


# ---- text helpers ----------------------------------------------------------------------

WIDE_RANGES = (
    (0x1100, 0x115F), (0x2E80, 0xA4CF), (0xAC00, 0xD7A3), (0xF900, 0xFAFF),
    (0xFE30, 0xFE4F), (0xFF00, 0xFF60), (0xFFE0, 0xFFE6), (0x3000, 0x303F),
)


def units(text: str) -> int:
    total = 0
    for ch in text:
        code = ord(ch)
        total += 2 if any(lo <= code <= hi for lo, hi in WIDE_RANGES) else 1
    return total


def norm(text: str) -> str:
    import re

    return re.sub(r"\s+", "", text or "").lower()


def is_null(text: str) -> bool:
    if text is None:
        return True
    return text.strip().lower() in NULL_MARKERS


def rendered_lines(text: str, width: int) -> int:
    return sum(max(1, -(-units(line) // width)) for line in text.split("\n"))


def join_flat(text: str) -> str:
    parts = [p.strip() for p in text.split("\n")]
    out = parts[0]
    for i in range(1, len(parts)):
        prev = parts[i - 1]
        out += ("" if prev and units(prev[-1]) == 2 else " ") + parts[i]
    return out


def fit_spec(fmg: str):
    if fmg == "Conversation_.fmg":
        return {"max": 3, "width": 60, "preview": False}
    if fmg == "Movie_subtitles_.fmg":
        return {"max": 2, "width": 62, "preview": False}
    if wild(fmg, ("*_long_desc_*",)):
        return {"max": 20, "width": 60, "preview": True}
    return None


def merged_text(top: str, bottom: str, inline: str, fit: dict):
    if not fit:
        return None
    stacked = top + "\n" + bottom
    if rendered_lines(stacked, fit["width"]) <= fit["max"]:
        return stacked
    if not fit["preview"]:
        flat = " ".join((join_flat(top) + inline + join_flat(bottom)).split())
        if rendered_lines(flat, fit["width"]) <= fit["max"]:
            return flat
        if rendered_lines(flat, fit["width"]) <= rendered_lines(stacked, fit["width"]):
            return flat
        return stacked
    top_lines = rendered_lines(top, fit["width"])
    budget = fit["max"] - top_lines
    if budget < 1:
        return top
    keep, used = [], 0
    for line in bottom.split("\n"):
        need = max(1, -(-units(line) // fit["width"]))
        if used + need > budget:
            break
        keep.append(line)
        used += need
    if not keep:
        return top
    return top + "\n" + "\n".join(keep)


def truncated(text: str, max_units: int) -> str:
    if units(text) <= max_units:
        return text
    out, used, last_space = [], 0, -1
    for ch in text:
        w = units(ch)
        if used + w > max_units:
            break
        out.append(ch)
        used += w
        if ch == " ":
            last_space = len(out) - 1
    result = "".join(out)
    if last_space > int(len(result) * 0.6):
        result = result[:last_space]
    return result.rstrip()


def inline_text(top: str, bottom: str, inline: str, wide: bool = False) -> str:
    widest = max(units(top), units(bottom))
    merged = top + inline + bottom
    # Item panels have room to spare, so there the merged line may reach twice the game's own
    # string; menu rows only get a short margin before the text is cut at the field edge.
    budget = widest * 2 if wide else widest + 10
    # a couple of characters over the edge is not worth cutting a word for
    if units(merged) <= budget + 2:
        return merged
    cut = truncated(merged, budget)
    # nothing useful of the second language survived -> keep the game's own line only
    if inline in cut:
        head, _, tail = cut.rpartition(inline)
        if units(tail.strip()) < 3:
            return head.rstrip()
    return cut


def already_merged(t1: str, t2: str, sep: str) -> bool:
    if not sep:
        return False
    if t1.endswith(sep + t2) or t2.endswith(sep + t1):
        return True
    a = t1.split(sep)
    b = t2.split(sep)
    if len(a) <= 1 or len(b) <= 1 or len(a) != len(b):
        return False
    return sorted(a) == sorted(b)


def category(fmg: str) -> str:
    base = os.path.basename(fmg)
    for name, patterns in CATEGORY_RULES:
        if wild(base, patterns):
            return name
    return "Other"


def value_mode(value):
    if isinstance(value, dict):
        if value.get("mode"):
            return str(value["mode"])
        if "enabled" in value:
            return "append" if value["enabled"] else "off"
        return "append"
    if isinstance(value, str):
        return value.strip()
    return "append" if value else "off"


def get_mode(cfg: dict, pack: str, fmg: str) -> str:
    entry = (cfg.get("files") or {}).get(stem(pack)) or {}
    if entry:
        if not entry.get("enabled", True):
            return "off"
        for pattern, value in (entry.get("fmg") or {}).items():
            if wild(fmg, (pattern,)):
                return value_mode(value)
    value = (cfg.get("categories") or {}).get(category(fmg))
    if value is not None:
        return value_mode(value)
    return "off"


def inline_sep(cfg: dict) -> str:
    sep = cfg.get("separator", " / ")
    if sep == "\\n":
        return "\n"
    if not sep:
        return " / "
    return str(sep)


def separator_for(cfg: dict, pack: str, fmg: str):
    entry = (cfg.get("files") or {}).get(stem(pack)) or {}
    for pattern, value in (entry.get("fmg") or {}).items():
        if wild(fmg, (pattern,)) and isinstance(value, dict) and "separator" in value:
            sep = value["separator"]
            return "\n" if sep == "\\n" else str(sep)
    if wild(fmg, MULTILINE):
        return "\n"
    if wild(fmg, ONELINE):
        return inline_sep(cfg)
    return None


# ---- fmg editing -----------------------------------------------------------------------


def text_map(yabber: dict, fmg_dir: str, fmg: str) -> dict:
    path = os.path.join(fmg_dir, fmg)
    run_yabber(yabber["exe"], path)
    tree = ET.parse(path + ".xml")
    out = {}
    for el in tree.getroot().findall("./entries/text"):
        out[el.get("id")] = (el.text or "").replace("\r\n", "\n").replace("\r", "\n")
    return out


def update_fmg(yabber: dict, fmg_dir: str, fmg: str, top_map: dict, bottom_map: dict,
               mode: str, sep, inline: str, wide: bool = False) -> int:
    path = os.path.join(fmg_dir, fmg)
    xml_path = path + ".xml"
    tree = ET.parse(xml_path)
    changed = 0
    fit = fit_spec(fmg)
    for el in tree.getroot().findall("./entries/text"):
        entry_id = el.get("id")
        top = (top_map.get(entry_id) or "")
        bottom = (bottom_map.get(entry_id) or "")
        if is_null(bottom):
            continue
        if mode == "en_only":
            if top == bottom:
                continue
            el.text = bottom
            changed += 1
            continue
        if is_null(top):
            continue
        if norm(top) == norm(bottom):
            continue
        use_sep = sep
        if use_sep is None:
            use_sep = "\n" if ("\n" in top or "\n" in bottom) else inline
        if already_merged(top, bottom, use_sep):
            continue
        if fmg.lower().startswith("event_text_") and min(units(top), units(bottom)) <= 12:
            continue
        text = merged_text(top, bottom, inline, fit) if fit else None
        if not text:
            text = (inline_text(top, bottom, inline, wide=wide) if use_sep == inline
                    else top + use_sep + bottom)
        el.text = text
        changed += 1
    if changed:
        tree.write(xml_path, encoding="utf-8", xml_declaration=True)
        run_yabber(yabber["exe"], xml_path)
    return changed


def pack_names(root: str, lang_a: str, lang_b: str) -> list:
    a = os.path.join(root, "msg", lang_a)
    b = os.path.join(root, "msg", lang_b)
    names = {}
    if os.path.isdir(a):
        for name in os.listdir(a):
            if name.lower().endswith(".msgbnd.dcx"):
                names[name.lower()] = name
    have = set()
    if os.path.isdir(b):
        have = {n.lower() for n in os.listdir(b)}
    return sorted(n for k, n in names.items() if k in have)


# ---- main ------------------------------------------------------------------------------


def main() -> int:
    parser = argparse.ArgumentParser(description="Build the DSR dual-language text packs.")
    parser.add_argument("--source", help="folder holding msg\\<LANG>\\*.msgbnd.dcx (default: the package's source\\)")
    parser.add_argument("--out", help="folder to write msg\\ and font\\ into (default: the package root)")
    parser.add_argument("--game", help="game folder, used for the font")
    parser.add_argument("--yabber", help="folder holding Yabber.exe and Yabber.DCX.exe")
    parser.add_argument("--config", help="config file (default: tools\\dualsub.config.json)")
    parser.add_argument("--filter", help="build only packs whose name matches this pattern")
    parser.add_argument("--keep-work", action="store_true", help="keep the intermediate files")
    args = parser.parse_args()

    script_dir = os.path.dirname(os.path.abspath(__file__))
    pack_root = os.path.dirname(script_dir) if os.path.basename(script_dir).lower() == "tools" else script_dir
    config_path = args.config or os.path.join(script_dir, "dualsub.config.json")
    if not os.path.isfile(config_path):
        fail(f"Config not found: {config_path}")

    with open(config_path, "r", encoding="utf-8") as fh:
        from_file = json.load(fh)
    cfg = {"categories": dict(DEFAULT_CATEGORIES)}
    for key, value in from_file.items():
        if key == "categories":
            cfg["categories"].update(value)
        else:
            cfg[key] = value

    out_dir = args.out or pack_root
    game_dir = args.game or default_game()

    source = args.source
    if not source:
        packaged = os.path.join(pack_root, "source")
        source = packaged if os.path.isdir(os.path.join(packaged, "msg")) else game_dir
    if not os.path.isdir(os.path.join(source, "msg")):
        fail(f"Text packs not found: {os.path.join(source, 'msg')}")

    yabber_dir = args.yabber or cfg.get("yabber_dir") or find_yabber(pack_root, script_dir)
    yabber = {"dir": yabber_dir,
              "exe": os.path.join(yabber_dir, "Yabber.exe"),
              "dcx": os.path.join(yabber_dir, "Yabber.DCX.exe")}
    if not (os.path.isfile(yabber["exe"]) and os.path.isfile(yabber["dcx"])):
        fail(f"Yabber not found in: {yabber_dir}\n{YABBER_HELP}")

    packs = pack_names(source, CJK_SLOT, "ENGLISH")
    if args.filter:
        from fnmatch import fnmatchcase

        packs = [p for p in packs if fnmatchcase(stem(p), args.filter)]
    if not packs:
        fail("No text packs to process")

    log(f"Source: {source}")
    log(f"Output: {out_dir}")
    log(f"Slots: {', '.join(SLOTS)}, {len(packs)} packs")
    log()

    total_fmg = 0
    total_entries = 0
    for pack in packs:
        name = stem(pack)
        log(f"[{name}]")
        work_root = os.path.join(out_dir, "_work", name)
        if os.path.isdir(work_root):
            shutil.rmtree(work_root, ignore_errors=True)

        dirs, texts = {}, {}
        for lang in SLOTS:
            src = os.path.join(source, "msg", lang, pack)
            if not os.path.isfile(src):
                continue
            expanded = expand_pack(yabber, src, os.path.join(work_root, lang))
            dirs[lang] = expanded
            maps = {}
            for fmg in sorted(f for f in os.listdir(expanded["fmg_dir"]) if f.lower().endswith(".fmg")):
                maps[fmg] = text_map(yabber, expanded["fmg_dir"], fmg)
            texts[lang] = maps

        pack_entries = 0
        for lang in SLOTS:
            if lang not in dirs:
                continue
            changed = 0
            for fmg in sorted(f for f in os.listdir(dirs[lang]["fmg_dir"]) if f.lower().endswith(".fmg")):
                if fmg not in texts.get(CJK_SLOT, {}) or fmg not in texts.get("ENGLISH", {}):
                    continue
                mode = get_mode(cfg, pack, fmg)
                if mode == "off":
                    continue
                sep = separator_for(cfg, pack, fmg)
                count = update_fmg(yabber, dirs[lang]["fmg_dir"], fmg, texts[CJK_SLOT][fmg],
                                   texts["ENGLISH"][fmg], mode, sep, inline_sep(cfg),
                                   wide=(name == "item"))
                if count:
                    changed += count
                    total_fmg += 1
                    log(f"  + {lang}/{fmg}: {count} entries")
            if not changed:
                log(f"  = {lang}: nothing to merge")
                continue
            pack_entries += changed
            run_yabber(yabber["exe"], dirs[lang]["unpacked"])
            run_yabber(yabber["dcx"], dirs[lang]["msgbnd"])
            dst = os.path.join(out_dir, "msg", lang, pack)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copyfile(dirs[lang]["msgbnd"] + ".dcx", dst)
            log(f"  -> {dst}")
        total_entries += pack_entries
        if not pack_entries:
            log(f"  = {name} stays vanilla, not installed")
        if not args.keep_work:
            shutil.rmtree(work_root, ignore_errors=True)
        log()

    font_files = ["TalkFont24.ccm.dcx", "TalkFont24.tpf.dcx"]
    ui_on = any(value_mode(v) != "off" for k, v in cfg["categories"].items()
                if k not in ("Dialogue", "Cutscene Subtitles"))
    if ui_on:
        font_files += ["DSFont24.ccm.dcx", "DSFont24.tpf.dcx"]
    font_src = os.path.join(game_dir, "font", CJK_SLOT.lower())
    for lang in SLOTS:
        if lang == CJK_SLOT:
            continue
        font_dst = os.path.join(out_dir, "font", lang)
        os.makedirs(font_dst, exist_ok=True)
        for fname in font_files:
            src = os.path.join(font_src, fname)
            if os.path.isfile(src):
                shutil.copyfile(src, os.path.join(font_dst, fname))
            elif not os.path.isfile(os.path.join(font_dst, fname)):
                log(f"  ! font missing: {src}")
        log(f"  -> {font_dst}")

    log(f"Done: {total_fmg} FMGs, {total_entries} entries")
    log(f"Mod files in: {out_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
