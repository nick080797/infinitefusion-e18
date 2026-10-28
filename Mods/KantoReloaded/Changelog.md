══════════════════════════════════════════════
KANTO RELOADED
Update #5 - Mart Dynamics
v1.5.0
Release Date: August 13, 2026
══════════════════════════════════════════════

SUMMARY
-------
This update brings changing sales and shortages to regular Marts, adds optional Reloaded Mart interfaces, expands money settings, and adds paid Reloaded PC services. It also fixes issues across Trainer Control, Double Abilities, Weather, Healing Overworld Moves, and the Overworld Menu.

FEATURES
--------
• Added an Economy System that gives regular Marts local sales and shortages lasting three in-game days
  - Mart Events can affect selected items, an item category, or the entire shop
• Added Mart Events as an optional Overworld Menu command for checking, filtering, and tracking active events
• Added Starting Money and Battle Money settings
• Added paid Reset EVs and Friendship Boost actions to the Reloaded PC Menu
  - Service prices can be customized, and Friendship Boost previews the result
• Added optional Reloaded interfaces for buying and selling at regular Marts

IMPROVEMENTS
------------
• Improved the Overworld Menu Time Changer by letting players choose how many days pass and the target hour

BUG FIXES
---------
• Fixed Gym Leader Full Party still limiting the player's usable party instead of allowing both sides to use six Pokemon
• Fixed some fusion evolutions creating duplicate abilities when Double Abilities was enabled
• Fixed rain audio continuing after Weather or Custom Audio was turned off
• Fixed Weather System settings appearing directly in Gameplay instead of inside the Weather System menu
• Fixed Healing Overworld Moves closing the Party Menu after using a healing move
• Fixed the Overworld Menu Time Changer moving time backward when an earlier hour was selected

VISUALS & UI
------------
• Added a Mart Events interface with All, Sales, Shortages, and Ending Soon filters, found in the Overworld Menu or Options menu
• Added normal and event price comparisons, event details, and live savings or markup amounts to Reloaded regular Marts
• Added number pickers for Starting Money and Reloaded PC service prices

TECHNICAL
---------
• Added guarded native payout and new-game hooks with persistent location-based shop identities

DEVELOPER
---------
• Added a stable Economy System API and Reloaded PC action-registry integrations
• Added direct in-Mart Economy Control access when the separate Admin Control mod is installed

══════════════════════════════════════════════
KANTO RELOADED
Update #4 - Shifting Skies
v1.4.2
Release Date: August 3, 2026
══════════════════════════════════════════════

SUMMARY
-------
This update introduces persistent regional weather and forecasting with battle integration, custom ambience, and multiplayer safeguards while improving Wild Link previews and Overworld Menu responsiveness.

FEATURES
--------
• Added a regional Weather System with persistent climate-based or fully random weather cells, weather forecasts, Overworld Menu forecast views, and battle-weather integration
• Added a global Wild Link Sprites option for switching detail previews between Pokémon icons and full battle sprites

IMPROVEMENTS
------------
• Improved the Overworld Menu so map graphics and world-time updates continue while the overlay and its popups are open
• Improved Wild Link opening so the initially selected row's Pokémon preview is loaded before the completed scene becomes visible

BUG FIXES
---------
• Fixed authored Wild Link Rare Signals being remapped by encounter and Static Encounter randomization instead of matching the live Poké Radar-exclusive species
• Fixed Wild Link invoking KIF's popup-producing battle randomizer while building roster rows; static encounter results are now resolved directly without repeated error prompts
• Fixed Wild Link repeatedly presenting stale loading frames and requiring additional button presses before the completed scene appeared
• Fixed Wild Link fusion previews collapsing to the shared icon 000 placeholder and Seen species remaining black silhouettes
• Fixed Wild Link detail previews inheriting Big Icons, miscomposing valid species with fallback fusion components, shrinking unintended full battle sprites into icon-sized space, failing to resolve exact fusion icons, and allowing invalid species to display KIF's Pikachu fallback; previews now use Pokémon icon assets by default

VISUALS & UI
------------
• Added non-pausing upper-left alerts for local Weather System changes

AUDIO
-----
• Added optional continuous rain, storm, and heavy-rain ambience to the Weather System with randomized thunder timing and independent rain and thunder audio toggles

PERFORMANCE
-----------
• Removed first-open Wild Link stalls caused by constructing complete fusion battle data for roster rows; fusion names, Pokédex keys, and icon paths now use lightweight references, previews load only after active row focus, and completed scenes are presented immediately
• Packed 2,302 Wild Link fusion follower graphics into two lazily opened ZIP-compatible `.pak` archives, reducing update file count while preserving on-demand normal and shiny silhouettes

TECHNICAL
---------
• Added guarded PvP weather negotiation that synchronizes initiator battle weather only when both clients confirm Kanto Reloaded support and suppresses unsynchronized local weather in co-op

DEVELOPER
---------
• Added a data-only Weather System map override registry for eligibility, cell grouping, climate, and forecast-label exceptions

══════════════════════════════════════════════
KANTO RELOADED
Update #3 - Signals & Supplies
v1.3.2
Release Date: July 27, 2026
══════════════════════════════════════════════

