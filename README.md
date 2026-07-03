# Playerbots Tuner

Standalone tuning and patch helper for AzerothCore servers using `mod-playerbots`.

This repo is for server owners who already have a Playerbots-compatible
AzerothCore server and want to apply Azeroth Lab Works-style Playerbots tuning
without installing our full server build.

The tuner focuses on two kinds of changes:

- config tuning that only needs an `ac-worldserver` restart
- optional source patches that need an `ac-worldserver` rebuild

## Development Status

This project is under active development and should be considered experimental.
It has safeguards such as `--dry-run`, timestamped config backups, confirmation
prompts, and `restore-latest`, but every server install is a little different.

Review the dry-run output before applying changes, keep your own server and
database backups, and test on a non-production copy first when possible.

## Important Compatibility Note

The standard AzerothCore repository is not enough for Playerbots. `mod-playerbots`
requires the Playerbots-compatible AzerothCore fork and the `mod-playerbots`
module installed in your server source tree.

This tool expects a server folder that looks roughly like this:

```text
your-server-folder/
  docker-compose.yml
  modules/
    mod-playerbots/
      conf/
        playerbots.conf.dist
```

Some installs may store the runtime config here instead:

```text
your-server-folder/env/dist/etc/modules/playerbots.conf
```

The tuner checks common locations automatically.

## What It Tunes

Phase 1 config tuning includes:

- quiet greetings and reduced repeated emotes
- solo/controller-friendly party behavior
- random bot population and level range
- LFG participation and dungeon strategy defaults
- battleground progression brackets for Warsong Gulch, Arathi Basin, Eye of the Storm, Alterac Valley, and Isle of Conquest
- tank/healer-biased random bot specs for dungeon queues
- conservative level-80 rated 3v3 arena seeding
- Docker Compose environment override alignment
- diagnostics for LFG/PvP settings and recent logs
- restore from the latest tuner-created backup

Phase 2 patch support includes:

- accepting LFG proposals even when bots are busy, dead, or in combat
- retrying native LFG dungeon teleport when an accepted bot remains outside

## Requirements

- Bash
- Git
- Docker Compose if you want the tuner to restart, rebuild, or read logs
- An AzerothCore Playerbots server using `mod-playerbots`

On Linux, Steam Deck, and WSL, Bash and Git are usually enough to run the script.
Docker Compose is only required for commands such as `--restart`, `--rebuild`,
`diagnose-lfg`, and `diagnose-pvp`.

## Step 1: Open A Terminal

Use the terminal environment where you normally manage your server.

For WSL on Windows:

```bash
wsl
```

Then work from your Linux home folder, for example:

```bash
cd ~
```

For Steam Deck desktop mode:

1. Switch to Desktop Mode.
2. Open the Konsole terminal.
3. Work from your home folder:

```bash
cd ~
```

For a normal Linux server:

```bash
cd ~
```

## Step 2: Download The Tuner

Recommended method:

```bash
git clone https://github.com/AzerothLabWorks/playerbots-tuner.git
cd playerbots-tuner
```

To update later:

```bash
cd ~/playerbots-tuner
git pull
```

If you do not have Git, download the ZIP from GitHub:

```text
https://github.com/AzerothLabWorks/playerbots-tuner
```

Click `Code`, then `Download ZIP`, extract it, and open a terminal inside the
extracted folder.

## Step 3: Find Your Server Directory

The `--server-dir` value must point to your Playerbots server source/install
folder, not to this tuner repo.

Examples:

```bash
~/wow-server-playerbots
~/wow-server-playerbots-hybrid
~/azerothcore-wotlk
~/azerothcore-playerbots
```

You can verify a likely folder with:

```bash
ls ~/wow-server-playerbots
ls ~/wow-server-playerbots/modules/mod-playerbots
ls ~/wow-server-playerbots/docker-compose.yml
```

If your folder has `modules/mod-playerbots`, you are probably pointing at the
right place.

On WSL, avoid pointing the tuner at a Windows path unless your server actually
lives there. A Linux-side server path is usually better:

```bash
~/wow-server-playerbots
```

rather than:

```bash
/mnt/c/Users/YourName/Desktop/wow-server-playerbots
```

