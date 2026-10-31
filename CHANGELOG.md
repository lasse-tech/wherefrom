# Changelog

All notable changes to Wherefrom are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-10-31

First release.

### Added
- **A provenance block in every item tooltip.** Up to three lines, each of which can be
  switched off on its own: where you got this copy, which boss drops it, and the game's
  own source text.
- **Acquisition tracking.** From the moment it is installed, the addon records where each
  item entered your bags and remembers it account-wide, so an alt's find is still
  answered months later. It tells apart creature loot, world objects, containers, quest
  rewards, vendors, mail, the auction house, crafting, player trades and the guild bank,
  and falls back to the zone when it can name nothing more specific. Every record carries
  the place, the date and the character. Worn gear counts alongside the bags and the bank
  is skipped entirely, so taking a weapon off or emptying a bank slot is not mistaken for
  acquiring something.
- **A drop index built from the Adventure Guide.** One throttled scan per game build
  walks every encounter of the current expansion and maps its loot back to boss and
  instance, so items that were already in your bags before the addon existed still get an
  answer. `/wf index` rebuilds it; an option widens it to every expansion.
- **The client's own source text** for mounts, battle pets and heirlooms, and the transmog
  source category for anything wearable - shown when the drop index has nothing more
  precise to say.
- Slash commands: `/wf` for the options, `/wf status`, `/wf index`, `/wf forget [item]`
  and `/wf reset confirm`.
- German and English, following the client's language.
- **No taint.** Patch 12.0 restricts the combat log, so creature names come from the
  player's target and mouseover, the corpse being looted included. Nothing is stored on
  Blizzard's frames or created on `UIParent`, so the client never blocks a protected action
  on account of this addon.

