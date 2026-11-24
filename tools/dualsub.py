#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""DARK SOULS: REMASTERED dual-language text tool (default: Chinese primary, English secondary).

How it works:
  1. read the text packs from <source>/msg/<LANG>/menu.msgbnd.dcx
  2. unpack DCX -> BND3 -> FMG with Yabber
  3. merge the two languages entry by entry into "Chinese\\nEnglish"
  4. write the result into every language slot (ENGLISH, SCHINESE, TCHINESE), so the pack
     works whichever language the game is set to
  5. the config decides which FMGs take part (dialogue / subtitles / menus / items ...)
  6. repack into <out>/msg/<LANG>/menu.msgbnd.dcx, plus the Chinese dialogue font for the
     English slot (the English atlas carries no CJK glyphs)

Usage:
  python tools\\dualsub.py                       # build everything from source\\ into msg\\
  python tools\\dualsub.py --filter menu         # only one pack (debugging)
  python tools\\dualsub.py --source <dir> --out <dir>
"""
from __future__ import annotations

import argparse
import fnmatch
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
# Package root: when the script lives in <package>/tools/ this is the package root,
# and the output defaults to <package>/
PACK_ROOT = os.path.dirname(SCRIPT_DIR) if os.path.basename(SCRIPT_DIR).lower() == "tools" else SCRIPT_DIR
DEFAULT_CONFIG = os.path.join(SCRIPT_DIR, "dualsub.config.json")

NULL_MARKERS = {"%null%", "null", ""}


def norm(t: str) -> str:
    return re.sub(r"\s+", "", t or "").lower()


def is_null(t) -> bool:
    return t is None or t.strip().lower() in NULL_MARKERS


def is_already_merged(t1: str, t2: str, sep: str) -> bool:
    """True when this text pair is already merged, so a rebuild never stacks the two twice."""
    if not sep:
        return False
    if t1.endswith(sep + t2) or t2.endswith(sep + t1):
        return True
    a, b = t1.split(sep), t2.split(sep)
    return len(a) > 1 and len(b) > 1 and sorted(a) == sorted(b)


class Yabber:
    def __init__(self, directory: str):
        self.exe = os.path.join(directory, "Yabber.exe")
        self.dcx = os.path.join(directory, "Yabber.DCX.exe")
        for p in (self.exe, self.dcx):
            if not os.path.exists(p):
                raise SystemExit(f"Yabber not found in: {directory}\n"
                                 "Download: https://github.com/JKAnderson/Yabber/releases")

    def run(self, tool: str, path: str) -> None:
        proc = subprocess.run([tool, path], capture_output=True, text=True,
                              encoding="utf-8", errors="replace")
        if proc.returncode != 0:
            raise RuntimeError(f"Yabber failed: {path}\n{proc.stdout}\n{proc.stderr}")


def find_yabber(hint: str = "") -> str:
    """Locate the Yabber folder (must hold both Yabber.exe and Yabber.DCX.exe)."""
    cands = []
    if hint:
        cands.append(hint)
    exe = shutil.which("Yabber.exe") or shutil.which("Yabber")
    if exe:
        cands.append(os.path.dirname(os.path.abspath(exe)))
    roots = [
        PACK_ROOT, SCRIPT_DIR,
        r"D:\Hermesworkplace\tools\Yabber", r"D:\game\TOOL", r"D:\Tools", r"D:\tool",
        r"C:\Tools", r"C:\tool", os.environ.get("YABBER_DIR", ""),
        os.path.expanduser("~\\Downloads"),
    ]
    for root in roots:
        if not root or not os.path.isdir(root):
            continue
        for pat in ("Yabber*", os.path.join("*", "Yabber*"), os.path.join("Yabber*", "Yabber*")):
            cands.extend(sorted(glob.glob(os.path.join(root, pat))))
    for c in cands:
        if c and os.path.isfile(os.path.join(c, "Yabber.exe")) \
                and os.path.isfile(os.path.join(c, "Yabber.DCX.exe")):
            return os.path.abspath(c)
    raise SystemExit("Yabber not found. Extract Yabber anywhere under this package's root folder, "
                     "pass --yabber <dir>, or set \"yabber_dir\" in the config.")


def default_game() -> str:
    """Locate the DSR folder (environment variable -> Steam library -> usual paths)."""
    env = os.environ.get("DSR_GAME_DIR", "")
    if env and os.path.isfile(os.path.join(env, "DarkSoulsRemastered.exe")):
        return env
    roots = []
    try:
        import winreg
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Software\Valve\Steam") as k:
            steam = winreg.QueryValueEx(k, "SteamPath")[0]
        roots.append(steam)
        vdf = os.path.join(steam, "steamapps", "libraryfolders.vdf")
        if os.path.isfile(vdf):
            with open(vdf, encoding="utf-8", errors="replace") as fh:
                for m in re.finditer(r'"path"\s+"([^"]+)"', fh.read()):
                    roots.append(m.group(1).replace("\\\\", "\\"))
    except Exception:
        pass
    roots += [r"D:\steam\steamapps\common", r"E:\steam\steamapps\common",
              r"F:\steam\steamapps\common", r"C:\Program Files (x86)\Steam\steamapps\common"]
    for r in roots:
        cand = os.path.join(r, "DARK SOULS REMASTERED")
        if os.path.isfile(os.path.join(cand, "DarkSoulsRemastered.exe")):
            return cand
    return r"D:\steam\steamapps\common\DARK SOULS REMASTERED"


class FmgXml:
    """Yabber XML of an FMG: <fmg><entries><text id="...">text</text>..."""

    def __init__(self, path: str):
        self.path = path
        self.tree = ET.parse(path)
        self.root = self.tree.getroot()
        self.entries = {}
        parent = self.root.find("entries")
        if parent is None:
            raise RuntimeError(f"Not a valid FMG XML: {path}")
        for el in parent:
            self.entries[el.attrib.get("id")] = el

    def write(self) -> None:
        self.tree.write(self.path, xml_declaration=True, encoding="utf-8")

    def texts(self) -> dict:
        return {k: (el.text or "") for k, el in self.entries.items()}


# English category name -> FMG filenames (first match wins)
CATEGORY_RULES = [
    ("Dialogue", ["Conversation_.fmg"]),
    ("Cutscene Subtitles", ["Movie_subtitles_.fmg"]),
    ("Dialogue Boxes", ["Dialogue_.fmg"]),
    ("Event Text", ["Event_text_.fmg"]),
    ("Menu Text", ["Menu_general_text_.fmg", "Menu_others_.fmg", "Ingame_menu_.fmg"]),
    ("Key Prompts", ["Key_guide_.fmg"]),
    ("Help Text", ["Item_help_.fmg", "Single_line_help_.fmg"]),
    ("System Messages", ["System_message_win32_.fmg", "System_specific_tags_win32_.fmg"]),
    ("Blood Messages", ["Blood_writing_.fmg"]),
]

DEFAULT_CATEGORIES = {
    "Dialogue": True,
    "Cutscene Subtitles": True,
    "Dialogue Boxes": "off",
    "Event Text": "off",
    "Menu Text": "off",
    "Key Prompts": "off",
    "Help Text": "off",
    "System Messages": "off",
    "Blood Messages": "off",
}

# Widgets that already wrap text keep a newline between the languages
MULTILINE_FMGS = ("Conversation_.fmg", "Movie_subtitles_.fmg", "Event_text_.fmg")


def category_of(fmg: str) -> str:
    for name, names in CATEGORY_RULES:
        if fmg in names:
            return name
    return "Other"


def stem_of(path: str) -> str:
    name = os.path.basename(path)
    for suffix in (".msgbnd.dcx", ".msgbnd"):
        if name.lower().endswith(suffix):
            return name[: -len(suffix)]
    return os.path.splitext(name)[0]


def _mode_value(v) -> str:
    if isinstance(v, dict):
        v = v.get("mode") if v.get("mode") else bool(v.get("enabled", True))
    if isinstance(v, str):
        return v.strip()
    return "append" if v else "off"


def mode_for(cfg: dict, pack: str, fmg: str) -> str:
    """append / off / sec_only. files/ wins over the category table."""
    entry = cfg.get("files", {}).get(stem_of(pack), {}).get("fmg", {})
    for pat, val in entry.items():
        if fnmatch.fnmatchcase(fmg, pat):
            return _mode_value(val)
    cats = cfg.get("categories")
    if cats:
        v = cats.get(category_of(fmg))
        if v is not None:
            return _mode_value(v)
    return "off"


def separator_for(cfg: dict, pack: str, fmg: str) -> str:
    entry = cfg.get("files", {}).get(stem_of(pack), {}).get("fmg", {})
    for pat, val in entry.items():
        if fnmatch.fnmatchcase(fmg, pat) and isinstance(val, dict) and "separator" in val:
            return "\n" if val["separator"] == "\\n" else val["separator"]
    if fmg in MULTILINE_FMGS:
        return "\n"
    sep = cfg.get("separator", "\n")
    return "\n" if sep == "\\n" else sep


def unpack_pack(y: Yabber, src: str, work: str) -> dict:
    """DCX -> msgbnd -> folder. Returns the BND folder, the FMG dir and the msgbnd path."""
    os.makedirs(work, exist_ok=True)
    dcx = os.path.join(work, os.path.basename(src))
    shutil.copy2(src, dcx)
    y.run(y.dcx, dcx)
    msgbnd = dcx[:-4]
    y.run(y.exe, msgbnd)
    bnd = os.path.join(work, os.path.splitext(os.path.basename(msgbnd))[0] + "-msgbnd")
    for root, _dirs, files in os.walk(bnd):
        if any(f.lower().endswith(".fmg") for f in files):
            return {"bnd": bnd, "fmg_dir": root, "msgbnd": msgbnd}
    raise RuntimeError(f"No FMG found after unpacking {src}")


def fmg_names(directory: str) -> list:
    return sorted(f for f in os.listdir(directory) if f.lower().endswith(".fmg"))


def unpack_fmg(y: Yabber, directory: str, fmg: str) -> str:
    xml = os.path.join(directory, fmg + ".xml")
    y.run(y.exe, os.path.join(directory, fmg))
    return xml


def texts_of(y: Yabber, directory: str, fmg: str) -> dict:
    """Read one FMG's entries as {id: text}."""
    return FmgXml(unpack_fmg(y, directory, fmg)).texts()


