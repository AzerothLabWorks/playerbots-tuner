# Playerbots Tuner

Standalone tuning and patch helper for AzerothCore servers using `mod-playerbots`.

The goal is to make Playerbots easier to customize on an existing server without
requiring a full prebuilt server distribution. The tuner focuses on two kinds of
changes:

- config tuning that only needs an `ac-worldserver` restart
- optional source patches that need an `ac-worldserver` rebuild

## What It Tunes

Phase 1 config tuning includes:

- quiet greetings and reduced repeated emotes
- solo/controller-friendly party behavior
- random bot population and level range
- LFG participation and dungeon strategy defaults
- tank/healer-biased random bot specs for dungeon queues
- conservative level-80 rated 3v3 arena seeding
- Docker Compose environment override alignment
- diagnostics for LFG/PvP settings and recent logs

Phase 2 patch support includes:

- accepting LFG proposals even when bots are busy, dead, or in combat
- retrying native LFG dungeon teleport when an accepted bot remains outside

## Quick Start

From this repo:

```bash
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots apply-preset solo-controller --dry-run
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots apply-preset solo-controller --restart
```

For dungeon-focused tuning:

```bash
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots apply-preset dungeon-lfg --restart
```

To apply the optional LFG reliability patches:

```bash
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots apply-patches lfg --rebuild
```

## Presets

`quiet-social`

Disables repeated nearby greetings and random emote noise while preserving useful
bot talk and broadcasts.

`solo-controller`

Quiet, low-friction leveling defaults for players who use a controller or want
party bots to be easier to recover after death, summon, or movement drift.

`dungeon-lfg`

The current Azeroth Lab Works dungeon baseline: online random bots, level-synced
leveling density, LFG participation, instance strategies, summon-on-group, and
role-biased tank/healer specs.

`pvp-3v3`

Conservative level-80 rated 3v3 seeding.

`living-server`

Combines dungeon, PvP, and quiet social defaults.

## Useful Commands

```bash
./scripts/playerbots-tuner.sh list-presets
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots doctor
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots diagnose-lfg
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots diagnose-pvp
./scripts/playerbots-tuner.sh print-macros
```

## Safety

Before editing an existing config or Docker override, the script creates a
timestamped backup next to the file:

```text
playerbots.conf.bak.YYYYMMDD-HHMMSS
docker-compose.override.yml.bak.YYYYMMDD-HHMMSS
```

Use `--dry-run` to preview file changes and Docker actions.

## Restart vs Rebuild

Restart-only changes:

- presets
- bot counts
- level ranges
- LFG/PvP config
- chat/greeting behavior
- follow distance
- role/spec probability tuning

Rebuild-required changes:

- `apply-patches lfg`
- any future C++ behavior patch

## Player Feedback Notes

Repeated voice lines/greetings are handled by the quiet presets:

```ini
AiPlayerbot.EnableGreet = 0
AiPlayerbot.RandomBotEmote = 0
AiPlayerbot.RandomBotSayWithoutMaster = 0
```

If bots lose follow after player death/resurrection, use:

```text
/p follow
```

To make bots hold position for quest objectives:

```text
/p stay
```

Party persistence after relog is more complicated for roaming random bots. For
stable long-session party play, prefer altbots or addclass bots where possible.

## Requirements

- Bash
- Git
- Docker Compose for restart/rebuild/diagnostic log actions
- An AzerothCore Playerbots server using `mod-playerbots`

The standard AzerothCore repository is not enough for Playerbots; `mod-playerbots`
requires the Playerbots-compatible AzerothCore fork.