On Steam Deck, your server may be under your home folder, for example:

```bash
~/wow-server-playerbots
~/Games/wow-server-playerbots
```

Use the exact path that contains your `docker-compose.yml` and `modules` folder.

## Step 4: Run A Safety Check

From inside the `playerbots-tuner` folder:

```bash
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots doctor
```

If your server is somewhere else, change the path:

```bash
./scripts/playerbots-tuner.sh --server-dir ~/YOUR-SERVER-FOLDER doctor
```

`doctor` prints the Playerbots config it found, Docker override values, and
notes about common gameplay behavior such as greetings, follow recovery, and
random bot party persistence.

For a deeper compatibility check against your installed Playerbots version:

```bash
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots compat-check
```

`compat-check` is read-only. It reports:

- the detected `mod-playerbots` branch, commit, and remote when available
- whether important config keys are present
- whether the Docker override exists
- whether bundled source patches are applicable, already applied, or incompatible

Patch status meanings:

- `applicable`: the patch should apply cleanly.
- `already-applied`: the patch appears to already be present.
- `incompatible`: the patch does not match this Playerbots source tree and needs
  review before use.

If `compat-check` reports incompatible patches, config presets may still be safe
to use, but do not run `apply-patches lfg` until the patch mismatch is reviewed.

## Step 5: Preview Changes First

Always run `--dry-run` first. This prints what the tuner would change without
editing files or restarting anything.

Solo/controller-friendly leveling:

```bash
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots --dry-run apply-preset solo-controller
```

Dungeon/LFG-focused tuning:

```bash
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots --dry-run apply-preset dungeon-lfg
```

Living server defaults:

```bash
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots --dry-run apply-preset living-server
```

## Step 6: Apply A Preset

When the dry run looks correct, run the same command without `--dry-run`.

Solo/controller-friendly leveling:

```bash
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots apply-preset solo-controller
```

Dungeon/LFG-focused tuning:

```bash
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots apply-preset dungeon-lfg
```

Living server defaults:

```bash
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots apply-preset living-server
```

Progression battleground tuning:

```bash
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots apply-preset pvp-bg-progression
```

To apply and restart `ac-worldserver` in one command:

```bash
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots apply-preset dungeon-lfg --restart
```

If you want fewer bots than the default dungeon preset:

```bash
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots apply-preset dungeon-lfg --bots 800 --restart
```

You can also choose a named population size:

```bash
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots apply-preset dungeon-lfg --population low --restart
```

Or set separate minimum and maximum online random bot counts:

```bash
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots apply-preset dungeon-lfg --min-bots 300 --max-bots 900 --restart
```

## Step 7: Optional LFG Reliability Patches

Config presets only require a worldserver restart. The optional LFG reliability
patches change C++ source files in `modules/mod-playerbots`, so they require a
worldserver rebuild.

Preview first:

```bash
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots --dry-run apply-patches lfg
```

Apply patches:

```bash
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots apply-patches lfg
```

Apply patches and rebuild:

```bash
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots apply-patches lfg --rebuild
```

The script checks whether each patch can apply cleanly, is already applied, or
cannot be applied to your installed `mod-playerbots` version.

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

`pvp-bg-progression`

Conservative battleground auto-join across leveling brackets. Enables Warsong
Gulch, Arathi Basin, and Eye of the Storm across their configured progression
brackets, while leaving Alterac Valley and Isle of Conquest at their endgame
brackets with zero auto-created battles by default to avoid large over-queueing.

`pvp-bg-all`

Enables all configured battleground brackets with one auto-created battle per
bracket. This is intended for stronger hosts and larger bot populations only.
Use `--dry-run` first and monitor server performance.

`pvp-3v3`

Conservative level-80 rated 3v3 seeding.

`living-server`

Combines dungeon, PvP, and quiet social defaults.

Show presets:

```bash
./scripts/playerbots-tuner.sh list-presets
```

Show population sizes:

```bash
./scripts/playerbots-tuner.sh list-populations
```

## Bot Population And Performance

Random bot count has a direct effect on CPU, memory, database activity, and
worldserver startup time. More bots can make the world feel alive and improve
queue density, but lower-powered systems may need a smaller population.

