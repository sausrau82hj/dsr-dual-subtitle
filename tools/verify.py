#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Verify the built packs against the vanilla ones in source\\.

Per language, checks that:
  - the pack still holds the same FMG set and the same entry ids
  - every entry the config merges equals top language + separator + secondary language
  - every other entry and every FMG left alone is byte-identical to vanilla
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dualsub import (DEFAULT_CONFIG, PACK_ROOT, Yabber, find_yabber,  # noqa: E402
                     fmg_names, is_null, mode_for, norm, separator_for,
                     stem_of, texts_of, unpack_pack)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="verify built DSR dual-language packs")
    ap.add_argument("--source", default=None, help="vanilla msg folder (default: the package's source/)")
    ap.add_argument("--pack-dir", default=PACK_ROOT)
    ap.add_argument("--config", default=DEFAULT_CONFIG)
    ap.add_argument("--yabber", default="")
    args = ap.parse_args(argv)

    with open(args.config, encoding="utf-8") as fh:
        cfg = json.load(fh)
    y = Yabber(args.yabber or cfg.get("yabber_dir") or find_yabber())
    src_dir = args.source or os.path.join(PACK_ROOT, "source")
    secondary = cfg["secondary"]
    languages = cfg.get("languages", [cfg["primary"], secondary])
    errors, merged_total = [], 0
    tmp = tempfile.mkdtemp(prefix="dsr-verify-")
    counter = {"n": 0}

    def unpack(which, lang, pack):
        counter["n"] += 1
        return unpack_pack(y, os.path.join(which, "msg", lang, pack),
                           os.path.join(tmp, f"w{counter['n']}"))["fmg_dir"]

    try:
        for pack in cfg.get("packs", ["menu.msgbnd.dcx"]):
            van, built = {}, {}
            for lang in languages:
                van[lang] = unpack(src_dir, lang, pack)
                built[lang] = unpack(args.pack_dir, lang, pack)
            sec_texts = {f: texts_of(y, van[secondary], f) for f in fmg_names(van[secondary])}

            for lang in languages:
                top_lang = cfg.get("chinese_source", {}).get(
                    lang, secondary if lang == secondary else lang)
                print(f"[{lang}] top={top_lang}")
                b_names, v_names = set(fmg_names(built[lang])), set(fmg_names(van[lang]))
                if b_names != v_names:
                    errors.append(f"{lang}: FMG set differs: {sorted(b_names ^ v_names)}")
                for fmg in sorted(b_names & v_names):
                    mode = mode_for(cfg, pack, fmg)
                    if mode == "off":
                        if open(os.path.join(built[lang], fmg), "rb").read() != \
                                open(os.path.join(van[lang], fmg), "rb").read():
                            errors.append(f"{lang}/{fmg}: untouched FMG changed")
                        continue
                    bt = texts_of(y, built[lang], fmg)
                    vt = texts_of(y, van[lang], fmg)
                    if set(bt) != set(vt):
                        errors.append(f"{lang}/{fmg}: entry ids differ")
                        continue
                    top = texts_of(y, van[top_lang], fmg)
                    sep = separator_for(cfg, pack, fmg)
                    n = 0
                    for key, original in vt.items():
                        a, b = top.get(key), sec_texts[fmg].get(key)
                        if is_null(a) or is_null(b) or norm(a) == norm(b):
                            expected = original
                        elif mode == "sec_only":
                            expected = b
                        else:
                            expected = a.rstrip("\n") + sep + b.rstrip("\n")
                        if bt[key] != expected:
                            # Yabber drops whitespace-only text nodes when it repacks an FMG,
                            # so a blank entry can come back as an empty string
                            if expected.strip() == '' and bt[key].strip() == '':
                                n += 1 if expected != original else 0
                                continue
                            errors.append(f"{lang}/{fmg}: entry {key} mismatch\n"
                                          f"    got      {bt[key]!r}\n"
                                          f"    expected {expected!r}")
                            break
                        if expected != original:
                            n += 1
                    merged_total += n
                    print(f"  {fmg}: {n} merged of {len(vt)} entries")
                print(f"  {pack}: {len(b_names)} FMGs ok")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    print()
    if errors:
        print(f"FAILED ({len(errors)}):")
        for e in errors[:20]:
            print(" -", e)
        return 1
    print(f"ALL OK — {merged_total} merged entries across {len(languages)} languages")
    return 0


if __name__ == "__main__":
    sys.exit(main())
