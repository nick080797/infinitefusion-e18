# Randomizer

Kanto Reloaded's Randomizer module extends KIF's existing randomizer rather
than replacing it. The original Dynamic Randomiser concept is credited to
**An Unsocial Pigeon**.

## Settings

The `Randomizer` action is in Kanto Reloaded's `Gameplay` category. Its runtime
settings are per-save, and its feature toggles default to Off:

- `randomizer.dynamic_wild`: chooses a new eligible species for each future
  normal wild encounter and for KIF-enabled Gift Pokemon or Static Encounters.
- `randomizer.wild_mode`: uses KIF's BST range or selects any eligible Pokemon
  randomly. BST Range is the default.
- `randomizer.dynamic_items`: chooses a new eligible item whenever KIF has
  already decided that a found or given item should be randomized.
- `randomizer.dynamic_abilities`: assigns random abilities to Pokemon generated
  after the setting is enabled.

`Dynamic Pokemon` requires KIF's main `Pokemon` randomizer option to be
On. `Dynamic Items` likewise requires KIF's main `Items` randomizer option to
be On. Trying to adjust either KR setting without its prerequisite opens a
warning that identifies the required KIF option. If a prerequisite is disabled
later, KR preserves the saved setting but pauses that dynamic feature until the
KIF option is enabled again.

Changing `Dynamic Pokemon` or `Dynamic Items` does not regenerate KIF's
Global or Area mappings. Those mappings remain intact underneath the dynamic
layer and are visible again as soon as the corresponding dynamic setting is
disabled.

`Dynamic Abilities` has no KIF prerequisite and can be changed at any point in
an existing save. It affects future Pokemon creation, trainer generation,
fusion creation, fusion reversal, and unfusion. It never rewrites Pokemon
already stored in the save. Turning it Off stops future ability rolls but does
not revert abilities already assigned while it was On.

## KIF Rules

The module deliberately reuses KIF's existing controls:

- `Custom Sprites Only` selects the custom-sprite pool. When it is Off, all
  eligible Pokemon can appear.
- `Randomness degree` supplies the target BST range.
- `Wild Selection: Random` ignores the BST range while continuing to honor the
  selected Pokemon pool and legendary rules.
- `Allow legendaries` controls whether non-legendary encounters may become
  legendary. Existing legendary encounters still map to legendaries.
- `Gift Pokemon` allows eligible KIF gift acquisitions to use live species
  selection while Dynamic Pokemon is On.
- `Static Encounters` allows eligible scripted static battles to use live
  species selection while Dynamic Pokemon is On.
- Starters continue using KIF's existing randomized-starter mapping and are
  never rerolled by Dynamic Pokemon.
- Found Item, Found TM, Given Item, and Given TM options determine which item
  sources can invoke dynamic item selection.
- Item and TM randomizer toggles determine which item types are eligible.

KIF already owns randomization for wild Pokemon, trainers, Gyms, starters,
static encounters, gift Pokemon, found and given items or TMs, shops, trainer
held items, legendary handling, fusion behavior, and custom-sprite filtering.
KR does not duplicate those settings. Dynamic Pokemon only changes the species
result after KIF has authorized an enabled wild, gift, or static source. KIF
does not currently expose general randomization for abilities, so KR provides
its own dynamic ability layer. Evolutions and learned movesets are not changed
by this module.

## Safety

Dynamic species selection wraps `PokemonEncounters#choose_wild_pokemon`,
`tryRandomizeGiftPokemon`, and `pbKurayRandomize`. The gift wrapper preserves
KIF's `dontRandomize` and starter-selection exclusions. The static wrapper
preserves KIF's base-species and Poke Radar exclusions. The module does not
wrap `pbGenerateWildPokemon`, silent storage helpers, roaming construction,
NPC contest catches, or multiplayer-created copies. The selected level and
encounter metadata are preserved.

Dynamic item selection wraps `pbGetRandomItem`. Key items, HMs, KIF's protected
item lists, and internal/debug entries are excluded. TMs remain TMs, berries
remain berries, quantities are preserved by the calling KIF workflow, and a
failed candidate search returns the original value.

Species searches are bounded and widen their BST range only when necessary.
Species stats, legendary checks, custom-sprite IDs, and item pools are cached.
The last ten selected species across enabled dynamic Pokemon sources are stored
in KR's save bucket to reduce immediate repeats. The Settings screen provides a
command to clear that history.

Dynamic ability selection uses registered KIF and mod abilities except internal
placeholders, form-dependent owner-restricted abilities, and Multiplayer's
boosted Family-only talents. Family Pokemon are skipped completely.
Single-species Pokemon receive one randomized ability. When KR Double Abilities
is enabled, newly generated fusions receive two distinct abilities that pass
the Double Abilities hard blacklist. If Double Abilities is disabled, fusions
receive one randomized active ability.

Owner-restricted abilities never enter the general random pool. If a species
or fusion component naturally owns one, its slot has a 25% chance to select one
of those native restricted abilities and a 75% chance to use the general pool.
A species with no native restricted ability always uses the general pool.
Double Abilities evaluates this rule separately for each ability's owning
fusion component. Duplicate or hard-blacklisted results are rerolled and fall
back to a legal general pairing.

The explicit owner-restricted list covers Disguise, Power Construct, Schooling,
Shields Down, Stance Change, Tera Shift, Zen Mode, and Zero to Hero. These
abilities remain native-only because their effects require a supported species
or form transition. Entries not registered by the current KIF build are
ignored.

Signature abilities that do not require a form transition can enter the
general pool. KR supplies narrow compatibility behavior where KIF's native
implementation still checks a specific owner. Commander works for any holder
but still requires an allied Dondozo. Battle Bond grants its modern
once-per-battle stat boost to non-Greninja holders. Multitype and RKS System
change the holder's owning type position when it holds a matching Plate,
type Z-Crystal, or Memory. A dynamically randomized Wonder Guard has three
blocks per battle even when it is the Pokemon's only ability; naturally owned
single-ability Wonder Guard retains KIF's normal unlimited behavior.

Ability mods can keep a custom species-bound ability out of the general pool
without editing KR:

```ruby
KantoReloaded::Randomizer.register_owner_restricted_ability(:MYABILITY)
```

The ability remains eligible for the 25% native roll when it appears in that
species or component's registered normal or hidden ability data.

Ability assignment is applied after trainer and fusion finalization so those
native workflows cannot overwrite the result. Fusion creation suppresses the
normal ability chooser while Dynamic Abilities is enabled because the final
ability or pair is selected automatically.

KIF save data and Pokemon JSON export/import preserve KR's dynamic assignment
metadata, including whether a single-ability Wonder Guard uses the randomized
three-charge rule.

## Migration

On first load, KR imports enabled values from the legacy Dynamic Randomiser
switches (`1700` for wild Pokemon and KIF's dynamic-item switch) only when the
new KR setting has not already been stored. KR does not continue writing those
legacy switches.
