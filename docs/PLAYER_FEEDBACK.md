# Player Feedback Handling

This note tracks the first gameplay pain points targeted by the tuner.

## Repeated Voice Lines And Greetings

Pain point:

- nearby bots repeatedly greet/emote around the player
- this becomes especially noticeable during leveling

Tuner response:

- all practical presets disable greet spam
- random bot emotes are disabled
- masterless random bot say lines are disabled

Config:

```ini
AiPlayerbot.EnableGreet = 0
AiPlayerbot.RandomBotEmote = 0
AiPlayerbot.RandomBotSayWithoutMaster = 0
```

## Follow Lost After Death Or Resurrection

Pain point:

- bots sometimes lose follow state after the player dies and resurrects

Tuner response:

- `solo-controller`, `dungeon-lfg`, and `living-server` keep summon/revive support enabled
- docs and macro output recommend `/p follow` as a fast recovery command
- future source patch candidate: re-assert follow for grouped bots after master resurrection

Useful command:

```text
/p follow
```

## Party Disbands Or Changes On Relog

Pain point:

- after relog, existing random-bot party may disband or partially persist

Current assessment:

- this appears tied to random bot lifecycle and randomization
- config can improve comfort, but should not promise stable random-bot party persistence
- altbots/addclass bots are better for stable long-session parties

Tuner response:

- `doctor` prints a note explaining the limitation
- no automatic patch in v1

## Holding Bots At A Spot

Pain point:

- some quests require careful control instead of bots destroying every enemy

Tuner response:

- `print-macros` includes the existing Playerbots `stay` command
- `solo-controller` increases follow distance slightly so bots are less glued to the player

Useful command:

```text
/p stay
```

To resume:

```text
/p follow
```