The tuner supports three ways to control bot count:

```bash
--population tiny|low|medium|high|very-high
--bots N
--min-bots N --max-bots N
```

Named population sizes:

| Population | Bot Count | Suggested Use |
|---|---:|---|
| `tiny` | 100 | Basic testing, very low-resource systems |
| `low` | 300 | Steam Deck, small private servers, older CPUs |
| `medium` | 800 | General use on modest desktop/server hardware |
| `high` | 1500 | Azeroth Lab Works dungeon-density baseline |
| `very-high` | 2500 | Strong hosts only; test carefully |

Simple exact count:

```bash
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots apply-preset dungeon-lfg --bots 500 --restart
```

Separate minimum and maximum:

```bash
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots apply-preset dungeon-lfg --min-bots 300 --max-bots 900 --restart
```

If you are not sure where to start:

- Steam Deck or low-end host: start with `--population low`
- Average desktop/server: start with `--population medium`
- Dungeon/LFG-focused server with good resources: try `--population high`

Always test with `--dry-run` first:

```bash
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots --dry-run apply-preset dungeon-lfg --population low
```

The script writes both:

```ini
AiPlayerbot.MinRandomBots = N
AiPlayerbot.MaxRandomBots = N
```

and Docker Compose environment overrides:

```yaml
AC_AI_PLAYERBOT_MIN_RANDOM_BOTS: "N"
AC_AI_PLAYERBOT_MAX_RANDOM_BOTS: "N"
```

unless you use `--skip-compose`.

## Battleground And Arena Progression

Battleground progression can be improved with config-only tuning. The tuner now
includes:

```bash
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots apply-preset pvp-bg-progression --restart
```

This sets:

```ini
AiPlayerbot.RandomBotJoinBG = 1
AiPlayerbot.RandomBotAutoJoinBG = 1
AiPlayerbot.RandomBotAutoJoinWSBrackets = 0,1,2,3,4,5,6,7
AiPlayerbot.RandomBotAutoJoinABBrackets = 0,1,2,3,4,5,6
AiPlayerbot.RandomBotAutoJoinAVBrackets = 3
AiPlayerbot.RandomBotAutoJoinEYBrackets = 0,1,2
AiPlayerbot.RandomBotAutoJoinICBrackets = 1
AiPlayerbot.RandomBotAutoJoinBGWSCount = 1
AiPlayerbot.RandomBotAutoJoinBGABCount = 1
AiPlayerbot.RandomBotAutoJoinBGAVCount = 0
AiPlayerbot.RandomBotAutoJoinBGEYCount = 1
AiPlayerbot.RandomBotAutoJoinBGICCount = 0
```

The tuner writes these exact `playerbots.conf` keys. It also writes best-effort
Docker Compose environment overrides for matching `AC_AI_PLAYERBOT_*` names.
If your Docker image uses different environment mapping, verify the final
runtime values with `diagnose-pvp`.

This is intentionally conservative:

- Warsong Gulch is available across its leveling brackets.
- Arathi Basin is available across its leveling brackets.
- Eye of the Storm is available across its leveling brackets.
- Alterac Valley and Isle of Conquest stay configured but do not auto-create
  extra battles by default because they are larger and more resource-heavy.

For stronger hosts, this enables all configured battleground brackets with one
auto-created battle per bracket:

```bash
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots apply-preset pvp-bg-all --restart
```

Arena progression is different. The upstream Playerbots config currently notes
that lower-level rated arena brackets require custom code changes. For that
reason, this tuner keeps arena automation conservative and level-80 focused for
now through:

```bash
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots apply-preset pvp-3v3 --restart
```

Lower-level arena support should be treated as future source-patch work rather
than a safe config-only preset.

## Useful Commands

```bash
./scripts/playerbots-tuner.sh list-presets
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots doctor
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots compat-check
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots diagnose-lfg
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots diagnose-pvp
./scripts/playerbots-tuner.sh print-macros
```

## Backups And Restore

Before editing an existing config or Docker override, the script creates a
timestamped backup next to the file:

