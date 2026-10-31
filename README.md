# Wherefrom

A World of Warcraft addon that answers the question every full bag raises sooner or
later: **where did this come from?**

Hover an item and the tooltip gains a provenance block — where *you* got this copy, which
boss drops it, and what the game itself knows about its origin.

```
Venom-Cursed Fragment
Soulbound
Use: Combine two fragments to create a Champion Venom-Cursed item ...

Obtained                                          Nexus-King Salhadaar
   Manaforge Omega (Mythic) - 18.09.2026 - Rosalita
Drops from                     Nexus-King Salhadaar (Manaforge Omega)
```

## What it knows, and how

The addon answers from three sources, each of which can be switched off on its own.

**Where you got it.** From the moment Wherefrom is installed it watches items entering
your bags and records what you were doing at that instant. It tells apart creature loot,
chests and gathering nodes, containers you opened, quest rewards, vendors, mail, the
auction house, crafting, player trades and the guild bank — and falls back to naming the
zone when nothing more specific fits. Each record keeps the place, the date and the
character, and it is stored account-wide, so an alt's find still has an answer months
later.

This half only knows what it has seen. It learns from the day you install it.

**Which boss drops it.** Once per game build the addon walks the Adventure Guide and maps
every encounter's loot table back to its boss and instance. That covers what was already
in your bags before it was ever installed, for anything that drops in a dungeon or raid.
The scan is spread across frames so it does not stall the client, and the result is
cached until the next patch. `/wf index` rebuilds it on demand; an option widens it from
the current expansion to all of them, at a real cost in time and file size.

**The game's own source text.** Mounts, battle pets and heirlooms carry a source line
Blizzard wrote, and transmog files every appearance under a category — boss drop, quest,
vendor, world drop and so on. It is shown when the drop index has nothing more precise.

No external database, no web lookups, no libraries: everything comes out of the client.

## Commands

| Command | What it does |
| --- | --- |
| `/wf` | open the options |
| `/wf status` | how much is recorded and indexed |
| `/wf index` | rebuild the drop index from the Adventure Guide |
| `/wf forget [item]` | drop what is recorded for one item (shift-click it in) |
| `/wf reset confirm` | forget every recorded item |

## Installation

Download the latest release from <https://github.com/lasse-tech/wherefrom/releases> and
drop the `Wherefrom` folder into `World of Warcraft/_retail_/Interface/AddOns`.

From a clone:

```sh
make install     # copy into the live client
make lint        # luacheck, TOC, locale, ruff and Makefile checks
make test        # run tests/ headless in wow-ui-sim
make help        # every target
```

`make install` finds the client on its own; `WOW_RETAIL_ADDON_FOLDER=/path/to/Interface/AddOns`
overrides it.

## Language

German and English, following the client's language. Other locales fall back to English —
`Locales/enUS.lua` is the full key list to translate from, and `make lint` fails on any
key a locale is missing.

## Licence

MIT — see [LICENSE](LICENSE). © 2026 lasse tech, Lars Gossard.
