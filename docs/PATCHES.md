# Patch Sets

## `apply-patches lfg`

Applies two optional patches to `modules/mod-playerbots`.

### `0001-accept-lfg-proposals-while-busy.patch`

Removes code that explicitly declines an LFG proposal just because a bot is in
combat or dead. This targets the case where one questing bot collapses the whole
group proposal.

### `0002-retry-lfg-dungeon-teleport.patch`

Adds a lightweight LFG dungeon teleport trigger that retries the existing native
`lfg teleport` action every 10 seconds when a bot is in an LFG dungeon group but
is still outside the dungeon.

The trigger skips bots that are:

- dead
- in combat
- in a battleground or arena
- already teleporting
- already inside a dungeon map

## Applying

```bash
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots apply-patches lfg --rebuild
```

The script checks whether each patch applies cleanly, is already applied, or
cannot be applied. Patch changes require rebuilding `ac-worldserver`.

## Compatibility

The patch files are intentionally small, but `mod-playerbots` changes quickly.
If a patch fails, inspect the target files in the installed module and either
port the patch manually or wait for a tuner patch update.

## `apply-patches arena-lower-brackets`

Experimental patch set for lower-level rated arena brackets.

Upstream Playerbots config currently notes that lower-level arena brackets
require custom code changes. This patch changes random bot arena team creation,
team filling, and queue gathering to use the configured
`AiPlayerbot.RandomBotAutoJoinArenaBracket` level range instead of hardcoded
level 70+ checks.

Apply:

```bash
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots apply-patches arena-lower-brackets --rebuild
```

Then configure the experimental 2v2 preset:

```bash
./scripts/playerbots-tuner.sh --server-dir ~/wow-server-playerbots apply-preset pvp-arena-2v2-experimental --arena-bracket 2 --restart
```

Treat this as experimental and test on a non-production copy first.
