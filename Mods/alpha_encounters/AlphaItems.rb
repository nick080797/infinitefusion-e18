
class PokeBattle_Move
    alias alpha_block_pbMoveFailed? pbMoveFailed?
    ALPHA_MOVES_BLOCKED = %i[THIEF COVET TRICK SWITCHEROO KNOCKOFF]
    def pbMoveFailed?(user, targets)
        # Check if any target is a alpha and move is blocked
        if ALPHA_MOVES_BLOCKED.include?(@id) && battle.wildBattle?
            alpha_target = targets.find { |t| t.pokemon.alpha? }
            if alpha_target
                @battle.pbDisplay(_INTL("{1} is unaffected by {2}!", alpha_target.pbThis, @name))
                return true
            end
        end

        alpha_block_pbMoveFailed?(user, targets)
    end
end

BattleHandlers::UserAbilityEndOfMove.add(:MAGICIAN,
                                         proc { |ability, user, targets, move, battle|
                                                next if battle.futureSight
                                              next if !move.pbDamagingMove?
                                              next if user.item
                                              next if battle.wildBattle? && user.opposes?
                                              targets.each do |b|
                                              next if b.damageState.unaffected || b.damageState.substitute
                                              next if !b.item
                                              # --- Boss protection ---
                                              if b.pokemon.alpha? && battle.wildBattle?
                                              battle.pbShowAbilitySplash(user)
                                              battle.pbDisplay(_INTL("{1}'s item is protected by its alpha aura!", b.pbThis))
                                              battle.pbHideAbilitySplash(user)
                                              next
                                              end
                                              # --- End alpha protection ---
                                              next if b.unlosableItem?(b.item) || user.unlosableItem?(b.item)
                                              battle.pbShowAbilitySplash(user)
                                              user.item = b.item
                                              b.item = nil
                                              b.effects[PBEffects::Unburden] = true if b.hasActiveAbility?(:UNBURDEN)
                                              if battle.wildBattle? && !user.initialItem && user.item == b.item
                                              user.setInitialItem(user.item)
                                              b.setInitialItem(nil)
                                              end
                                              battle.pbDisplay(_INTL("{1} stole {2}'s {3}!", user.pbThis,
                                                                     b.pbThis(true), user.itemName))
                                              battle.pbHideAbilitySplash(user)
                                              user.pbHeldItemTriggerCheck
                                              break
                                              end
                                              }
                                        )

BattleHandlers::TargetAbilityAfterMoveUse.add(:PICKPOCKET,
                                              proc { |ability, target, user, move, switched, battle|
                                                     next if battle.wildBattle? && target.opposes?
                                                   next if !move.contactMove?
                                                   next if switched.include?(user.index)
                                                   next if user.effects[PBEffects::Substitute] > 0 || target.damageState.substitute
                                                   next if target.item || !user.item
                                                   # --- Boss protection ---
                                                   if user.pokemon.alpha? && battle.wildBattle?


                                                   battle.pbShowAbilitySplash(target)
                                                   battle.pbDisplay(_INTL("{1}'s item is protected by its alpha aura!", user.pbThis))
                                                   battle.pbHideAbilitySplash(target)
                                                   next
                                                   end
                                                   # --- End alpha protection ---
                                                   next if user.unlosableItem?(user.item) || target.unlosableItem?(user.item)
                                                   battle.pbShowAbilitySplash(target)
                                                   target.item = user.item
                                                   user.item = nil
                                                   user.effects[PBEffects::Unburden] = true if user.hasActiveAbility?(:UNBURDEN)
                                                   if battle.wildBattle? && !target.initialItem && target.item == user.item
                                                   target.setInitialItem(target.item)
                                                   user.setInitialItem(nil)
                                                   end
                                                   battle.pbDisplay(_INTL("{1} pickpocketed {2}'s {3}!", target.pbThis,
                                                                          user.pbThis(true), target.itemName))
                                                   battle.pbHideAbilitySplash(target)
                                                   target.pbHeldItemTriggerCheck
                                                   })
