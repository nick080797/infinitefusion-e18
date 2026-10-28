# RPG Maker XP Walkthrough — Placing DBZ Trainer NPCs

This project (`InfiniteFusion.rxproj`, same folder as `Game.exe`) is a standard RPG Maker XP project. Open that `.rxproj` file to load it.

## The layout
- **Left panel**: list of all maps (matches the game's in-game location names).
- **Center**: the map itself as a tile grid. Events (NPCs, trainers, signs) are drawn as their sprite. Scroll/zoom with the mouse wheel.
- **Right panel** (when a map is open): tileset palette — not needed for this task, you're placing events, not drawing tiles.

## Opening a map
Double-click a map name in the left tree.

## Identifying a trainer event
Trainer sprites look like any other NPC — you can't tell by appearance alone. Double-click the sprite to open its **Event editor**. A trainer event has a **Script** command (not a plain "Comment") reading something like:
```
pbTrainerBattle(:SUPERNERD,"Miguel",_INTL("..."),false,0)
```
The first argument is the TrainerType, the second is the Name, and the 5th positional number (`trainerPartyID`, default `0`) is the trainer's **version** — this is the number that picks which party they use.

## Cloning a trainer to place a new NPC next to it
1. Right-click the existing trainer's tile → **Copy Event** (Ctrl+C).
2. Right-click the destination tile → **Paste Event** (Ctrl+V). This clone carries over the same graphic, movement, and event commands — including the Script command above — so you don't need to retype it.
3. Double-click the new event → open the page with the Script command → double-click that Script command line → change ONLY the `trainerPartyID` number (the 5th argument) to the new version number (e.g. `900`). Leave the TrainerType and Name exactly as they are — that's what makes it battle the new party instead of the original.
4. If you want the new NPC to look distinct (different sprite), change the **Graphic** on that same page.
5. Click OK, then save (Ctrl+S for the map, or File → Save Project for everything).

## Placing a stationary NPC at a patrol route's end
1. Open the patrolling trainer's event, look at its page's **Move Route** (a list like "Move Down x3, Move Up x3, repeat") to see the path.
2. Walk that path visually on the map to find the tile where it turns around — that's the endpoint.
3. Copy the trainer event, paste at that endpoint tile, then on the pasted event's page set **Move Type** to **Fixed** (so this clone doesn't also patrol) and update the `trainerPartyID` as in step 3 above.

## Avoiding walls/water
Menu → **View** → toggle **Show/Hide Passability**. Impassable tiles get a red X overlay — don't place a trainer there. Also avoid tiles another event already occupies.

## Undo / safety
Ctrl+Z undoes per-map. Nothing is written to disk until you save, so it's safe to experiment. The project is also a git repo, so any saved changes can be diffed/reverted with git if needed.
