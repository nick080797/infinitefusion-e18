# Economy System

The Economy System adds optional shop-local Mart Events, configurable
new-game and battle money, and paid Reloaded PC services. Its action button
appears in Kanto Reloaded's Economy category.

## Mart Events

Mart Events default to On. Every discovered shop has a fixed three in-game-day
cycle based on `pbGetTimeNow`, so Unreal Time and KIF's calendar remain the
time authority. The first shop interaction starts its timer. A throttled
overworld scheduler resolves later cycles when they become due, without
requiring the shop to be reopened. At the beginning of a cycle, the shop can
receive a sale, a shortage markup, or no event. A no-event result remains in
effect until the next three-day cycle. Events affect two to eight eligible
items, an item category, or rarely the whole shop.

Existing shop records created before stock snapshots were introduced still
reroll through the background scheduler. Until that Mart is opened once to
cache its current stock, successful legacy rolls retain their intended selected
items, item category, or shopwide scope. Mart Events shows unresolved targets
as being chosen when the Mart opens. Opening the Mart resolves the actual items
or category without changing the event's type, strength, or expiration. Events
Status only displays successful active rolls; it does not trigger the roll.

Mart Event frequency and strength are balanced by the system rather than exposed
as player settings. Each shop has a 65% event chance per cycle. Sales range
from 10-30%, while shortage markups range from 5-20%.

Sales are weighted more often than shortages, and item-specific events are
weighted more often than category or shopwide events. The immediately prior
event signature is avoided when possible.

When KIF's randomized shop-stock switches are active, automatically generated
events use category or shopwide scopes so their full three-day duration remains
valid if the randomizer mapping changes. Existing selected-item and category
events retain their scope for the full duration. If saved targets are no longer
available, replacements are selected within the same scope without changing
the event's type, strength, or expiration.

Regular Mart identity uses KIF's current-Mart city value on KIF's shared
PokeMart interior map, which keeps cities independent while sharing one event
across every cashier in the same city. Other ordinary Marts share one event per
map. Explicit `MART_COUNTER_LABELS` entries can split genuinely distinct
departments; Celadon Department Store counters include their floor and
department. Legacy cashier and stock identities are consolidated into the new
shared record when that Mart is visited. Mart Events apply only when ordinary
Marts use the Reloaded interface. The customizable RLD Shop is excluded
entirely: it does not register, roll, display, or apply Mart Events. Any saved
RLD Shop event created by an earlier version is removed automatically.

The Mart Events page lists every discovered event that remains active. L/R
filters the page between All, Sales, Shortages, and events ending within the
next 24 hours. Reloaded regular Mart rows show the normal price beside the
adjusted event price, while quantity and confirmation panels show the total
savings or markup before payment. Mart Events is also an optional Overworld
Menu command, disabled in the page editor by default, with the active-event
count shown as its status. Input A in a Reloaded regular Mart opens the current
event details; Input A, Confirm, or Back closes that popup. Mart Event
notifications are not shown.

## Money

Starting Money is a global new-game amount and defaults to `$3,000`. It is
configured through a KR digit picker, assigned after KIF creates the new
Trainer while the Economy System is enabled, and does not alter existing saves.

Battle Money defaults to On at `1x` and supports `1x-10x`. KIF completes its
native payout first. KR measures the actual money gained and adds only the
configured extra amount, preserving native trainer payout, Pay Day, Amulet
Coin, Happy Hour, rematch, and money-cap behavior.

## Paid PC services

When Reloaded PC is active, the `Reloaded Actions` submenu directly below
`Kuray Actions` includes:

- Reset EVs: resets all EVs for `$1,000` by default
- Friendship Boost: adds 50 friendship, capped at 255, for `$5,000` by default

Starting Money and both service prices use KR digit-picker popups.
Friendship Boost previews both the current and resulting friendship before the
player confirms payment.

Each service checks eligibility and funds before confirmation, charges only
after the Pokemon update succeeds, refreshes the active PC scene, and returns
to the `Reloaded Actions` submenu. Eggs are not eligible.

## Public API

`KantoReloaded::EconomySystem` exposes the current shop context and event plus
guarded event controls used by external developer tools:

- `current_mart_event_context`
- `current_mart_event`
- `prepare_mart_event_context(context, entries)`
- `force_mart_event(type, scope, percent)`
- `reroll_mart_event`
- `expire_mart_event`
- `clear_mart_event`

Economy state is stored under the `economy_system` KR save-data owner. Admin
controls are intentionally kept in the separate Admin Control mod. When Admin
Control is installed, Reloaded regular Marts expose Economy Control directly
from their Buy/Sell/Quit prompt so the active shop can be changed in place.
