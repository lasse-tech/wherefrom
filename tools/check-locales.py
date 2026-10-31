#!/usr/bin/env python3
"""Verify that every L["..."] the code asks for exists in every locale.

A missing entry is not cosmetic: the fallback metatable hands the key back, so
the player reads an English sentence - or worse, a format string - where a
translated one belongs. An entry no line of code asks for is dead weight that
outlives whatever used to need it. Both are errors here.
"""

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CODE_DIRS = ("Core", "UI")
LOCALES = ("enUS", "deDE")

KEY = re.compile(r'L\["((?:[^"\\]|\\.)*)"\]')
# The slash-command help feeds its table entries through L[line].
HELP_LINE = re.compile(r'^\s*"(/wf [^"]*)",', re.MULTILINE)


def wanted() -> list[str]:
    keys, seen = [], set()
    for directory in CODE_DIRS:
        for path in sorted((ROOT / directory).glob("*.lua")):
            text = path.read_text(encoding="utf-8")
            for match in list(KEY.finditer(text)) + list(HELP_LINE.finditer(text)):
                key = match.group(1)
                if key not in seen:
                    seen.add(key)
                    keys.append(key)
    return keys


def provided(locale: str) -> set[str]:
    path = ROOT / "Locales" / f"{locale}.lua"
    return set(KEY.findall(path.read_text(encoding="utf-8")))


def main() -> int:
    keys = wanted()
    failed = False

    for locale in LOCALES:
        have = provided(locale)
        missing = [k for k in keys if k not in have]
        extra = sorted(k for k in have if k not in keys)

        for key in missing:
            print(f"  MISSING  {locale}: {key!r}")
        for key in extra:
            print(f"  UNUSED   {locale}: {key!r}")

        failed = failed or bool(missing) or bool(extra)

    if failed:
        return 1

    print(f"locales: {len(keys)} keys, {', '.join(LOCALES)} complete")
    return 0


if __name__ == "__main__":
    sys.exit(main())