## Custom Items
module AlphaItems
    START_ID_NUMBER = 8000
    @registered = false
    ITEMS = [
        { sym: :ALPHABOND},{ sym: :ALPHADEFENSE},
        ]
    def self.registrar
        if defined?(GameData::Item) && GameData::Item.respond_to?(:register)
            return [:gamedata_item, GameData::Item]
        end
        if defined?(Item) && Item.respond_to?(:register)
            return [:item_alias, Item]
        end
        nil
    end

    # Sanity-check that required systems exist before attempting registration.
    # Ensures MessageTypes and GameData::Item helpers exist, and that a registrar API was found.
    def self.ready?
        return false unless defined?(MessageTypes) && MessageTypes.respond_to?(:set)
        return false unless defined?(GameData::Item) && GameData::Item.respond_to?(:each) &&
                        GameData::Item.respond_to?(:exists?) && GameData::Item.respond_to?(:get)
        !!registrar
    end
    def self.register_one(reg_mod, sym, id_number, name, price, desc)
        plural = name + "s"
        reg_mod.register({
                          :id          => sym,
                          :id_number   => id_number,
                          :name        => name,
                          :name_plural => plural,
                          :pocket      => 1,
                          :price       => price,
                          :description => desc,
                          :field_use   => 0,
                          :battle_use  => 0,
                          :type        => 0,
                          :move        => nil
                         })
        MessageTypes.set(MessageTypes::Items,            id_number, name)
        MessageTypes.set(MessageTypes::ItemPlurals,      id_number, plural)
        MessageTypes.set(MessageTypes::ItemDescriptions, id_number, desc)
    end
    def self.used_id_numbers
        used = {}
        begin
            GameData::Item.each do |it|
                n = nil
                begin
                    n = it.id_number
                rescue
                    n = nil
                end
                used[n] = true if n.is_a?(Integer)
            end
        rescue
        end
        used
    end

    # Register all stones from STONES into GameData exactly once per game boot.
    # Skips if the item already exists, chooses free id_numbers starting from START_ID_NUMBER, and logs each decision.
    def self.register_once!
        return if @registered == true

        api = registrar

        return unless ready?
        api_name, reg_mod = api

        begin
            used = used_id_numbers
            numbers = []
            id_here = START_ID_NUMBER

            ITEMS.each do |s|
                sym   = s[:sym]
                name  = s[:name]  || s[:sym].to_s
                desc  = s[:desc]  || ""
                price = s[:price] || 0

                exists = false
                begin
                    exists = GameData::Item.exists?(sym)
                rescue
                    exists = false
                end

                if exists
                    it = nil
                    begin
                        it = GameData::Item.get(sym)
                    rescue
                        it = nil
                    end

                    next
                end

                id_here += 1 while used[id_here]
                numbers.push(id_here)
                used[id_here] = true

                register_one(reg_mod, sym, id_here, name, price, desc)


                id_here += 1
            end
            echoln numbers
            @registered = true
        rescue => e
            MegaStonesLog.err(e, "MegaStoneItems.register_once! (api=#{api.inspect})")

        end
    end
    @hooked = false

    # If the game exposes GameData.kurayeggs_loadsystem, hook it to run registration + icon copying after the data load completes.
    # This is a safer "run after core data is ready" point in some Kuray/KIF builds.
    def self.try_hook_kuray!
        return if @hooked
        return unless defined?(GameData)
        return unless GameData.respond_to?(:kurayeggs_loadsystem)


        begin
            sc = GameData.singleton_class
            unless sc.method_defined?(:__alpha_kurayeggs_loadsystem)
                sc.class_eval do
                    alias_method :__alpha_kurayeggs_loadsystem, :kurayeggs_loadsystem
                    define_method(:kurayeggs_loadsystem) do |*args|
                        __alpha_kurayeggs_loadsystem(*args)
                        self.register_once!

                    end
                end
            end
            @hooked = true

        rescue => e

        end
    end

    # Periodic bootstrap entry-point (called every Graphics.update).
    # Ensures the hooks/registration/icons/patches are installed, then runs one-time helpers (debug dump, self-fusion equip).
    def self.tick!
        self.try_hook_kuray!
        self.register_once!
        self.install_icon_fallback_hook!
    rescue => e
        MegaStonesLog.err(e, "MegaStoneBootstrap.tick!")
    end

    @hooked_icon = false

    def self.install_icon_fallback_hook!
        return if @hooked_icon

        # NOTE: this used to install its own Kernel#pbItemIconFile fallback hook
        # (identical to mega_stones/Mods/050_MegaStoneSimulator.rb's), aliasing
        # the ORIGINAL method to the literal name __megastones_orig_pbItemIconFile.
        # It relies on MegaStoneIcons/MegaStonesLog, which only mega_stones
        # actually defines, so this method has always required mega_stones to be
        # installed to do anything useful. Worse, if mega_stones IS installed,
        # both mods alias that same name - the second one to load re-points the
        # name at the first mod's already-hooked version, whose body calls itself
        # by that same literal name, causing infinite self-recursion
        # (SystemStackError) the first time any item icon is drawn.
        # mega_stones installs this exact hook on its own, so there's nothing
        # left for this copy to safely do - leave it a no-op.
        begin
            @hooked_icon = true
        rescue => e
            MegaStonesLog.err(e, "MegaStoneIcons.install_icon_fallback_hook!")
        end
    end



