# Move Effectiveness

Move Effectiveness adds optional battle-menu borders without replacing KIF or
EBDX battle scenes. The feature is global and defaults to `Off`.

## Display Rules

The selected damaging move receives a pulsing border based on its highest type
multiplier against a valid opposing target:

- `4x` or stronger uses the configurable `4x Border` color.
- `2x` uses the configurable `2x Border` color.
- `1x` uses the configurable `Neutral Border` color.
- `x1/2` uses the configurable `x1/2 Border` color.
- `x1/4` or weaker uses the configurable `x1/4 Border` color.
- `x0` always uses gray.

The Neutral Border defaults to Cyan. The effectiveness defaults are Green,
Yellow, Orange, and Red respectively. Status, ally-only, and otherwise
non-previewable moves do not receive an effectiveness color.

In multi battles, the move border only summarizes opposing targets so damage
to an ally cannot produce a favorable move color. When target selection is
shown, only the currently selected valid target receives its effectiveness
border. Allies that can be affected use their own result when selected. Slots
that EBDX marks as unavailable never receive a border.

For EBDX move selection, KR also intersects the battle calculation with the
target indices EBDX exposes for that move. Hidden, placeholder, and unavailable
targets cannot influence the move border.

## Integration

The module installs guarded wrappers through `KantoReloaded::Hooks`. Separate
overlay sprites follow the native or EBDX move and target buttons. Move names,
move objects, button graphics, battle choices, and target-selection behavior
are not replaced.

The global `Reloaded EBDX Cursor` Interface option independently replaces
EBDX's red corner selectors on command, move, target, and battle-bag selection
screens. Its normal cursor color uses the configurable `Neutral Border` color.
When enabled, non-previewable moves keep that neutral Reloaded cursor. When
disabled, EBDX's native selector remains visible and Move Effectiveness only
adds colors where an effectiveness preview is available. `Neutral Border`
remains adjustable while the Reloaded cursor is enabled, even if Move
Effectiveness itself is Off.

Effectiveness is calculated when move or target UI is refreshed. Per-frame
updates only reposition and pulse the already-created selected-move border.

The preview uses the move's current battle type and type-modifier calculation.
It does not execute ability immunity handlers because those handlers can have
battle side effects.