```text
playerbots.conf.bak.YYYYMMDD-HHMMSS
docker-compose.override.yml.bak.YYYYMMDD-HHMMSS
```

Preview restore:

```bash
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots --dry-run restore-latest
```

Restore the latest tuner-created backups:

```bash
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots restore-latest
```

Restore and restart `ac-worldserver`:

```bash
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots restore-latest --restart
```

Use `--yes` if you want to skip confirmation prompts:

```bash
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots restore-latest --restart --yes
```

`restore-latest` restores the newest backup for:

- `playerbots.conf`
- `docker-compose.override.yml`

It does not reset Git patches. If you applied C++ patches and want to remove
them, use normal Git tools in your server repo or restore your server source from
your own backup.

## Restart vs Rebuild

Restart-only changes:

- presets
- bot counts
- level ranges
- LFG/PvP config
- chat/greeting behavior
- follow distance
- role/spec probability tuning
- restoring config backups

Rebuild-required changes:

- `apply-patches lfg`
- any future C++ behavior patch

## WSL Notes

Recommended flow:

```bash
wsl
cd ~
git clone https://github.com/AzerothLabWorks/playerbots-tuner.git
cd playerbots-tuner
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots doctor
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots --dry-run apply-preset dungeon-lfg
```

If your Docker Desktop integration is enabled for WSL, `--restart`, `--rebuild`,
and diagnostics should work from WSL. If Docker commands fail, run:

```bash
docker compose version
docker ps
```

If those fail too, fix Docker/WSL integration before using tuner commands that
need Docker.

## Steam Deck Notes

Steam Deck runs SteamOS, which is Linux-based. The tuner should be run from
Desktop Mode using Konsole.

Recommended flow:

```bash
cd ~
git clone https://github.com/AzerothLabWorks/playerbots-tuner.git
cd playerbots-tuner
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots doctor
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots --dry-run apply-preset solo-controller
```

Steam Deck users may have servers installed under custom folders such as:

```bash
~/Games/wow-server-playerbots
~/Servers/wow-server-playerbots
```

Use the folder that contains `docker-compose.yml` and `modules/mod-playerbots`.

If Docker is not installed or not running on the Steam Deck, you can still use
the tuner to edit config files, but `--restart`, `--rebuild`, and log diagnostics
will not work until Docker Compose is available.

## In-Game Bot Commands

Playerbots respond to in-game chat commands. You do not run these commands in
the Linux terminal. Run them inside the WoW client chat box while logged into
your character.

The command target depends on where you type it:

- `/p command` sends the command to bots in your party.
- `/r command` sends the command to bots in your raid.
- `/w BotName command` sends the command to one specific bot.
- GM-style `.playerbots ...` commands are typed in chat and require the correct
  server permissions.

Examples:

```text
/p follow
/p stay
/w Somebot follow
/w Somebot stay
```

The most useful starter commands are:

```text
/p follow
```

Re-asserts follow for party bots. This is useful after death, resurrection,
summon, teleport, pathing drift, or a relog/reinvite situation.

```text
/p stay
```

Makes party bots hold their current position. This is useful when a quest needs
you to use an item, tag a target, wait for an event, or avoid instantly killing
everything nearby.

```text
/p attack
```

Commands bots to attack your selected target.

```text
/p flee
```

Calls bots back toward you while trying to ignore other distractions.

```text
/p summon
```

Asks bots to summon/teleport to you when supported by your Playerbots config.

```text
/p release
/p revive
```

Useful after wipes or deaths near a spirit healer.

```text
/p reset
```

Resets bot actions and state. This can help if bots get stuck trying to cast,
move, loot, or follow an old order.

```text
/p follow near
/p follow far
/p follow info
```

Adjusts or checks follow spacing.

```text
/p orders delay 5
```

Makes bots wait before engaging. This can help with quests that need controlled
damage or setup time.

Some commands can target subsets of bots. For example:

```text
/p @tank follow
/p @heal stay
/p @dps attack
/p @group1 follow
```

The full upstream command reference is available in the
[mod-playerbots Playerbot Commands wiki](https://github.com/mod-playerbots/mod-playerbots/wiki/Playerbot-Commands).

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