end
if defined?(Graphics) && Graphics.respond_to?(:update)
    class << Graphics
        alias __alpha_boot_updat update
        # Graphics.update hook: calls the original Graphics.update, then runs MegaStoneBootstrap.tick! once per frame.
        # This makes the mod self-initializing without requiring manual calls elsewhere.
        def update(*args)
            __alpha_boot_updat(*args)
            AlphaItems.tick!
        end
    end
end

# parental bond item
#=======
# The maximum number of hits in a round this move will actually perform. This
# can be 1 for Beat Up, and can be 2 for any moves affected by Parental Bond.

class PokeBattle_Move
    def pbNumHits(user,targets)
        if user.hasActiveAbility?(:PARENTALBOND) && pbDamagingMove? &&
                    !chargingTurnMove? && targets.length==1 or user.item_id == :ALPHABOND && pbDamagingMove? &&
                    !chargingTurnMove? && targets.length==1
            # Record that Parental Bond applies, to weaken the second attack
            user.effects[PBEffects::ParentalBond] = 3
            return 2
        end
        return 1
    end

def pbReduceDamage(user,target)
    damage = target.damageState.calcDamage
    if target.item_id == :ALPHADEFENSE
        damage /= 1.05
    end
    # Substitute takes the damage
    if target.damageState.substitute
        damage = target.effects[PBEffects::Substitute] if damage>target.effects[PBEffects::Substitute]
        target.damageState.hpLost       = damage
        target.damageState.totalHPLost += damage
        return
    end
    # Disguise takes the damage
    return if target.damageState.disguise
    # Target takes the damage
    if damage>=target.hp
        damage = target.hp
        # Survive a lethal hit with 1 HP effects
        if nonLethal?(user,target)
            damage -= 1
        elsif target.effects[PBEffects::Endure]
            target.damageState.endured = true
            damage -= 1
        elsif damage==target.totalhp
            if target.hasActiveAbility?(:STURDY) && !@battle.moldBreaker
                target.damageState.sturdy = true
                damage -= 1
            elsif target.hasActiveItem?(:FOCUSSASH) && target.hp==target.totalhp
                target.damageState.focusSash = true
                damage -= 1
            elsif target.hasActiveItem?(:FOCUSBAND) && @battle.pbRandom(100)<10
                target.damageState.focusBand = true
                damage -= 1
            end
        end
    end
    damage = 0 if damage<0
    target.damageState.hpLost       = damage
    target.damageState.totalHPLost += damage
end
end
BattleHandlers::ItemOnSwitchIn.add(:ALPHABOND,
                                   proc { |item,battler,battle|
                                          battle.pbDisplay(_INTL("{1} bonds with its rage!",
                                                                 battler.pbThis))
                                        }
                                  )
BattleHandlers::ItemOnSwitchIn.add(:ALPHADEFENSE,
                                   proc { |item,battler,battle|
                                          battle.pbDisplay(_INTL("{1}'s aura protects them, they take 5% less damage!",
                                                                 battler.pbThis))
                                        }
                                  )
DebugMenuCommands.register("fillbag", {
                                       "parent"      => "itemsmenu",
                                       "name"        => _INTL("Fill Bag"),
                                       "description" => _INTL("Add a certain number of every item to the Bag."),
                                       "effect"      => proc {
                                                              params = ChooseNumberParams.new
                                                             params.setRange(1, Settings::BAG_MAX_PER_SLOT)
                                                             params.setInitialValue(1)
                                                             params.setCancelValue(0)
                                                             qty = pbMessageChooseNumber(_INTL("Choose the number of items."), params)
                                                             if qty > 0
                                                             GameData::Item.each { |i|
                                                                            if AlphaItems::ITEMS.include?(i.id)
                                                                                 next
                                                                                 end
                                                                            $PokemonBag.pbStoreItem(i.id, qty)
                                                                                 }
                                                             pbMessage(_INTL("The Bag was filled with {1} of each item.", qty))
                                                             end
                                                             }
                                      })
