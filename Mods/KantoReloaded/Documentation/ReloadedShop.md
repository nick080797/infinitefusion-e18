# Reloaded Shop

Kanto Reloaded replaces KIF's Kuray Shop purchase screen with the offline
`RLD Shop`. The `Regular Mart` option chooses between KIF's untouched Standard
interface and Kanto Reloaded's Reloaded buy and sell scenes. It defaults to
Reloaded.

## Stock ownership

KIF remains responsible for building the available Kuray Shop stock and prices.
This preserves badge requirements, Streamer's Dream behavior, Rocket Ball
availability, K-Egg progression, and other base-game conditions.

Kanto Reloaded stores a per-save customization overlay for:

- category names and order
- item categories and custom order
- added, removed, and disabled items
- buy and sell price overrides
- favorite items

Resetting RLD Shop clears only this overlay.

## Controls

- Up/Down: select an item
- Left/Right: change category
- Confirm: buy or open editor actions
- Back: close
- Action: toggle favorite
- Special: open the RLD Mart controls popup
- L: cycle sorting
- R: toggle Quick Buy

Purchasing uses the same centered Reloaded Mart quantity and confirmation
panels as Hoenn Reloaded. Regular Marts using the Reloaded interface have a
matching sell scene with category navigation, sorting, quantity selection,
and KR confirmations. Quick Sell is intentionally not provided. The
customizable RLD Shop remains buy-only.

Regular Mart Reloaded mode uses the exact stock and temporary prices supplied
by KIF, including randomized and progression-dependent stock. It never imports
RLD Shop catalog categories, favorites, custom stock, or custom prices. Mart
Events can adjust regular Mart purchase prices, but never selling prices.
Mart Events never affect the customizable RLD Shop.
The buy and sell scene header remains the short `Mart` label; location and
department names are shown in Mart Events instead.

The Buy/Sell/Economy Control prompt is shown once per interaction. Returning
from any selected scene exits the Mart instead of reopening the prompt.

Bulk purchases in both RLD Shop and ordinary NPC Marts award one bonus item
for every complete group of ten in the current transaction:

- every 10 Poke Balls award 1 Premier Ball
- every 10 DNA Splicers award 1 DNA Reverser
- every 10 Super Potions, Hyper Potions, or Max Potions award 1 Potion

Eligible Reloaded Shop quantity and confirmation panels preview the reward for
the selected quantity. Ordinary NPC Marts add the same preview to their native
purchase confirmation. A KR purchase-reward popup then reports the number of
bonus items added. If the Bag cannot hold the full reward, the popup reports
the partial or failed award.

Open the catalog editor from **Economy > Reloaded Shop**. The editor
uses Left/Right to change panels and Action to add a category or item.

## Import and export

Catalog data is exported to:

`Mods/KantoReloaded/Exports/ReloadedShopCatalog.json`

The feature is entirely local. It has no online catalog, publishing,
automation, services, promo codes, alternate currencies, timed stock, bundles,
or reward system.

## Compatibility

Runtime integration uses guarded KR hooks:

- `PokemonPauseMenu_Scene#pbShowCommands` changes only the `Kuray Shop` label to
  `RLD Shop`.
- `PokemonMartScreen#pbBuyScreen` redirects only while KIF marks
  `$game_temp.fromkurayshop`.
- Standard Mart hooks track the selected item and quantity, then award bonuses
  only after `PokemonMartAdapter#setMoney` confirms a successful purchase.
- KIF's original single Premier Ball bonus is suppressed only after KR has
  awarded the complete per-10 reward.

When `Regular Mart` is Standard, KR delegates the complete Mart call to KIF's
original implementation. Reloaded mode uses KR-owned buy and sell loops while
retaining `PokemonMartAdapter` as the inventory, price, and payment authority.