SUMMARY
-------
This update strengthens Wild Link with more accurate randomized rosters, safer field targets, clearer progression details, and faster previews while expanding Mart bulk-purchase rewards and reducing Double Abilities battle overhead.

FEATURES
--------
• Added deterministic Rare Signal species targeting roughly 50 BST above the route average on maps without authored Poké Radar encounters

IMPROVEMENTS
------------
• File A Bug Report now uploads and copies separate links for both the sanitized bug report and full current log

BALANCE
-------
• Added one Potion per 10 Super Potions, Hyper Potions, or Max Potions purchased in a single transaction

BUG FIXES
---------
• Fixed chance-based and forced wild fusions being persisted in Wild Link rosters instead of showing only fusions supplied by randomized encounter tables
• Fixed Wild Link Surf searches selecting bridge tiles, placing overworld Pokemon on land, and launching battles from map updates in a way that could cause white-screen crashes
• Fixed Dynamic Pokemon encounters expanding Wild Link's persistent searchable roster
• Fixed Wild Link omitting KIF's final Static Encounter mapping from randomized table, Rare Signal, and generic Rock Smash fallback species
• Fixed Wild Link showing authored encounter species instead of KIF's effective Global or Area randomized encounter roster
• Expanded per-10 Premier Ball and DNA Reverser purchase rewards to regular marts
• Fixed bug reports omitting errors that had fallen outside the newest 300 log lines
• Fixed Wild Link hiding valid Surf encounter tables until the player was already surfing
• Fixed Wild Link omitting KIF's generic Geodude fallback on maps with smash rocks but no authored Rock Smash table
• Fixed Wild Link placement failures being hidden when Messages was Off
• Fixed fusion component evolution replacing still-legal Double Abilities with KIF's post-evolution ability-index result
• Fixed active Wild Link Rock Smash indicators remaining owned by the previous map spriteset and crashing during map transfers
• Fixed Wild Link combining Morning, Day, and Night species instead of showing KIF's currently active time-based encounter table

VISUALS & UI
------------
• Added live bulk-purchase reward previews to Reloaded Shop and standard Mart purchase confirmations
• Added per-method Seen and Caught completion counters to the Wild Link header
• Added KR purchase-reward prompts showing how many bonus items were added in Reloaded Shop and regular marts
• Added Input Z switching between Wild Link Search Level information and Current Bonuses for inactive links and active targets
• Replaced Wild Link's ambiguous Potential label with the generated target's exact perfect-IV count
• Highlighted unresolved Wild Link Rare Signals and revealed rare-species roster rows in gold
• Replaced missing Wild Link overworld graphics with Pikachu while preserving fully black silhouettes for unknown targets

PERFORMANCE
-----------
• Reduced Wild Link roster redraw work by caching row display data and moving cursor pulsing onto a dedicated sprite layer
• Cached stable Double Abilities battler eligibility, secondary ability resolution, and legal-pair validation instead of repeating species-data work across battle handlers

TECHNICAL
---------
• Added scoped Dynamic Pokemon suppression so Wild Link can resolve stable native randomizer mappings without consuming a Dynamic encounter roll

DEVELOPER
---------
• Added a Wild Link Gather Map Data diagnostic exporter for current-map metadata, terrain, field events, eligibility, and encounter tables


══════════════════════════════════════════════
KANTO RELOADED
Update #2 - Wild Link & Double Abilities
v1.3.0
Release Date: July 26, 2026
══════════════════════════════════════════════

SUMMARY
-------
This update adds Wild Link, Double Abilities, Move Effectiveness colors and live ability randomization while expanding battle interface customization and existing quality-of-life systems.

FEATURES
--------
• Added live Dynamic Ability randomization for newly generated Pokemon, trainer parties, fusions, reversals, and unfusions
• Added an optional Double Abilities system for newly created, generated, and reversed fusion Pokemon while keeping single-species Pokemon limited to one ability
• Added compatible two-ability behavior for reviewed abilities, moves, and effects, including Transform, Trace, Skill Swap, Role Play, Entrainment, Mummy, Lingering Aroma, Wandering Spirit, Scrappy, Aerilate, Stance Change, Disguise, Schooling, Power Construct, Shields Down, Battle Bond, Zen Mode, Neutralizing Gas, Slow Start, Multitype, and RKS System
• Added descriptive, slot-aware ability selection for fusion creation, Summary, Ability Capsule, Secret Capsule, Ability Ball
• Added Double Abilities-aware AI scoring for ability-changing moves and secondary Illusion support in opponent switch previews
• Added Wild Link, a targeted overworld Pokemon search system for Land, Cave, Surf, Fishing, Headbutt, and Rock Smash encounters
• Added permanent per-species and per-fusion Search Levels, method-and-map chains, post-battle continuation modes, and progressive target information
• Added Wild Link bonuses for shiny rolls, perfect IVs, Hidden Abilities, up to two Egg Moves, native held items, and encounter levels
• Added Hoenn-style Wild Link overworld reactions, temperament movement, and staged flee animations

