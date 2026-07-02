# Useful In-Game Bot Commands

Playerbots respond to in-game chat commands. Type these commands inside the WoW
client chat box while logged into your character.

Command target:

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

## Recover Follow

```text
/p follow
```

Re-asserts follow after death, resurrection, summon, or pathing drift.

## Hold Position

```text
/p stay
```

Keeps bots where they are. Useful for quest objectives that require controlled
damage or not killing everything immediately.

## Follow Spacing

```text
/p follow near
/p follow far
/p follow info
```

Adjusts or checks follow spacing.

## Slower Engagement

```text
/p orders delay 5
```

Makes bots wait before engaging. This can help with quests that need tagging,
using an item, or waiting for an event phase.

## Reset Bot State

```text
/p reset
```

Resets bot states, orders, and loot list.

## Attack And Recovery

```text
/p attack
/p flee
/p summon
/p release
/p revive
```

Common use:

- `attack` tells bots to attack your selected target.
- `flee` calls bots back toward you while trying to ignore distractions.
- `summon` asks bots to summon/teleport to you when supported by config.
- `release` and `revive` help recover after deaths and wipes.

## Targeting Bot Subsets

Some commands can target roles, groups, or classes:

```text
/p @tank follow
/p @heal stay
/p @dps attack
/p @group1 follow
```

For the full command reference, see:

```text
https://github.com/mod-playerbots/mod-playerbots/wiki/Playerbot-Commands
```