def build_pack(y: Yabber, cfg: dict, src_dir: str, out: str, pack: str, log,
               keep_work: bool) -> dict:
    primary, secondary = cfg["primary"], cfg["secondary"]
    languages = cfg.get("languages", [primary, secondary])
    top_of = cfg.get("chinese_source", {})
    work_root = os.path.join(out, "_work", stem_of(pack))
    stats = {"pack": pack, "fmg": 0, "entries": 0, "langs": []}

    sec = unpack_pack(y, os.path.join(src_dir, "msg", secondary, pack),
                      os.path.join(work_root, secondary))
    sec_texts = {f: texts_of(y, sec["fmg_dir"], f) for f in fmg_names(sec["fmg_dir"])}
    top_cache = {}

    log(f"[{pack}]")
    for lang in languages:
        tgt = sec if lang == secondary else unpack_pack(
            y, os.path.join(src_dir, "msg", lang, pack), os.path.join(work_root, lang))
        # Language shown on top: the pack's own wording for Chinese slots, otherwise `primary`
        top_lang = top_of.get(lang, secondary if lang == secondary else lang)
        if top_lang == lang:
            top_dir = tgt["fmg_dir"]
        elif top_lang == secondary:
            top_dir = sec["fmg_dir"]
        else:
            top_dir = unpack_pack(y, os.path.join(src_dir, "msg", top_lang, pack),
                                  os.path.join(work_root, top_lang + "_src"))["fmg_dir"]

        changed = 0
        for fmg in fmg_names(tgt["fmg_dir"]):
            mode = mode_for(cfg, pack, fmg)
            if mode == "off":
                continue
            if fmg not in sec_texts:
                log(f"  - skip {fmg} (missing in {secondary})")
                continue
            key = (top_lang, fmg)
            if key not in top_cache:
                top_cache[key] = texts_of(y, top_dir, fmg)
            top = top_cache[key]
            sep = separator_for(cfg, pack, fmg)

            xml = os.path.join(tgt["fmg_dir"], fmg + ".xml")
            y.run(y.exe, os.path.join(tgt["fmg_dir"], fmg))
            x = FmgXml(xml)
            n = 0
            for entry_id, el in x.entries.items():
                a, b = top.get(entry_id), sec_texts[fmg].get(entry_id)
                if is_null(a) or is_null(b) or norm(a) == norm(b):
                    continue
                if mode == "sec_only":
                    if el.text != b:
                        el.text = b
                        n += 1
                    continue
                if is_already_merged(a, b, sep):
                    continue
                el.text = a.rstrip("\n") + sep + b.rstrip("\n")
                n += 1
                if len(el.text) > 400:
                    log(f"  ! {fmg} entry {entry_id} is long after merge ({len(el.text)} chars)")
            if n:
                x.write()
                y.run(y.exe, xml)
                changed += n
                stats["fmg"] += 1
                stats["entries"] += n
                log(f"  + {lang}/{fmg}: {n} entries")
            os.remove(xml)

        if not changed:
            log(f"  = {lang}: nothing to merge, pack skipped")
            continue
        y.run(y.exe, tgt["bnd"])                      # folder -> msgbnd
        y.run(y.dcx, tgt["msgbnd"])                   # msgbnd -> dcx
        dst = os.path.join(out, "msg", lang, pack)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(tgt["msgbnd"] + ".dcx", dst)
        stats["langs"].append(lang)
        log(f"  -> {dst}")

    font = cfg.get("font") or {}
    if font.get("enabled"):
        game = cfg.get("game") or default_game()
        src = os.path.join(game, "font", font.get("source", "schinese"))
        dst_dir = os.path.join(out, "font", font.get("target", secondary))
        os.makedirs(dst_dir, exist_ok=True)
        for f in font.get("files", []):
            shutil.copy2(os.path.join(src, f), os.path.join(dst_dir, f))
        log(f"  -> {dst_dir}")

    if not keep_work:
        shutil.rmtree(work_root, ignore_errors=True)
    return stats


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="DARK SOULS: REMASTERED dual-language text pack builder")
    ap.add_argument("--source", default=None, help="vanilla msg folder (default: the package's source/)")
    ap.add_argument("--out", default=None, help="output folder (default: the package root)")
    ap.add_argument("--game", default=None, help="game folder holding font/ (auto-detected)")
    ap.add_argument("--yabber", default="", help="folder holding Yabber.exe and Yabber.DCX.exe")
    ap.add_argument("--primary", default=None, help="language shown on top (default SCHINESE)")
    ap.add_argument("--secondary", default=None, help="language underneath (default ENGLISH)")
    ap.add_argument("--filter", default=None, help="only build packs whose name matches this wildcard")
    ap.add_argument("--keep-work", action="store_true", help="keep the intermediate files")
    ap.add_argument("--config", default=DEFAULT_CONFIG)
    args = ap.parse_args(argv)

    with open(args.config, encoding="utf-8") as fh:
        cfg = json.load(fh)
    if args.primary:
        cfg["primary"] = args.primary
    if args.secondary:
        cfg["secondary"] = args.secondary
    if args.game:
        cfg["game"] = args.game
    if not cfg.get("game"):
        cfg["game"] = default_game()

    src_dir = args.source or os.path.join(PACK_ROOT, "source")
    if not os.path.isdir(os.path.join(src_dir, "msg")):
        raise SystemExit(f"Text packs not found: {os.path.join(src_dir, 'msg')}\n"
                         "The package ships them in source\\, or pass --source <game folder>.")
    out = args.out or PACK_ROOT
    y = Yabber(args.yabber or cfg.get("yabber_dir") or find_yabber())

    langs = cfg.get("languages", [cfg["primary"], cfg["secondary"]])
    names = [p for p in cfg.get("packs", ["menu.msgbnd.dcx"])
             if all(os.path.isfile(os.path.join(src_dir, "msg", l, p)) for l in langs)]
    if args.filter:
        names = [n for n in names if fnmatch.fnmatchcase(stem_of(n), args.filter)]
    if not names:
        raise SystemExit("No text packs to process")

    t0 = time.time()
    print(f"Source: {src_dir}")
    print(f"Output: {out}")
    print(f"Languages: {cfg['primary']} + {cfg['secondary']} -> {', '.join(langs)}\n")
    total_fmg = total_entries = 0
    for name in names:
        s = build_pack(y, cfg, src_dir, out, name, print, args.keep_work)
        total_fmg += s["fmg"]
        total_entries += s["entries"]
        print()
    print(f"Done: {len(names)} pack(s), {total_fmg} FMGs, {total_entries} entries, "
          f"in {time.time() - t0:.1f}s")
    print(f"Mod files in: {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