IMPROVEMENTS
------------
• Expanded Dynamic Pokemon to reroll eligible Gift Pokemon and Static Encounters when their corresponding KIF randomizer toggles are enabled
• Generalized signature abilities that do not require form changes, including Dondozo-gated Commander, modern Battle Bond boosts, and held-item typing for Multitype and RKS System

BALANCE
-------
• Improved Reloaded Shop bulk purchases to award one Premier Ball per 10 Poke Balls and one DNA Reverser per 10 DNA Splicers
• Restricted form-dependent abilities to native species or fusion components, with a 25% native roll and a 75% general roll for eligible owners
• Limited Wonder Guard to three blocked damaging moves per battle when paired with a second active ability or assigned by Dynamic Abilities

BUG FIXES
---------
• Fixed Battle Menu, Overworld Menu, and Egg Manager stack overflows on JoiPlay
• Fixed Settings Preset saving on JoiPlay and included registered Kanto Reloaded settings in preset save and load
• Fixed uploaded bug-report links not copying to the clipboard on supported JoiPlay runtimes
• Fixed enlarged EBDX move buttons rendering beneath neighboring move buttons
• Fixed EBDX multi-target selection showing DNA placeholders instead of Pokemon icons
• Fixed Overworld Menu status text being compressed when its command label left enough unused row space

VISUALS & UI
------------
• Improved read-only option rows with dimmed theme colors, cursor navigation, and accessible descriptions without allowing edits
• Added optional Move Effectiveness borders for native and EBDX move and target selection, with configurable neutral, 4x, 2x, x1/2, and x1/4 colors
• Added an optional Reloaded EBDX Cursor for rounded command, move, target, and battle-bag selection borders

TECHNICAL
---------
• Added guarded signature-ability adapters that preserve native handlers while extending compatible mechanics to randomized holders
• Preserved Dynamic Ability assignment and randomized Wonder Guard charge metadata through Pokemon JSON export and import
• Added guarded Double Abilities dispatch across all 46 KIF ability-handler entry points, standard Pokemon ability predicates, and reviewed direct-check mechanics with correct secondary ability splash names and without replacing KIF, Multiplayer, or Family Pokemon files
• Added versioned per-Pokemon Double Abilities metadata without backfilling existing fusion Pokemon
• Added guarded Wild Link bridges that preserve native field interactions, pass exact generated Pokemon into wild battles, and suppress only step encounters while a target is active

DEVELOPER
---------
• Added the stable `KantoReloaded::DoubleAbilities` API contract and documented its ability, item, compatibility, and blacklist behavior


══════════════════════════════════════════════
KANTO RELOADED
Update #1 - Reloaded PC
v1.2.0
Release Date: July 23, 2026
══════════════════════════════════════════════

SUMMARY
-------
This update adds dynamic randomization, save management, and a Reloaded PC interface while improving existing QoL systems.

FEATURES
--------
• Added a Randomizer module with per-encounter wild Pokemon and per-pickup item randomization
• Added Wild Selection for switching between BST-matched and fully random encounters
• Added a Reloaded PC toggle with Reloaded-only animation, speed, and Pokemon art settings
• Added Reloaded PC Speed with Off, 2x, and 3x modes. Speed-Up button is disabled in the RLD PC.
• Added Reloaded PC controls with L/R box switching, X-button focus cycling, A-button Normal, Quick Swap, and Multi Select modes, and a Z-button Reloaded PC menu
• Added a Big Icons option for switching between icons and full sprites
• Added Reloaded PC mouse controls with click-or-drag Quick Swap pickup, carry-aware box-panel wheel navigation, clickable footer controls and adjacent-box headers, drag-hover box switching, drag-and-drop moving or swapping, and right-click action menus
• Added EBDX-compatible reverse fusion support
• Added Save Manager for safely archiving, restoring, inspecting, and permanently removing save files

IMPROVEMENTS
------------
• Updated the About screen and framework services to read Kanto Reloaded's version directly from `mod.json`
• Changed TM Vault's Relearn Moves control to Input Y

BUG FIXES
---------
• Fixed Autosort Bag legacy text export/import
• Fixed Upgraded PP to refill a move only when its maximum PP is first upgraded
• Fixed Interface settings to persist globally across saves and game restarts while keeping Battle Menu layout customization per-save
• Fixed File A Bug Report to open the dedicated Kanto Reloaded bug-report Discord thread
• Fixed Back input activating the highlighted row in shared popups

VISUALS & UI
------------
• Expanded About with Author and Discord Link rows
• Removed hint footers from category-only and action-only Options pages
• Aligned read-only option values with the value column used by adjustable options
• Rounded the type icons shown in TM Vault
• Updated standard shared confirmations to begin on Yes while serious prompts continue to begin on No

TECHNICAL
---------
• Added one-time migration for legacy Dynamic Randomizer wild and item settings

DEVELOPER
---------
• Added the stable `KantoReloaded::Randomizer` API contract and documented its guarded integration boundaries
• Added the stable `KantoReloaded::PCOrganization` menu-command registry contract
• Added Pokemon, box, and multi-selection action registries for extending Reloaded PC without replacing its menus
