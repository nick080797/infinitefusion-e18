#===============================================================================
# GhostBattle_ClassicPlus.rb
#===============================================================================
# This mod highlights the currently active Pokémon while darkening its allies
# during its action in non-EBDX battles. It elevates the active battler's Z-index,
# smoothly slides them to the "front" visually while sliding inactive allies 
# to the "back". 
# Additionally, it shows Type Icons for all player Pokémon next to their name.
#
# Boss Support:
# - Integrates with Multiplayer Mod boss battles
# - Adds a toggle to force 100% boss spawn in Mod Settings
# - Features a custom, EBDX-inspired boss UI
#
# ClassicBattle Absorb:
# - Automatically disables EBDX visuals (sets to Off) in the Multiplayer Settings, and Battle GUI to Type 2
#===============================================================================

#===============================================================================
# Mod Stat Lock (Fix for +0 Level Up)
#===============================================================================
$gb_suppress_calc_stats = false

class Pokemon
  if !method_defined?(:ghostmod_classicplus_level)
    alias ghostmod_classicplus_level level
    def level
      if $gb_suppress_calc_stats
        @level = growth_rate.level_from_exp(@exp) if !@level
        return @level
      end
      return ghostmod_classicplus_level
    end
  end
end

#===============================================================================
# Mod Settings: GhostBattle Configuration
#===============================================================================
#===============================================================================
# Mod Settings: GhostBattle Configuration
#===============================================================================
def pbGhostBattleRegisterSettings
  return unless defined?(ModSettingsMenu)

  unless ModSettingsMenu.categories.any? { |c| c[:name] == "Ghost Settings" }
    ModSettingsMenu.categories << {
      name: "Ghost Settings",
      priority: 85,
      description: "Settings for GhostXYZ mods",
      collapsed: true
    }
  end

  ModSettingsMenu.register(:gb_boss_spawn_rate, {
    name: "Battle: Boss Spawn Rate",
    type: :slider,
    category: "Ghost Settings",
    save_key: "gb_boss_spawn_rate",
    min: 0,
    max: 100,
    interval: 25,
    default: 0,
    description: "Adjust wild boss spawn rates. 0% uses standard odds. 100% forces a boss on every encounter."
  })

  ModSettingsMenu.register(:gb_databox_size, {
    name: "Battle: Data Box Size",
    type: :enum,
    category: "Ghost Settings",
    save_key: "gb_databox_size",
    values: ["Small", "Large"],
    default: 0,
    description: "Toggle the scale of battle data boxes."
  })

  ModSettingsMenu.register(:gb_active_opacity, {
    name: "Battle: Target Opacity",
    type: :slider,
    category: "Ghost Settings",
    save_key: "gb_active_opacity",
    min: 0,
    max: 100,
    interval: 5,
    default: 100,
    description: "Adjust the opacity of the active Pokemon that ISN'T the target."
  })

  # Ensure defaults are set if missing (e.g. on new save or after load)
  def ModSettingsMenu.gb_ensure_defaults
    # Target Opacity
    if ModSettingsMenu.get(:gb_active_opacity).nil?
      ModSettingsMenu.set(:gb_active_opacity, 100)
    end
    # Inactive Opacity
    if ModSettingsMenu.get(:gb_inactive_opacity).nil?
      ModSettingsMenu.set(:gb_inactive_opacity, 60)
    end
  end

  # Call once on load
  ModSettingsMenu.gb_ensure_defaults

  # Re-call on save load
  EventHandlers.add(:on_load_save_file, :ghost_battle_ensure_defaults) do |save_data|
    ModSettingsMenu.gb_ensure_defaults
  end if defined?(EventHandlers)

  ModSettingsMenu.register(:gb_inactive_opacity, {
    name: "Battle: Inactive Opacity",
    type: :slider,
    category: "Ghost Settings",
    save_key: "gb_inactive_opacity",
    min: 0,
    max: 100,
    interval: 5,
    default: 60,
    description: "Opacity of inactive allies and their data boxes (0-100)."
  })

  ModSettingsMenu.register(:gb_effectiveness_mode, {
    name: "Battle: Hints",
    type: :enum,
    category: "Ghost Settings",
    save_key: "gb_effectiveness_mode",
    values: ["Off", "Text", "Glow"],
    default: 0,
    description: "Display type effectiveness on target databoxes during battle."
  })

end

# Initialize if ModSettingsMenu is available. If not, queue for when it loads.
if defined?(ModSettingsMenu)
  pbGhostBattleRegisterSettings
else
  $MOD_SETTINGS_PENDING_REGISTRATIONS ||= []
  $MOD_SETTINGS_PENDING_REGISTRATIONS << proc { pbGhostBattleRegisterSettings }
end

def pbGhostGetDataboxScale
  if defined?(ModSettingsMenu)
    val = ModSettingsMenu.get(:gb_databox_size)
    return (val == 1) ? 1.0 : 0.5
  end
  return 0.5
end

def pbGhostGetActiveOpacity
  if defined?(ModSettingsMenu)
    val = ModSettingsMenu.get(:gb_active_opacity)
    return (val.nil? ? 255 : (val * 2.55).to_i)
  end
  return 255
end

def pbGhostGetInactiveOpacity
  if defined?(ModSettingsMenu)
    val = ModSettingsMenu.get(:gb_inactive_opacity)
    return (val.nil? ? 153 : (val * 2.55).to_i)
  end
  return 153 # 60% of 255
end

def pbGhostGetEffectivenessMode
  if defined?(ModSettingsMenu)
    return ModSettingsMenu.get(:gb_effectiveness_mode) || 0
  end
  return 0
end

def pbGhostUseType2UI?
  # Robust check: Check the system setting directly to avoid getting 
  # fooled by temporary menu overrides like $ghost_force_gui = 0
  res = $PokemonSystem.instance_variable_get(:@battlegui) rescue nil
  res ||= $PokemonSystem.battlegui rescue 0
  return true if res == 2 || res == 3 # Type 2 or Classic+
  return false
end

#===============================================================================
# Settings Injection: Classic+ UI (Standard Options Menu)
#===============================================================================
class EnumOption
  alias ghostmod_classicplus_initialize_native initialize
  def initialize(name, values, getProc, setProc, description = "")
    # Check for Battle GUI option (Commonly named "Battle GUI")
    # We use both name check and value contents check to be extremely robust
    is_battle_gui = (name == _INTL("Battle GUI") || name == "Battle GUI")
    is_battle_gui ||= (values.include?(_INTL("Type 2")) || values.include?("Type 2"))
    
    if is_battle_gui
      unless values.include?(_INTL("Classic+"))
        values.push(_INTL("Classic+"))
      end
    end
    ghostmod_classicplus_initialize_native(name, values, getProc, setProc, description)
  end
end

if defined?(PokemonOption_Scene)
  class PokemonOption_Scene
    # GHOST: guarded - without this, if this file's class-reopen code ever runs
    # twice, the alias re-points at the already-patched pbGetOptions instead of
    # the true original, making it call itself forever (SystemStackError,
    # uncaught by rescue StandardError -> silent crash, no dialog).
    alias ghostmod_classicplus_pbGetOptions pbGetOptions unless method_defined?(:ghostmod_classicplus_pbGetOptions)
    def pbGetOptions(inloadscreen = false)
      options = ghostmod_classicplus_pbGetOptions(inloadscreen)
      # Second-pass verification to ensure the value is present even if EnumOption hook was skipped
      options.each do |opt|
        if opt.respond_to?(:name) && (opt.name == _INTL("Battle GUI") || opt.name == "Battle GUI")
          if opt.respond_to?(:values) && !opt.values.include?(_INTL("Classic+"))
            opt.values.push(_INTL("Classic+"))
          end
        end
      end
      return options
    end
  end
end

# Safe forcing of Classic+ (3)
module GhostForceClassicPlus
  def pbStartScene(*args)
    return super(*args) if (@battle.class.to_s == "PokeBattle_SafariZone") rescue false
    if $PokemonSystem && ($PokemonSystem.battlegui.nil? || $PokemonSystem.battlegui == 0)
      $PokemonSystem.battlegui = 3
    end
    super(*args)
  end
end

class PokeBattle_Scene
  prepend GhostForceClassicPlus
end

if false && defined?(PokemonOption_Scene)
  # DIAGNOSTIC: disabled - bisecting native Options crash. This prepend was
  # written for battle scenes (@battle, PokeBattle_SafariZone) and appears to
  # have been mistakenly also applied to PokemonOption_Scene, whose
  # pbStartScene is otherwise unoverridden by PokemonGameOption_Scene - so
  # this WAS actually running every time the title-screen Options menu opened.
  class PokemonOption_Scene
    prepend GhostForceClassicPlus
  end
end

# Keep the on_load hook as a tertiary measure
EventHandlers.add(:on_load_save_file, :ghost_force_classic_plus) do |save_data|
  if $PokemonSystem && ($PokemonSystem.battlegui.nil? || $PokemonSystem.battlegui == 0)
    $PokemonSystem.battlegui = 3
  end
end if defined?(EventHandlers)

#===============================================================================
# Hook Wild Battle Methods to check for Bosses (Enables 1v1 Boss in 2v2/3v3 areas)
#===============================================================================
def pbGhostCheckBossSpawn(species, level)
  if defined?(BossSpawnHook) && defined?(BossConfig) && BossConfig.enabled?
    MultiplayerDebug.info("GHOST-BOSS", "Checking spawn for #{species} Lv#{level}...") if defined?(MultiplayerDebug)
    
    encounter = [species, level]
    player_parties = [($Trainer.party rescue [])]
    family_enabled = defined?(PokemonFamilyConfig) && PokemonFamilyConfig.system_enabled?
    initiator_sid = defined?(MultiplayerClient) ? MultiplayerClient.session_id.to_s : nil
    
    boss = BossSpawnHook.check_boss_spawn(encounter, 1, player_parties, family_enabled, initiator_sid)
    if boss
        MultiplayerDebug.info("GHOST-BOSS", "  SUCCESS! Boss #{boss.species} spawned.") if defined?(MultiplayerDebug)
        $boss_current_pokemon = boss
        setBattleRule("cannotRun")
        # Start boss battle - redirection to single core
        decision = pbWildBattleCore(boss)
        Events.onWildBattleEnd.trigger(nil, boss.species, boss.level, decision) if defined?(Events) && Events.respond_to?(:onWildBattleEnd)
        $boss_current_pokemon = nil
        return decision
    end
    MultiplayerDebug.info("GHOST-BOSS", "  No boss spawned.") if defined?(MultiplayerDebug)
  end
  return nil
end

# Hook pbDoubleWildBattle
alias ghost_boss_pbDoubleWildBattle pbDoubleWildBattle
def pbDoubleWildBattle(species1, level1, species2, level2, outcomeVar=1, canRun=true, canLose=false)
  boss_decision = pbGhostCheckBossSpawn(species1, level1)
  if boss_decision
    pbSet(outcomeVar, boss_decision)
    return (boss_decision != 2 && boss_decision != 5)
  end
  return ghost_boss_pbDoubleWildBattle(species1, level1, species2, level2, outcomeVar, canRun, canLose)
end

# Hook pbWildBattle
alias ghost_boss_pbWildBattle pbWildBattle
def pbWildBattle(species, level, outcomeVar=1, canRun=true, canLose=false)
  boss_decision = pbGhostCheckBossSpawn(species, level)
  if boss_decision
    pbSet(outcomeVar, boss_decision)
    return (boss_decision != 2 && boss_decision != 5)
  end
  return ghost_boss_pbWildBattle(species, level, outcomeVar, canRun, canLose)
end

# Hook pbWildBattleSpecific
alias ghost_boss_pbWildBattleSpecific pbWildBattleSpecific
def pbWildBattleSpecific(pokemon, outcomeVar=1, canRun=true, canLose=false)
  boss_decision = pbGhostCheckBossSpawn(pokemon.species, pokemon.level)
  if boss_decision
    pbSet(outcomeVar, boss_decision)
    return (boss_decision != 2 && boss_decision != 5)
  end
  return ghost_boss_pbWildBattleSpecific(pokemon, outcomeVar, canRun, canLose)
end

# Hook pbTripleWildBattle
alias ghost_boss_pbTripleWildBattle pbTripleWildBattle
def pbTripleWildBattle(species1, level1, species2, level2, species3, level3, outcomeVar=1, canRun=true, canLose=false)
  boss_decision = pbGhostCheckBossSpawn(species1, level1)
  if boss_decision
    pbSet(outcomeVar, boss_decision)
    return (boss_decision != 2 && boss_decision != 5)
  end
  return ghost_boss_pbTripleWildBattle(species1, level1, species2, level2, species3, level3, outcomeVar, canRun, canLose)
end

# Hook pb1v3WildBattle
alias ghost_boss_pb1v3WildBattle pb1v3WildBattle
def pb1v3WildBattle(species1, level1, species2, level2, species3, level3, outcomeVar=1, canRun=true, canLose=false)
  boss_decision = pbGhostCheckBossSpawn(species1, level1)
  if boss_decision
    pbSet(outcomeVar, boss_decision)
    return (boss_decision != 2 && boss_decision != 5)
  end
  return ghost_boss_pb1v3WildBattle(species1, level1, species2, level2, species3, level3, outcomeVar, canRun, canLose)
end

#===============================================================================
# Hook BossConfig to respect the force spawn setting
#===============================================================================
if defined?(BossConfig)
  module BossConfig
    class << self
      alias ghost_boss_enabled enabled?
      def enabled?
        if defined?(ModSettingsMenu)
          rate = ModSettingsMenu.get(:gb_boss_spawn_rate) rescue 0
          return true if rate && rate > 0
        end
        return ghost_boss_enabled
      end

      alias ghost_get_spawn_chance get_spawn_chance
      def get_spawn_chance
        if defined?(ModSettingsMenu)
          rate = ModSettingsMenu.get(:gb_boss_spawn_rate)
          if rate && rate > 0
            # If our internal roll succeeds, return 1 so that rand(1) == 0 in SpawnHook
            # Otherwise return a massive number so that rand(massive) != 0
            return (rand(100) < rate) ? 1 : 9999999
          end
        end
        return ghost_get_spawn_chance
      end
    end
  end
end

#===============================================================================
# ClassicBattle logic (Absorbed)
#===============================================================================
if defined?(PokemonSystem)
  class PokemonSystem
    # Override the getter to ALWAYS return 2 (Type 2) when GhostBattle is installed.
    # This bypasses the save file value entirely, ensuring the visual style is active.
    if method_defined?(:battlegui)
      alias ghost_battlegui battlegui unless method_defined?(:ghost_battlegui)
    end
    def battlegui
      return $ghost_force_gui if defined?($ghost_force_gui) && $ghost_force_gui
      res = respond_to?(:ghost_battlegui) ? ghost_battlegui : (@battlegui || 0)
      # Default to 3 if Off (0)
      if res == 0 || res.nil?
        @battlegui = 3
        return 3
      end
      return res
    end
    
    # Force EBDX Visuals to Off (0) to prevent visual conflicts.
    if method_defined?(:mp_ebdx_enabled)
      alias ghost_mp_ebdx_enabled mp_ebdx_enabled unless method_defined?(:ghost_mp_ebdx_enabled)
    end
    def mp_ebdx_enabled
      return 0
    end
  end
end

if defined?(EBDXToggle)
  module EBDXToggle
    def self.enabled?
      return false
    end
  end
end

class PokeBattle_Scene
  #-----------------------------------------------------------------------------
  # Update styles based on the active battler and an optional target battler
  #-----------------------------------------------------------------------------
  def pbRefreshBattlerTones(active_idx, target_idx = -1)
    return if (@battle.class.to_s == "PokeBattle_SafariZone") rescue false
    return if $PokemonSystem.mp_ebdx_enabled && $PokemonSystem.mp_ebdx_enabled == 1 rescue false
    
    active_battler = (active_idx.nil? || active_idx < 0) ? nil : @battle.battlers[active_idx]
    target_battler = (target_idx.nil? || target_idx < 0) ? nil : @battle.battlers[target_idx]
    
    active_opacity = pbGhostGetActiveOpacity
    inactive_opacity = pbGhostGetInactiveOpacity
    
    # Reset all if no active battler or invalid index
    if active_battler.nil? || (active_battler.respond_to?(:fainted?) ? active_battler.fainted? : false)
      @sprites.each do |key, sprite|
        next unless key.to_s.start_with?("pokemon_") && sprite.is_a?(PokemonBattlerSprite)
        sprite.tone = Tone.new(0, 0, 0)
        # sprite.opacity = 255 # Only affect databoxes
        if sprite.respond_to?(:ghostmod_target_offset_x=)
            sprite.ghostmod_target_offset_x = 0
            sprite.ghostmod_target_offset_y = 0
        end
        # Reset Z-index and Opacity
        idx = sprite.index
        db = @sprites["dataBox_#{idx}"]
        if db
          db.opacity = 255
          if db.respond_to?(:ghostmod_highlighted=)
            db.ghostmod_highlighted = false
          end
        end
        if (idx % 2) == 0
          sprite.z = 50 + 5 * (idx / 2)
        else
          sprite.z = 50 - 5 * ((idx + 1) / 2)
        end
      end
      return
    end

    @sprites.each do |key, sprite|
      next unless key.to_s.start_with?("pokemon_") && (sprite.is_a?(PokemonBattlerSprite) rescue false)
      
      idx = sprite.index
      battler = @battle.battlers[idx]
      next if !battler
      
      if (sprite.is_a?(PokemonBattlerSprite) rescue false) && (battler.respond_to?(:fainted?) ? battler.fainted? : false)
        sprite.ghostmod_target_offset_x = 0 if sprite.respond_to?(:ghostmod_target_offset_x=)
        sprite.ghostmod_target_offset_y = 0 if sprite.respond_to?(:ghostmod_target_offset_y=)
        next
      end

      is_primary = (idx == active_idx)
      is_target  = (idx == target_idx)
      is_boss    = battler.is_boss? rescue false # Multiplayer Mod check

      # Determine side sizes and key positions dynamically per side
      side_size = battler.opposes?(0) ? @battle.pbSideSize(1) : @battle.pbSideSize(0)
      front_index = -1
      back_index = -1
      
      if side_size == 1
        front_index = idx
        back_index = idx
      elsif side_size == 2 || side_size == 3
        front_index = 2
        back_index = 0
      end

      # Bosses are ALWAYS primary visually and never slide
      if is_boss
        sprite.tone = Tone.new(0, 0, 0)
        # sprite.opacity = active_opacity
        sprite.z = 80 # Even higher than normal primary
        sprite.ghostmod_target_offset_x = 0 if sprite.respond_to?(:ghostmod_target_offset_x=)
        sprite.ghostmod_target_offset_y = 0 if sprite.respond_to?(:ghostmod_target_offset_y=)
        
        db = @sprites["dataBox_#{idx}"]
        if db
          db.opacity = active_opacity
          if db.respond_to?(:ghostmod_highlighted=)
              db.ghostmod_highlighted = true
          end
        end
        next
      end

      if is_primary || is_target
        sprite.tone = Tone.new(0, 0, 0)
        # sprite.opacity = active_opacity
        sprite.z = 70 
        
        db = @sprites["dataBox_#{idx}"]
        if db
          db.opacity = active_opacity
          if db.respond_to?(:ghostmod_highlighted=)
              db.ghostmod_highlighted = true
          end
        end

        # Slide forward ONLY if it's the player team
        if !battler.opposes?(0) && sprite.respond_to?(:ghostmod_target_offset_x=)
            p_base = PokeBattle_SceneConstants.pbBattlerPosition(idx, sprite.sideSize)
            p_target = PokeBattle_SceneConstants.pbBattlerPosition(front_index, sprite.sideSize)
            sprite.ghostmod_target_offset_x = p_target[0] - p_base[0]
            sprite.ghostmod_target_offset_y = p_target[1] - p_base[1]
        else
            sprite.ghostmod_target_offset_x = 0 if sprite.respond_to?(:ghostmod_target_offset_x=)
            sprite.ghostmod_target_offset_y = 0 if sprite.respond_to?(:ghostmod_target_offset_y=)
        end
        
      elsif (!battler.opposes?(active_idx)) || (target_battler && !battler.opposes?(target_idx))
        # Ally team of either the attacker or the target: darkened tone
        sprite.tone = Tone.new(-80, -80, -80)
        # sprite.opacity = inactive_opacity # Only affect databoxes
        
        db = @sprites["dataBox_#{idx}"]
        if db
          db.opacity = inactive_opacity
          if db.respond_to?(:ghostmod_highlighted=)
              db.ghostmod_highlighted = false
          end
        end

        # Slide backward ONLY if it's the player team
        if !battler.opposes?(0) && sprite.respond_to?(:ghostmod_target_offset_x=)
            p_base = PokeBattle_SceneConstants.pbBattlerPosition(idx, sprite.sideSize)
            p_target = PokeBattle_SceneConstants.pbBattlerPosition(back_index, sprite.sideSize)
            sprite.ghostmod_target_offset_x = p_target[0] - p_base[0]
            sprite.ghostmod_target_offset_y = p_target[1] - p_base[1]
        else
            sprite.ghostmod_target_offset_x = 0 if sprite.respond_to?(:ghostmod_target_offset_x=)
            sprite.ghostmod_target_offset_y = 0 if sprite.respond_to?(:ghostmod_target_offset_y=)
        end
        
        if (idx % 2) == 0
          sprite.z = 50 + 5 * (idx / 2)
        else
          sprite.z = 50 - 5 * ((idx + 1) / 2)
        end
      else
        # Neutral coloring fallback
        sprite.tone = Tone.new(0, 0, 0)
        # sprite.opacity = 255 # Only affect databoxes
        sprite.ghostmod_target_offset_x = 0 if sprite.respond_to?(:ghostmod_target_offset_x=)
        sprite.ghostmod_target_offset_y = 0 if sprite.respond_to?(:ghostmod_target_offset_y=)
        
        db = @sprites["dataBox_#{idx}"]
        db.opacity = 255 if db
        
        if (idx % 2) == 0
          sprite.z = 50 + 5 * (idx / 2)
        else
          sprite.z = 50 - 5 * ((idx + 1) / 2)
        end
      end
    end
    
    # GHOST: Effectiveness Indicators
    if pbGhostGetEffectivenessMode != 0
      move = @ghostmod_effectiveness_move
      user = active_battler
      
      # GHOST FIX: Use a localized target index to handle fallbacks
      check_target_idx = target_idx
      
      # GHOST FIX: If we are not explicitly in targeting mode, but have a target_idx 
      # matching the user, it means pbSelectBattler for the UI has forced focus.
      # We ignore this for effectiveness to avoid self-highlighting.
      if target_idx != -1 && target_idx == active_idx && !@ghostmod_in_targeting
        check_target_idx = -1
      end

      # Determine default target if browsing (check_target_idx == -1)
      if move && user && check_target_idx == -1
        @battle.battlers.each_with_index do |ob, oi|
          if ob && ob.opposes?(user.index) && !(ob.respond_to?(:fainted?) ? ob.fainted? : false)
            break
          end
        end
      end

      @battle.battlers.each_with_index do |b, i|
        next if !b
        db = @sprites["dataBox_#{i}"]
        sb = @sprites["pokemon_#{i}"]
        next if !db || !db.is_a?(PokemonDataBox)
        
        should_show = false
        if move && user && move.damagingMove? && b.opposes?(active_idx)
          # GHOST: Highlight opponents only
          if check_target_idx != -1
            # Explicit Targeting
            should_show = (i == check_target_idx)
            # Support AOE highlights in target menu (Opponents Only)
            target_id = move.pbTarget(user).id
            case target_id
            when :AllNearFoes, :AllFoes, :AllNearOthers, :AllBattlers, :RandomNearFoe
               should_show = true # Already filtered by b.opposes?(active_idx)
            end
          else
            # Move Browsing: Highlight ALL potential opponent targets
            should_show = true # Already filtered by b.opposes?(active_idx)
          end
        end
        
        if should_show
          db.pbShowEffectiveness(move, user, b)
          sb.pbShowEffectiveness(db.ghostmod_effectiveness) if sb.respond_to?(:pbShowEffectiveness)
        else
          db.pbHideEffectiveness
          sb.pbHideEffectiveness if sb.respond_to?(:pbHideEffectiveness)
        end
      end
    end
  end

  # Refresh tones on command and fight menus
  alias ghostmod_highlight_pbCommandMenu pbCommandMenu
  def pbCommandMenu(idxBattler, firstAction, &block)
    pbRefreshBattlerTones(idxBattler)
    old_force = $ghost_force_gui
    $ghost_force_gui = 0 if $PokemonSystem.battlegui == 3
    ret = ghostmod_highlight_pbCommandMenu(idxBattler, firstAction, &block)
    $ghost_force_gui = old_force
    pbRefreshBattlerTones(-1)
    return ret
  end

  alias ghostmod_highlight_pbFightMenu pbFightMenu
  def pbFightMenu(idxBattler, megaEvoPossible = false, &block)
    pbRefreshBattlerTones(idxBattler)
    old_force = $ghost_force_gui
    $ghost_force_gui = 0 if $PokemonSystem.battlegui == 3
    ret = ghostmod_highlight_pbFightMenu(idxBattler, megaEvoPossible, &block)
    $ghost_force_gui = old_force
    # GHOST: Clear effectiveness context
    @ghostmod_effectiveness_move = nil
    @ghostmod_active_battler_idx = -1
    @sprites.each { |ki, si| si.pbHideEffectiveness if si.is_a?(PokemonDataBox) }
    pbRefreshBattlerTones(-1)
    return ret
  end
end

class PokeBattle_Battler
  alias ghostmod_highlight_pbProcessTurn pbProcessTurn
  def pbProcessTurn(choice, tryFlee = true)
    if @battle.scene.is_a?(PokeBattle_Scene) && !(@battle.scene.class.name.include?("EBDX"))
      @battle.scene.pbRefreshBattlerTones(self.index)
    end
    ret = ghostmod_highlight_pbProcessTurn(choice, tryFlee)
    if @battle.scene.is_a?(PokeBattle_Scene) && !(@battle.scene.class.name.include?("EBDX"))
      @battle.scene.pbRefreshBattlerTones(-1)
    end
    return ret
  end
end

class PokemonBattlerSprite < RPG::Sprite
  # GHOST: @isSub is set throughout this class (initialize/setSubstitute/
  # removeSubstitute/setPokemonBitmap) but had no reader - refreshStatus's
  # sprite.isSub checks crashed with NoMethodError. Exposed it here.
  attr_accessor :isSub
  attr_accessor :ghostmod_target_offset_x
  attr_accessor :ghostmod_target_offset_y
  attr_accessor :ghostmod_current_offset_x
  attr_accessor :ghostmod_current_offset_y
  attr_accessor :ghostmod_in_animation

  alias ghostmod_highlight_initialize initialize
  def initialize(viewport, sideSize, index, battleAnimations)
    ghostmod_highlight_initialize(viewport, sideSize, index, battleAnimations)
    @ghostmod_target_offset_x = 0
    @ghostmod_target_offset_y = 0
    @ghostmod_current_offset_x = 0
    @ghostmod_current_offset_y = 0
    @ghostmod_in_animation = false
    
    # GHOST: Outline Glow Sprites (Two layers for "softer" look)
    @ghostmod_glow_sprite = Sprite.new(viewport)
    @ghostmod_glow_sprite.z = self.z - 1
    @ghostmod_glow_sprite.visible = false
    
    @ghostmod_glow_sprite_2 = Sprite.new(viewport)
    @ghostmod_glow_sprite_2.z = self.z - 2
    @ghostmod_glow_sprite_2.visible = false
    
    # GHOST: Substitute Opacity tracking
    @isSub = false
    @ghostmod_opacity_dimmed = false
  end

  alias ghostmod_highlight_dispose dispose
  def dispose
    @ghostmod_glow_sprite.dispose if @ghostmod_glow_sprite && !@ghostmod_glow_sprite.disposed?
    @ghostmod_glow_sprite_2.dispose if @ghostmod_glow_sprite_2 && !@ghostmod_glow_sprite_2.disposed?
    ghostmod_highlight_dispose
  end

  # GHOST: Substitute handling
  # The actual visual change (opacity drop) is handled in update.
  def setSubstitute(pokemon = nil, back = false)
    @isSub = true
  end

  def removeSubstitute
    @isSub = false
  end

  # GHOST: Override setPokemonBitmap to clear substitute state when the
  # battler changes (e.g. after Baton Pass sends out a new Pokemon).
  # The scene's substitueAll will re-apply if PBEffects::Substitute > 0.
  alias ghostmod_substitute_setPokemonBitmap setPokemonBitmap
  def setPokemonBitmap(pkmn, back = false)
    @isSub = false
    @ghostmod_opacity_dimmed = false
    ghostmod_substitute_setPokemonBitmap(pkmn, back)
  end

  alias ghostmod_highlight_x_assign x=
  def x=(value)
    @spriteX = value
    self.mirror = true if @back && self.respond_to?(:mirror=)
    if @ghostmod_in_animation
      super(value + (@spriteXExtra || 0))
    else
      val = value + (@ghostmod_current_offset_x || 0) + (@spriteXExtra || 0)
      super(val)
    end
  end

  alias ghostmod_highlight_y_assign y=
  def y=(value)
    @spriteY = value
    self.mirror = true if @back && self.respond_to?(:mirror=)
    if @ghostmod_in_animation
      super(value + (@spriteYExtra || 0))
    else
      val = value + (@ghostmod_current_offset_y || 0) + (@spriteYExtra || 0)
      super(val)
    end
  end

  alias ghostmod_highlight_update update
  def update(frameCounter = 0)
    # GHOST: Normal update always runs — we no longer swap bitmaps for substitute.
    ghostmod_highlight_update(frameCounter)
    
    dist_x = (@ghostmod_target_offset_x || 0) - (@ghostmod_current_offset_x || 0)
    dist_y = (@ghostmod_target_offset_y || 0) - (@ghostmod_current_offset_y || 0)
    
    smoothing_factor = 0.12
    
    if dist_x.abs < 0.1
      @ghostmod_current_offset_x = @ghostmod_target_offset_x
    else
      @ghostmod_current_offset_x += dist_x * smoothing_factor
    end
    if dist_y.abs < 0.1
      @ghostmod_current_offset_y = @ghostmod_target_offset_y
    else
      @ghostmod_current_offset_y += dist_y * smoothing_factor
    end

    if !@ghostmod_in_animation
      self.x = @spriteX if @spriteX
      self.y = @spriteY if @spriteY
    end
    
    # GHOST: Effectiveness Glow (Multi-layered Pulsing Outline)
    if pbGhostGetEffectivenessMode == 2 && @ghostmod_effectiveness_color && self.visible && self.opacity > 0 && self.bitmap && !self.bitmap.disposed?
      # Calculate pulse factor (0.0 to 1.0)
      pulse = (Math.sin(Graphics.frame_count * 0.1) + 1.0) / 2.0
      
      # Compensation for off-center origin when zooming
      
      # Layer 1: Inner Glow
      @ghostmod_glow_sprite.visible = true
      @ghostmod_glow_sprite.ox = self.ox
      @ghostmod_glow_sprite.oy = self.oy
      @ghostmod_glow_sprite.zoom_x = self.zoom_x * (1.05 + pulse * 0.01)
      @ghostmod_glow_sprite.zoom_y = self.zoom_y * (1.02 + pulse * 0.01)
      @ghostmod_glow_sprite.x = self.x
      @ghostmod_glow_sprite.y = self.y
      @ghostmod_glow_sprite.mirror = self.mirror
      @ghostmod_glow_sprite.opacity = (self.opacity * (0.4 + pulse * 0.1)).to_i
      @ghostmod_glow_sprite.color = @ghostmod_effectiveness_color
      @ghostmod_glow_sprite.z = self.z - 1
      
      # Layer 2: Outer Glow
      @ghostmod_glow_sprite_2.visible = true
      @ghostmod_glow_sprite_2.ox = self.ox
      @ghostmod_glow_sprite_2.oy = self.oy
      @ghostmod_glow_sprite_2.zoom_x = self.zoom_x * (1.11 + pulse * 0.02)
      @ghostmod_glow_sprite_2.zoom_y = self.zoom_y * (1.04 + pulse * 0.02)
      @ghostmod_glow_sprite_2.x = self.x
      @ghostmod_glow_sprite_2.y = self.y
      @ghostmod_glow_sprite_2.mirror = self.mirror
      @ghostmod_glow_sprite_2.opacity = (self.opacity * (0.2 + pulse * 0.1)).to_i
      @ghostmod_glow_sprite_2.color = @ghostmod_effectiveness_color
      @ghostmod_glow_sprite_2.z = self.z - 2
      
      # Sync Bitmaps
      if @ghostmod_glow_sprite.bitmap != self.bitmap
          @ghostmod_glow_sprite.bitmap = self.bitmap
          @ghostmod_glow_sprite_2.bitmap = self.bitmap
      end
    else
      if @ghostmod_glow_sprite && !@ghostmod_glow_sprite.disposed?
        @ghostmod_glow_sprite.visible = false 
        @ghostmod_glow_sprite_2.visible = false
      end
      # Reset full tint if we were using it before
      self.color = Color.new(0,0,0,0) if self.color.alpha > 0 && pbGhostGetEffectivenessMode != 0
    end
    
    # GHOST: Substitute Opacity Dimming
    if @isSub && self.bitmap && !self.bitmap.disposed?
      # Ensure the pokemon is forced to be visible, but dimmed (60% opacity)
      self.visible = true
      self.opacity = (255 * 0.6).to_i
      @ghostmod_opacity_dimmed = true
    elsif @ghostmod_opacity_dimmed
      # Restore full opacity when substitute is broken/removed
      self.opacity = 255
      @ghostmod_opacity_dimmed = false
    end
  end

  def pbShowEffectiveness(multiplier)
    case multiplier
    when ->(m) { m > 8 };   @ghostmod_effectiveness_color = Color.new(104, 240, 104, 200) # Green
    when ->(m) { m == 8 };  @ghostmod_effectiveness_color = Color.new(220, 220, 220, 200) # Grey-White (Neutral)
    when ->(m) { m == 0 };  @ghostmod_effectiveness_color = Color.new(240, 104, 104, 200) # Red (Immune)
    when ->(m) { m < 8 };   @ghostmod_effectiveness_color = Color.new(240, 160, 60, 200)  # Orange (Resisted)
    else; @ghostmod_effectiveness_color = nil
    end
  end

  def pbHideEffectiveness
    @ghostmod_effectiveness_color = nil
    self.color = Color.new(0,0,0,0) if self.color
  end

  def ghostmod_slide_done?
    u_ox = @ghostmod_current_offset_x || 0
    u_oy = @ghostmod_current_offset_y || 0
    t_ox = @ghostmod_target_offset_x || 0
    t_oy = @ghostmod_target_offset_y || 0
    return (u_ox - t_ox).abs < 0.1 && (u_oy - t_oy).abs < 0.1
  end
end

#-----------------------------------------------------------------------------
# Display Player Pokémon Types as a cleanly tracked overlay sprite
#-----------------------------------------------------------------------------
class PokemonDataBox < SpriteWrapper
  attr_accessor :ghostmod_effectiveness
  alias ghostmod_classicplus_initialize_graphics initialize
  def initialize(battler, sideSize, viewport)
    # GHOST: base PokemonDataBox#initialize never stores sideSize as an ivar
    # (it's only a local param forwarded to initializeDataBoxGraphic), but our
    # x=/y= overrides below read @sideSize directly - without this it's nil
    # and crashes the first time a databox is repositioned.
    # Also guard against sideSize itself arriving nil (seen from some raid/
    # multi-mon wild battles, where PokeBattle_Battle#pbEnsureParticipants can
    # rewrite @sideSizes from a nil pbAbleTeamCounts entry before the scene
    # creates its databoxes) - default to 1 (single-battle layout) rather than
    # propagate nil.
    # MUST be set before the aliased call below: it chains into
    # initializeOtherGraphics, which itself calls self.y= (triggering our
    # override) before this method would otherwise get a chance to run.
    @sideSize = sideSize || 1
    old_force = $ghost_force_gui
    $ghost_force_gui = 2 if pbGhostUseType2UI?
    ghostmod_classicplus_initialize_graphics(battler, sideSize, viewport)
    $ghost_force_gui = old_force
    # GHOST: Force EXP bar presence for player Pokémon to ensure animation logic triggers
    @showExp = true if !@battler.opposes?(0)
    # Expand bitmap width to prevent clipping of right-aligned text (Level/Gender/Effectiveness)
    # We use 512 to give plenty of overflow room while keeping the logical position stable.
    if self.bitmap
      if self.bitmap.width < 512
        new_bmp = Bitmap.new(512, self.bitmap.height)
        self.bitmap = new_bmp
      end
      # GHOST: Force a refresh to ensure all variables (like name_width) are initialized.
      refresh
    end
  end

  alias ghostmod_unified_types_initializeOtherGraphics initializeOtherGraphics
  def initializeOtherGraphics(viewport)
    old_force = $ghost_force_gui
    $ghost_force_gui = 2 if pbGhostUseType2UI?
    ghostmod_unified_types_initializeOtherGraphics(viewport)
    $ghost_force_gui = old_force
    
    # GHOST: Restore correct scaling for all databox elements
    s_zoom = pbGhostGetDataboxScale
    self.zoom_x = s_zoom
    self.zoom_y = s_zoom
    @sprites.each do |key, s|
      next if !s || s.disposed? || !s.respond_to?(:zoom_x=)
      s.zoom_x = s_zoom
      s.zoom_y = s_zoom
    end

    # GHOST: Hard-hide the EXP bar and any potential background containers for enemies immediately.
    # Also ensures any "orphaned" vanilla background sprites are suppressed for player.
    if @sprites
      @sprites.each do |key, s|
        next if !s || s.disposed?
        # Hide any sprite that looks like an EXP background or container
        if key.to_s.downcase.include?("exp") && key.to_s != "expBar"
          s.visible = false
          s.opacity = 0
        end
      end
    end

    if @expBar && @battler && @battler.opposes?(0)
      @expBar.visible = false
      @expBar.opacity = 0
    end
    
    @ghostmod_exp_animating = false
    @ghostmod_highlighted = false

    self.opacity = 255 # Trigger the opacity calculation
    # GHOST: Initialize logical coordinates to prevent drift
    @logical_x = self.x
    @logical_y = self.y
    # GHOST: Force a coordinate update so sub-sprites are correctly scaled/aligned on start
    # This prevents the "snapping" issue where they start un-zoomed.
    self.x = @logical_x

    self.y = @logical_y
    ghostmod_sync_sub_visibility
  end

  def pbShowEffectiveness(move, user, target)
    return if !move || !user || !target
    move_type = move.pbCalcType(user)
    @ghostmod_effectiveness = move.pbCalcTypeMod(move_type, user, target)
    refresh
  end

  def pbHideEffectiveness
    return if @ghostmod_effectiveness.nil?
    @ghostmod_effectiveness = nil
    refresh
  end

  def drawEffectiveness(level_x)
    return if pbGhostGetEffectivenessMode == 0 || @ghostmod_effectiveness.nil?
    
    bmp = self.bitmap
    
    text = ""
    color = Color.new(255, 255, 255)
    shadow = Color.new(0, 0, 0)
    
    if @ghostmod_effectiveness > 8
      text = (@ghostmod_effectiveness > 16) ? "SUPER x4" : "SUPER x2"
      color = Color.new(104, 240, 104) # Green
    elsif @ghostmod_effectiveness == 0
      text = "IMMUNE"
      color = Color.new(240, 104, 104) # Red
    elsif @ghostmod_effectiveness < 8
      text = (@ghostmod_effectiveness < 4) ? "WEAK x0.25" : "WEAK x0.5"
      color = Color.new(240, 160, 60) # Orange
    elsif @ghostmod_effectiveness == 8
      text = "NEUTRAL x1"
      color = Color.new(220, 220, 220) # Grey-White
    else
      return 
    end
    
    mode = pbGhostGetEffectivenessMode
    if mode == 1 # Text
      pbSetSystemFont(bmp)
      s_zoom = pbGhostGetDataboxScale
      is_small = (s_zoom < 1.0)
      
      # GHOST: Perfect Inline Alignment
      # Now used dynamic level_x from refresh to place text exactly after Lv. number.
      # A 2-3 digit level is approx 35-45 pixels wide on the bitmap.
      # We offset by 58 to sit close to the level number.
      eff_x = level_x + 58
      eff_y = is_small ? 2 : 0 # Shifted up to align with name/level top.
      
      # Use a much larger font for effectiveness text to match name/level legibility
      bmp.font.size = is_small ? 22 : 24
      
      pbDrawTextPositions(bmp, [[text, eff_x, eff_y, 0, color, shadow]])
    end
  end

  def ghostmod_sync_sub_visibility
    return if !@sprites
    sub_vis = self.visible && self.opacity > 0
    
    # Hard guard: If the databox is meant to be hidden (fade out or intro), hide everything.
    # This prevents sub-sprites from "floating" early.
    sub_vis = false if self.opacity == 0
    
    if @sprites["typeDisplay"]
      @sprites["typeDisplay"].visible = false
    end
    if @hpBar && !@hpBar.disposed?
      @hpBar.visible = sub_vis
    end
    if @hpNumbers && !@hpNumbers.disposed?
      @hpNumbers.visible = sub_vis
    end
    # GHOST: EXP bar visibility should follow the databox visibility
    if @expBar && !@expBar.disposed?
      @expBar.visible = sub_vis && @showExp && !@battler.opposes?(0)
    end
  end
  
  # GHOST: Unified coordinate system for the EXP bar.
  # Tweak these values here to update both the fill-sprite and the background tray!
  def pbGhostEXPParams
    if @sideSize == 1
      eb_x = -25
      eb_y = 60
      eb_w = 128
    else
      eb_x = 31
      eb_y = 60
      eb_w = 128
    end
    eb_h = 6
    return eb_x, eb_y, eb_w, eb_h
  end

  alias ghostmod_unified_types_visible_assign visible=
  def visible=(value)
    ghostmod_unified_types_visible_assign(value)
    ghostmod_sync_sub_visibility
  end

  alias ghostmod_unified_types_x_assign x=
  def x=(value)
    @logical_x = value
    s_zoom = pbGhostGetDataboxScale
    # Use the logical width (260) for the side-pinning offset calculation.
    # We use 260 because that's the standard Type 2 width, ensuring 
    # the databox doesn't jump when we expanded the bitmap to 320.
    logical_bw = 260
    
    if @battler.opposes?(0)
      # ENEMY: Usually on the LEFT, keep left-aligned
      adjusted_x = @logical_x
    else
      # PLAYER: Usually on the RIGHT, pin right edge relative to animation position
      # Use the shrinking width to offset 'value' and keep the right edge relative
      adjusted_x = @logical_x + (logical_bw * (0.85 - s_zoom)).to_i
    end

    ghostmod_unified_types_x_assign(adjusted_x)
    
    if pbGhostUseType2UI?
      # Type 2 (Classic+) requires different offsets for 1v1 Player vs others
      if @sideSize == 1 && !@battler.opposes?(0)
        hp_offset = 12
        # GHOST: Nudge HP bar 2px left in small mode to fix alignment
        hp_x_nudge = (s_zoom < 1.0) ? 2 : 0
      else
        hp_offset = 31
        hp_x_nudge = 0
      end
      # GHOST: Synchronized offsets via central config
      eb_x, _, _, _ = pbGhostEXPParams
      @hpBar.x      = adjusted_x + (@spriteBaseX + hp_offset) * s_zoom - hp_x_nudge if @hpBar
      @expBar.x     = adjusted_x + (@spriteBaseX + eb_x) * s_zoom if @expBar && !@battler.opposes?(0)
      @hpNumbers.x  = adjusted_x + (@spriteBaseX + 80) * s_zoom if @hpNumbers
      @statusIcon.x = adjusted_x + (@spriteBaseX + 24) * s_zoom if @statusIcon
    else
      # AnimeFusionMerge: matches the vanilla track-alignment fix in
      # 004_PokeBattle_SceneElements.rb - measured track left-edge is
      # @spriteBaseX+10, not +12 (see that file's x= for the pixel data).
      # This branch (Type 1 UI) duplicates that same unscaled formula, and
      # since this method fully replaces vanilla's (no super call), the
      # base-file fix alone has no effect while this mod is loaded.
      @hpBar.x      = adjusted_x + (@spriteBaseX + 10) * s_zoom if @hpBar
      @expBar.x     = adjusted_x + (@spriteBaseX + 24) * s_zoom if @expBar && !@battler.opposes?(0)
      @hpNumbers.x  = adjusted_x + (@spriteBaseX + 80) * s_zoom if @hpNumbers
      @statusIcon.x = adjusted_x + (@spriteBaseX + 24) * s_zoom if @statusIcon
    end
  end

  def x; return @logical_x || super; end

  alias ghostmod_unified_types_y_assign y=
  def y=(value)
    @logical_y = value
    s_zoom = pbGhostGetDataboxScale
    adjusted_y = @logical_y
    
    # Reposition to handle grouping (pulling boxes together when scaled down)
    # index_in_side logic (simplified: battler index / 2 is the vertical "slot")
    # We want to subtract some height based on the scale difference
    bh = (self.bitmap ? self.bitmap.height : 60)
    overlap_shift = (bh * (0.85 - s_zoom)).to_i
    idx_in_side = @battler.index / 2
    
    if @battler.opposes?(0)
      # ENEMY: Pin top edge to @logical_y + 8
      adjusted_y = @logical_y + 8
      # Pull UP towards the top-most box to close shrinking gaps
      adjusted_y -= (idx_in_side * overlap_shift)
    else
      # PLAYER: Pin bottom edge relative to its original 0.85 baseline
      # Boxes above move down further to close gaps
      shift_factor = (@sideSize - idx_in_side)
      adjusted_y = @logical_y + (shift_factor * overlap_shift).to_i
      
      # Correct the original constant padding ratio
      adjusted_y += (bh * 0.15 * s_zoom / 0.85).to_i
    end
    ghostmod_unified_types_y_assign(adjusted_y)

    if pbGhostUseType2UI?
      case @sideSize
      when 1; hp_y_off = 38; st_y_off = (@battler.opposes?(0) ? 49 : 52)
      when 2,3; hp_y_off = 37; st_y_off = (@battler.opposes?(0) ? 49 : 52)
      else;       hp_y_off = 38; st_y_off = (@battler.opposes?(0) ? 49 : 52)
      end
      _, eb_y, _, _ = pbGhostEXPParams
      # GHOST: Nudge HP bar down by 1px in small mode to fix alignment with container
      nudge = (s_zoom < 1.0) ? 1 : 0
      @hpBar.y      = adjusted_y + (hp_y_off * s_zoom).to_i + nudge if @hpBar
      # GHOST: Unified Y positioning for the EXP bar sprite
      @expBar.y     = adjusted_y + (eb_y * s_zoom).to_i if @expBar && !@battler.opposes?(0)
      @hpNumbers.y  = adjusted_y + (52 * s_zoom).to_i if @hpNumbers
      @statusIcon.y = adjusted_y + (st_y_off * s_zoom).to_i + nudge if @statusIcon
    else
      @hpBar.y      = adjusted_y + (40 * s_zoom).to_i if @hpBar
      @expBar.y     = adjusted_y + (64 * s_zoom).to_i if @expBar && !@battler.opposes?(0)
      @hpNumbers.y  = adjusted_y + (52 * s_zoom).to_i if @hpNumbers
      @statusIcon.y = adjusted_y + ((@battler.opposes?(0) ? 49 : 52) * s_zoom).to_i if @statusIcon
    end
  end

  def y; return @logical_y || super; end

  alias ghostmod_unified_types_z_assign z=
  def z=(value)
    ghostmod_unified_types_z_assign(value)
  end

  attr_accessor :ghostmod_highlighted
  attr_accessor :ghostmod_exp_animating

  def selected=(value)
    @selected = value
    self.opacity = 255
  end

  def ghostmod_highlighted=(value)
    @ghostmod_highlighted = value
    self.opacity = 255
  end

  alias ghostmod_unified_types_opacity_assign opacity=
  def opacity=(value)
    # Highlighted (active or target) -> 100% (255/255)
    # Background -> 60% (153/255)
    is_high = (@selected && @selected > 0) || @ghostmod_highlighted
    mult = is_high ? 1.0 : 0.5
    tone = is_high ? Tone.new(0, 0, 0, 0) : Tone.new(0, 0, 0, 102)
    
    adjusted_opacity = (value * mult).to_i
    ghostmod_unified_types_opacity_assign(adjusted_opacity)
    self.tone = tone if self.respond_to?(:tone=)
    
    ghostmod_sync_sub_visibility
    
    # Ensure all sub-sprites follow suit
    @sprites.each do |key, s|
      next if !s || s.disposed?
      s.opacity = adjusted_opacity
      s.tone = tone if s.respond_to?(:tone=)
    end
    if @expBar && !@expBar.disposed?
      @expBar.opacity = adjusted_opacity
      @expBar.tone = tone if @expBar.respond_to?(:tone=)
      # GHOST: EXP visibility is now handled in ghostmod_sync_sub_visibility
    end
    if @hpBar && !@hpBar.disposed?
      @hpBar.opacity = adjusted_opacity
      @hpBar.tone = tone if @hpBar.respond_to?(:tone=)
    end
    if @statusIcon && !@statusIcon.disposed?
      @statusIcon.opacity = adjusted_opacity
      @statusIcon.tone = tone if @statusIcon.respond_to?(:tone=)
    end
  end

  def refresh
    self.bitmap.clear
    return if !@battler.pokemon
    
    # GHOST: Call base refreshers first so they update sprites and draw legacy junk.
    # We will then immediately clear their bitmap drawing before adding our own.
    # (NOTE: there is no base refreshStatus - the vanilla PokemonDataBox#refresh
    # draws the status icon inline rather than via a separate method. That call
    # used to be here and crashed with a NameError; the icon itself is now
    # drawn below, alongside our own imagePos entries.)
    refreshHP
    refreshExp

    # GHOST: Clear the entire bottom strip (now expanded to y=50..72) to catch
    # all legacy text, placeholder dashes (---), and baked-in bars.
    self.bitmap.fill_rect(@spriteBaseX, 50, 260, 22, Color.new(0, 0, 0, 0))

    textPos = []
    imagePos = []
    # Logical width for container blitting
    self.bitmap.blt(0,0,@databoxBitmap.bitmap,Rect.new(0,0,@databoxBitmap.width,@databoxBitmap.height))
    
    # GHOST: Draw EXP container using unified parameters
    if !@battler.opposes?(0)
       eb_x, eb_y, eb_w, eb_h = pbGhostEXPParams
       self.bitmap.fill_rect(@spriteBaseX + eb_x, eb_y, eb_w, eb_h, Color.new(0, 0, 0, 160))
    end
    
    pbSetSystemFont(self.bitmap)
    name_str = @battler.name
    name_width = self.bitmap.text_size(name_str).width
    # GHOST: Store name width BEFORE offset for badge positioning logic
    @ghostmod_name_width = name_width
    
    # Standard databox content area is ~116px. 
    # If name is wider, we offset it left.
    name_offset = (name_width > 116) ? (name_width - 116) : 0
    
    name_x = @spriteBaseX + 8 - name_offset
    textPos.push([name_str, name_x, 0, false, NAME_BASE_COLOR, NAME_SHADOW_COLOR])
    
    s_zoom = pbGhostGetDataboxScale
    is_small = (s_zoom < 1.0)
    
    # GHOST: Synchronize with drawtypeDisplay's start offset (4 for small, 6 for large)
    type_start_offset = is_small ? 4 : 6
    # Gap between Type Box and Gender Icon
    type_gender_gap = is_small ? 4 : 3
    
    type_icons_width = 0
    # GHOST: $PokemonSystem has no "typedisplay" property in this engine build
    # (that NameError crashed every wild battle) - the actual base-game toggle
    # for this is the boolean $PokemonSystem.type_icons (004_PokeBattle_
    # SceneElements.rb, exposed in the Sprite Options menu).
    if $PokemonSystem.type_icons
      # Use battler types with fallback consistency
      tp1 = @battler.type1 rescue nil
      tp2 = @battler.type2 rescue nil
      if (tp1.nil? || tp1 == :NONE) && @battler.pokemon
        tp1 = @battler.pokemon.type1
        tp2 = @battler.pokemon.type2
      end
      if tp1
        # GHOST: Adjusted for 26px boxes in Small Mode (26 single, 26+27=53 dual)
        # Large Mode: (20 single, 20+21=41 dual)
        if (tp2.nil? || tp1 == tp2)
          type_icons_width = is_small ? 26 : 20
        else
          type_icons_width = is_small ? 53 : 41
        end
      end
    end
    
    gender_base_x = name_x + name_width + (is_small ? 4 : 3) # Fallback if no types
    if type_icons_width > 0
      gender_base_x = name_x + name_width + type_start_offset + type_icons_width + type_gender_gap
    end
    
    gender_width = 0
    kuraygender1t = "♂"
    kuraygender2t = "♀"
    kuraygender1r = [55, 148, 229]; kuraygender1s = [68, 98, 125]
    kuraygender2r = [229, 55, 203]; kuraygender2s = [137, 73, 127]
    
    # GHOST: displayGenderPizza doesn't exist anywhere in this engine build or
    # mod stack (would crash on every databox refresh) - rescue false so this
    # dead branch never fires instead of erroring, same defensive pattern
    # used elsewhere in this file for uncertain APIs.
    if (@battler.displayGenderPizza rescue false)
      imagePos.push(["Graphics/Pictures/Storage/gender4", gender_base_x, 5])
      gender_width = 20
    else
      case @battler.displayGender
      when 0
        text_size = self.bitmap.text_size(kuraygender1t).width
        textPos.push([kuraygender1t, gender_base_x, 0, false, Color.new(*kuraygender1r), Color.new(*kuraygender1s)])
        gender_width = text_size
      when 1
        text_size = self.bitmap.text_size(kuraygender2t).width
        textPos.push([kuraygender2t, gender_base_x, 0, false, Color.new(*kuraygender2r), Color.new(*kuraygender2s)])
        gender_width = text_size
      when 2
        imagePos.push(["Graphics/Pictures/Storage/gender3", gender_base_x, 14])
        gender_width = 24 # GHOST: Increased from 16 to prevent overlap with Level string
      end
    end
    
    level_x = gender_base_x + gender_width + type_gender_gap
    show_level = !($game_switches[SWITCH_NO_LEVELS_MODE] && $PokemonSystem.showlevel_nolevelmode == 0 rescue false)
    if show_level
      imagePos.push(["Graphics/Pictures/Battle/overlay_lv", level_x, 14])
      pbDrawNumber(@battler.level, self.bitmap, level_x + 22, 14)
    end
    
    pbDrawTextPositions(self.bitmap, textPos)
    
    # GHOST: fakeshiny?/shinyR?/shinyG?/shinyB?/shinyKRS? don't exist anywhere
    # in this engine build (crashed on every non-shiny battler, since
    # `@battler.fakeshiny?` still runs via the `||`), and the call passed 14
    # args to a helper (052_InfiniteFusion/.../GraphicsUtils.rb) that only
    # takes 13. Trimmed to the real signature: imageArray, x, y, shinyBody,
    # shinyHead, debugShiny, radarShiny.
    if @battler.shiny?
      shinyX = (@battler.opposes?(0)) ? -12 : -10
      shinyY = 13
      addShinyStarsToGraphicsArray(imagePos, @spriteBaseX + shinyX, shinyY, @battler.pokemon.bodyShiny?, @battler.pokemon.headShiny?, @battler.pokemon.debugShiny?, nil)
    end
    
    if @battler.mega?
      imagePos.push(["Graphics/Pictures/Battle/icon_mega", @spriteBaseX + 8, 34])
    elsif @battler.primal?
      pX = @battler.opposes?(0) ? 208 : -28
      icon = @battler.isSpecies?(:KYOGRE) ? "Kyogre" : "Groudon"
      imagePos.push(["Graphics/Pictures/Battle/icon_primal_#{icon}", @spriteBaseX + pX, 4])
    end
    
    imagePos.push(["Graphics/Pictures/Battle/icon_own", @spriteBaseX - 8, 42]) if @battler.owned? && @battler.opposes?(0)

    # GHOST: Draw status icon (ported from vanilla PokemonDataBox#refresh,
    # which does this inline rather than via a separate refreshStatus method)
    if @battler.status != :NONE
      s = GameData::Status.get(@battler.status).id_number
      if s == :POISON && @battler.statusCount > 0 # Badly poisoned
        s = GameData::Status::DATA.keys.length / 2
      end
      imagePos.push(["Graphics/Pictures/Battle/icon_statuses", @spriteBaseX + 24, 56,
                     0, (s - 1) * STATUS_ICON_HEIGHT, -1, STATUS_ICON_HEIGHT])
    end

    pbDrawImagePositions(self.bitmap, imagePos)
    drawtypeDisplay if $PokemonSystem.type_icons
    drawEffectiveness(level_x) if @ghostmod_effectiveness
  end

  # Custom refreshExp to ensure stable scaling and progress blitting
  def refreshExp
    return if !@showExp || @battler.opposes?(0)
    return if @battler.level >= GameData::GrowthRate.max_level
    
    # GHOST: No scaling for Type 2, it's already wide
    scaling_factor = 1.0
    
    # GHOST: Use the internal 'exp_fraction' method to correctly support animation
    expFraction = self.exp_fraction
    
    # GHOST: Use unified width from central config
    _, _, eb_w, _ = pbGhostEXPParams
    w = (expFraction * eb_w * scaling_factor).to_i
    
    # Snapping for pixel-perfect look
    w = (w / 2).round * 2
    
    if @expBar && !@expBar.disposed?
      @expBar.src_rect.width = w
    end
  end

  # GHOST: Override to prevent sound cut-out during multi-level gain
  def updateExpAnimation
    return if !@animatingExp
    if !@showExp
      @currentExp = @endExp
      @animatingExp = false
      return
    end
    if @currentExp<@endExp
      @currentExp += @expIncPerFrame
      @currentExp = @endExp if @currentExp>=@endExp
    elsif @currentExp>@endExp
      @currentExp -= @expIncPerFrame
      @currentExp = @endExp if @currentExp<=@endExp
    end
    refreshExp
    return if @currentExp!=@endExp
    if @currentExp>=@rangeExp
      if @expFlash==0
        pbSEStop # Stop gain sound
        @expFlash = Graphics.frame_rate/5
        pbSEPlay("Pkmn exp full") # Play Level up chime
        self.flash(Color.new(64,200,248,192),@expFlash)
        for i in @sprites
          i[1].flash(Color.new(64,200,248,192),@expFlash) if !i[1].disposed?
        end
      else
        @expFlash -= 1
        @animatingExp = false if @expFlash==0
      end
    else
      pbSEStop # Stop gain sound
      @animatingExp = false
    end
  end

  #=============================================================================
  # Boss UI Hooks: Intercept vanilla databox for bosses
  #=============================================================================
  alias ghost_boss_refresh refresh
  def refresh
    if @battler&.respond_to?(:is_boss?) && @battler&.is_boss?
      self.visible = false # Hide standard databox
      if defined?(BossUIManager)
        unless BossUIManager.has_boss_databox?(@battler)
          BossUIManager.create_boss_databox(self.viewport, @battler)
        else
          BossUIManager.update_boss_databox(@battler)
        end
      end
      return
    end
    old_force = $ghost_force_gui
    $ghost_force_gui = 2 if pbGhostUseType2UI?
    ghost_boss_refresh
    $ghost_force_gui = old_force
  end

  alias ghost_boss_update update
  def update(frameCounter = 0)
    if @battler&.respond_to?(:is_boss?) && @battler&.is_boss?
      self.visible = false
      if defined?(BossUIManager)
        boss_db = BossUIManager.get_boss_databox(@battler)
        boss_db&.update
      end
      return
    end
    ghost_boss_update(frameCounter)
    
    # GHOST: Sync visibility of sub-sprites.
    ghostmod_sync_sub_visibility
  end

  if !method_defined?(:ghost_sub_bug_refreshHP)
    alias ghost_sub_bug_refreshHP refreshHP
    def refreshHP
      ghost_sub_bug_refreshHP
      @ghost_actual_drawn_hp = self.hp
    end
  end

  alias ghost_boss_animateHP animateHP
  def animateHP(oldHP, newHP, rangeHP = nil)
    # GHOST FIX: Prevent substitute visual bug where main HP bar "heals" and drains mistakenly.
    if @ghost_actual_drawn_hp && oldHP != @ghost_actual_drawn_hp
      oldHP = @ghost_actual_drawn_hp
    end

    if @battler&.respond_to?(:is_boss?) && @battler&.is_boss?
      if defined?(BossUIManager)
        boss_db = BossUIManager.get_boss_databox(@battler)
        if boss_db
          boss_db.damage if newHP < oldHP
          boss_db.animateHP(oldHP, newHP)
        end
      end
      return
    end
    ghost_boss_animateHP(oldHP, newHP, rangeHP)
  end

  alias ghost_boss_animatingHP animatingHP
  def animatingHP
    if @battler&.respond_to?(:is_boss?) && @battler&.is_boss? && defined?(BossUIManager)
      boss_db = BossUIManager.get_boss_databox(@battler)
      if boss_db
        boss_db.update
        return boss_db.animatingHP
      end
      return false
    end
    ghost_boss_animatingHP
  end

  def pbGetGhostTypeInfo(type)
    case type
    when :NORMAL;   return ["NRM", Color.new(168, 168, 120)]
    when :FIRE;     return ["FIR", Color.new(240, 128, 48)]
    when :WATER;    return ["WTR", Color.new(104, 144, 240)]
    when :GRASS;    return ["GRS", Color.new(120, 200, 80)]
    when :ELECTRIC; return ["ELC", Color.new(248, 208, 48)]
    when :ICE;      return ["ICE", Color.new(152, 216, 216)]
    when :FIGHTING; return ["FGT", Color.new(192, 48, 40)]
    when :POISON;   return ["PSN", Color.new(160, 64, 160)]
    when :GROUND;   return ["GRN", Color.new(224, 192, 104)]
    when :FLYING;   return ["FLY", Color.new(168, 144, 240)]
    when :PSYCHIC;  return ["PSY", Color.new(248, 88, 136)]
    when :BUG;      return ["BUG", Color.new(168, 184, 32)]
    when :ROCK;     return ["RCK", Color.new(184, 160, 56)]
    when :GHOST;    return ["GHS", Color.new(112, 88, 152)]
    when :DRAGON;   return ["DGN", Color.new(112, 56, 248)]
    when :DARK;     return ["DRK", Color.new(112, 88, 72)]
    when :STEEL;    return ["STL", Color.new(184, 184, 208)]
    when :FAIRY;    return ["FRY", Color.new(238, 153, 172)]
    else;           return [type.to_s[0..2].upcase, Color.new(104, 160, 144)]
    end
  end

  def pbGetGhostAbbr(type)
    case type
    when :NORMAL;   return "NO"
    when :FIRE;     return "FI"
    when :WATER;    return "WA"
    when :GRASS;    return "GR"
    when :ELECTRIC; return "EL"
    when :ICE;      return "IC"
    when :FIGHTING; return "FG"
    when :POISON;   return "PO"
    when :GROUND;   return "GD"
    when :FLYING;   return "FL"
    when :PSYCHIC;  return "PS"
    when :BUG;      return "BU"
    when :ROCK;     return "RO"
    when :GHOST;    return "GH"
    when :DRAGON;   return "DR"
    when :DARK;     return "DA"
    when :STEEL;    return "ST"
    when :FAIRY;    return "FA"
    else;           return type.to_s[0..1].upcase
    end
  end

  def pbDrawTypeBadge(bitmap, x, y, type)
    info = pbGetGhostTypeInfo(type)
    abbr = pbGetGhostAbbr(type)
    base_color = info[1]
    
    # Scale-aware dimensions
    s_zoom = pbGhostGetDataboxScale
    is_small = (s_zoom < 1.0)
    
    # GHOST: Large mode (1.0x) box is reduced to 20px. Small Mode is 2px wider (26px).
    width = is_small ? 26 : 20
    height = is_small ? 24 : 20
    
    # Draw background (GHOST: Removed black border to prevent erroneous outlines)
    bitmap.fill_rect(x, y, width, height, base_color)
    
    # Save font settings
    old_size = bitmap.font.size
    old_bold = bitmap.font.bold
    old_color = bitmap.font.color.clone
    old_aa = bitmap.font.antialiasing rescue true if bitmap.font.respond_to?(:antialiasing)
    
    # Font settings optimized for scale
    bitmap.font.name = "Power Green" if MessageConfig.respond_to?(:pbGetFontName)
    # GHOST: Use 22px for Large Mode (fix distortion) and keep 22px for Small Mode (user approved)
    bitmap.font.size = 22
    bitmap.font.bold = true
    bitmap.font.color = Color.new(255, 255, 255)
    # GHOST: Soft-guard the antialiasing property as it is not universal in RMXP
    if bitmap.font.respond_to?(:antialiasing=)
      bitmap.font.antialiasing = false if !is_small 
    end
    
    # USER: Shift text down by 3px in Large mode (from -1 to 2).
    y_off = is_small ? 2 : 2

    # GHOST: Use explicit pixel-perfect offsets instead of generic centering.
    # We use a wider text box to prevent squishing and a consistent 1px x-offset for all modes.
    # This ensures "NO" is perfectly centered and nudged right by 1px consistently.
    x_off = 1
    bitmap.draw_text(x + x_off, y + y_off, width, height + 6, abbr, 1)
    
    # Restore font settings
    bitmap.font.size = old_size
    bitmap.font.bold = old_bold
    bitmap.font.color = old_color
    if bitmap.font.respond_to?(:antialiasing=)
      bitmap.font.antialiasing = old_aa
    end
  end

  # Redefine to use main bitmap for better reliability
  def refreshtypeDisplay
    drawtypeDisplay
  end

  def drawtypeDisplay
    return if !$PokemonSystem.type_icons
    return if !self.bitmap || self.bitmap.disposed?
    
    # Use battler types with fallback consistency
    type1 = @battler.type1 rescue nil
    type2 = @battler.type2 rescue nil
    if (type1.nil? || type1 == :NONE) && @battler.pokemon
      type1 = @battler.pokemon.type1
      type2 = @battler.pokemon.type2
    end
    return if !type1
	  
    # Logical target position (synchronized with 'refresh' logic)
    name_width = @ghostmod_name_width || 0
    if name_width == 0 && @battler && @battler.name
      pbSetSystemFont(self.bitmap) if self.bitmap && !self.bitmap.disposed?
      name_width = self.bitmap.text_size(@battler.name).width rescue 0
    end
    name_offset = (name_width > 116) ? (name_width - 116) : 0
    
    s_zoom = pbGhostGetDataboxScale
    is_small = (s_zoom < 1.0)
    
    # Shift right based on name_x (which is @spriteBaseX + 8 - name_offset)
    type_x = @spriteBaseX + 8 - name_offset + name_width + (is_small ? 4 : 6)
    
    # Limit type_x to prevent overflow (adjusted for 26px box in small mode)
    type_x = [type_x, 320 - (type2.nil? || type1 == type2 ? (is_small ? 28 : 26) : (is_small ? 54 : 50))].min
    
    # Centering on the databox
    type_y = is_small ? 9 : 12
	  
    if type2.nil? || type1 == type2
      pbDrawTypeBadge(self.bitmap, type_x, type_y, type1)
    else
      # HORIZONTAL layout
      pbDrawTypeBadge(self.bitmap, type_x, type_y, type1)
      # GHOST: Expanded gap for wider small-mode boxes to preserve 1px spacing (26+1=27)
      pbDrawTypeBadge(self.bitmap, type_x + (is_small ? 27 : 21), type_y, type2)
    end
    
    # Always hide default types when the mod is active
    @sprites["typeDisplay"].visible = false if @sprites["typeDisplay"]
  end
end

#-----------------------------------------------------------------------------
# Safely handle PBAnimationPlayerX to prevent coordinate drift
#-----------------------------------------------------------------------------
class PokeBattle_Scene
  def ghostmod_visual_sprite_xy(sprite)
    return [0, 0] if !sprite
    logical_x = sprite.instance_variable_get(:@spriteX)
    logical_y = sprite.instance_variable_get(:@spriteY)
    logical_x = sprite.x if logical_x.nil?
    logical_y = sprite.y if logical_y.nil?
    current_ox = sprite.respond_to?(:ghostmod_current_offset_x) ? sprite.ghostmod_current_offset_x.to_f : 0.0
    current_oy = sprite.respond_to?(:ghostmod_current_offset_y) ? sprite.ghostmod_current_offset_y.to_f : 0.0
    extra_x = sprite.instance_variable_get(:@spriteXExtra) || 0
    extra_y = sprite.instance_variable_get(:@spriteYExtra) || 0
    return [logical_x.to_f + current_ox + extra_x.to_f, logical_y.to_f + current_oy + extra_y.to_f]
  rescue
    return [sprite.x.to_f, sprite.y.to_f]
  end

  def ghostmod_sprite_center_at(sprite, x, y)
    return [x.to_f, y.to_f] if !sprite || sprite.disposed?
    return [x.to_f, y.to_f] if !sprite.bitmap || sprite.bitmap.disposed?
    center_x = sprite.src_rect.width / 2.0
    center_y = sprite.src_rect.height / 2.0
    offset_x = (center_x - sprite.ox.to_f) * sprite.zoom_x.to_f
    offset_y = (center_y - sprite.oy.to_f) * sprite.zoom_y.to_f
    return [x.to_f + offset_x, y.to_f + offset_y]
  rescue
    return [x.to_f, y.to_f]
  end

  def pbWaitSlide(battlers)
    return if (@battle.class.to_s == "PokeBattle_SafariZone") rescue false
    battlers = [battlers] if !battlers.is_a?(Array)
    sprites_to_check = []
    battlers.each { |b| sprites_to_check << @sprites["pokemon_#{b.index}"] if b }
    loop do
      all_ready = true
      sprites_to_check.each do |s|
        if s && s.respond_to?(:ghostmod_slide_done?) && !s.ghostmod_slide_done?
          all_ready = false
          break
        end
      end
      break if all_ready
      pbUpdate
    end
  end

  alias ghostmod_highlight_pbCommonAnimation pbCommonAnimation
  def pbCommonAnimation(animName,user=nil,target=nil)
    return ghostmod_highlight_pbCommonAnimation(animName, user, target) if (@battle.class.to_s == "PokeBattle_SafariZone") rescue false
    mp_ebdx_enabled_active = ($PokemonSystem.mp_ebdx_enabled && $PokemonSystem.mp_ebdx_enabled == 1) rescue false
    if !mp_ebdx_enabled_active && user && user.index
      # Set highlight for status effect animations
      if target && target.is_a?(Array)
          pbRefreshBattlerTones(user.index, target[0].index)
          pbWaitSlide([user, target[0]])
      elsif target
          pbRefreshBattlerTones(user.index, target.index)
          pbWaitSlide([user, target])
      else
          pbRefreshBattlerTones(user.index)
          pbWaitSlide(user)
      end
    end
    
    ghostmod_highlight_pbCommonAnimation(animName, user, target)
  end

  alias ghostmod_highlight_pbAnimationCore pbAnimationCore
  def pbAnimationCore(animation,user,target,oppMove=false)
    return ghostmod_highlight_pbAnimationCore(animation, user, target, oppMove) if (@battle.class.to_s == "PokeBattle_SafariZone") rescue false
    return if !animation
    @briefMessage = false

    userSprite   = (user) ? @sprites["pokemon_#{user.index}"] : nil
    targetSprite = (target) ? @sprites["pokemon_#{target.index}"] : nil

    # Lock sprites to current visual position for the start of the animation
    userSprite.ghostmod_in_animation = true if userSprite
    targetSprite.ghostmod_in_animation = true if targetSprite

    userX = 0; userY = 0
    if userSprite
      userXY = ghostmod_visual_sprite_xy(userSprite)
      userX = userXY[0]
      userY = userXY[1]
    end
    
    targetX = userX; targetY = userY
    if targetSprite
      targetXY = ghostmod_visual_sprite_xy(targetSprite)
      targetX = targetXY[0]
      targetY = targetXY[1]
    end
    
    oldUserX = (userSprite) ? userSprite.instance_variable_get(:@spriteX) : 0
    oldUserY = (userSprite) ? userSprite.instance_variable_get(:@spriteY) : 0
    oldTargetX = (targetSprite) ? targetSprite.instance_variable_get(:@spriteX) : oldUserX
    oldTargetY = (targetSprite) ? targetSprite.instance_variable_get(:@spriteY) : oldUserY
    lock_indices = @ghostmod_anim_lock_indices || []
    lock_user_sprite = (user && lock_indices.include?(user.index))
    lock_target_sprite = (target && lock_indices.include?(target.index))

    # Standard player initialization
    animPlayer = PBAnimationPlayerX.new(animation,user,target,self,oppMove)
    
    # Ensure animation origin tracks current visual (slide-aware) position.
    # PBAnimationPlayerX captures @userOrig/@targetOrig from sprite centers at init;
    # in doubles/triples, ClassicPlus can visually slide battlers, so we override
    # origins to match the current on-screen location to prevent "snap to slot".
    if userSprite
      ux, uy = ghostmod_visual_sprite_xy(userSprite)
      animPlayer.instance_variable_set(:@userOrig, ghostmod_sprite_center_at(userSprite, ux, uy))
    end
    if targetSprite
      tx, ty = ghostmod_visual_sprite_xy(targetSprite)
      animPlayer.instance_variable_set(:@targetOrig, ghostmod_sprite_center_at(targetSprite, tx, ty))
    end

    # NOTE:
    # PBAnimationPlayerX initializes @userOrig/@targetOrig from current rendered
    # sprite positions. Adding ghost offsets again here can double-compensate and
    # produce first-frame jitter in focus-3 (line transform) animations.
    
    u_zoom = (userSprite) ? userSprite.zoom_y : 1.0
    t_zoom = (targetSprite) ? targetSprite.zoom_y : u_zoom
    userHeight = (userSprite && userSprite.bitmap && !userSprite.bitmap.disposed?) ? userSprite.bitmap.height : 128
    if targetSprite
      targetHeight = (targetSprite.bitmap && !targetSprite.bitmap.disposed?) ? targetSprite.bitmap.height : 128
    else
      targetHeight = userHeight
    end
    userHeight = (userHeight * u_zoom).to_i
    targetHeight = (targetHeight * t_zoom).to_i

    animPlayer.setLineTransform(
       PokeBattle_SceneConstants::FOCUSUSER_X,PokeBattle_SceneConstants::FOCUSUSER_Y,
       PokeBattle_SceneConstants::FOCUSTARGET_X,PokeBattle_SceneConstants::FOCUSTARGET_Y,
       userX,userY-userHeight/2,
       targetX,targetY-targetHeight/2)
       
    animPlayer.start
    loop do
      animPlayer.update
      if lock_user_sprite && userSprite
        userSprite.x = userX
        userSprite.y = userY
        userSprite.pbSetOrigin
      end
      if lock_target_sprite && targetSprite
        targetSprite.x = targetX
        targetSprite.y = targetY
        targetSprite.pbSetOrigin
      end
      pbUpdate
      break if animPlayer.animDone?
    end
    animPlayer.dispose
    
    if userSprite
      userSprite.ghostmod_in_animation = false
      userSprite.x = oldUserX
      userSprite.y = oldUserY
      userSprite.pbSetOrigin
      userSprite.z = old_user_z if defined?(old_user_z)
    end
    if targetSprite
      targetSprite.ghostmod_in_animation = false
      targetSprite.x = oldTargetX
      targetSprite.y = oldTargetY
      targetSprite.pbSetOrigin
      targetSprite.z = old_target_z if defined?(old_target_z)
    end
  end

  alias ghostmod_highlight_pbAnimation pbAnimation
  def pbAnimation(moveID,user,targets,hitNum=0)
    return ghostmod_highlight_pbAnimation(moveID, user, targets, hitNum) if (@battle.class.to_s == "PokeBattle_SafariZone") rescue false
    mp_ebdx_enabled_active = ($PokemonSystem.mp_ebdx_enabled && $PokemonSystem.mp_ebdx_enabled == 1) rescue false
    swapped = false
    
    if !mp_ebdx_enabled_active && user && user.index
      targets_array = (targets && targets.is_a?(Array)) ? targets : [targets]
      targets_array.compact!
      is_single_target = targets_array.length == 1
      target = targets_array[0]
      
      # Keep animation prep aligned with the same anchor battler used by base animation.
      if target && user != target
        pbRefreshBattlerTones(user.index, target.index)
        swapped = true if !target.opposes?(0)
      else
        pbRefreshBattlerTones(user.index)
      end
      if targets_array.length >= 1
        @ghostmod_anim_lock_indices = []
        @ghostmod_anim_lock_indices << user.index if user
        targets_array.each { |t| @ghostmod_anim_lock_indices << t.index if t }
        @ghostmod_anim_lock_indices.uniq!
      else
        @ghostmod_anim_lock_indices = nil
      end
    end
    
    if !mp_ebdx_enabled_active
      sprites_to_check = []
      sprites_to_check << @sprites["pokemon_#{user.index}"] if user
      if targets
        targets_array = targets.is_a?(Array) ? targets : [targets]
        targets_array.each { |t| sprites_to_check << @sprites["pokemon_#{t.index}"] if t }
      end
      
      pbWaitSlide(sprites_to_check.compact.map{|sl| @battle.battlers[sl.index] if sl.respond_to?(:index)}.compact)
    end
    
    begin
      ghostmod_highlight_pbAnimation(moveID, user, targets, hitNum)
    ensure
      @ghostmod_anim_lock_indices = nil
    end
    
    if !mp_ebdx_enabled_active && user && user.index
      if swapped
        frames = (Graphics.frame_rate * 0.4).to_i
        frames.times do
          Graphics.update
          pbUpdate
        end
      end
      pbRefreshBattlerTones(user.index)
    end
  end

  alias ghostmod_classicplus_pbEXPBar pbEXPBar
  def pbEXPBar(battler,startExp,endExp,tempExp1,tempExp2)
    return if !battler
    # GHOST: Lock stats to prevent UI refreshes from calling calc_stats prematurely
    $gb_suppress_calc_stats = true
    begin
      # Safety: Only try to handle databox if it exists in the scene
      db = @sprites["dataBox_#{battler.index}"] rescue nil
      if db
        # GHOST: Crucial fix - force @showExp to true so base updateExpAnimation doesn't short-circuit
        db.instance_variable_set(:@showExp, true) if !battler.opposes?(0)
        if db.respond_to?(:ghostmod_exp_animating=)
          db.ghostmod_exp_animating = true
          db.ghostmod_sync_sub_visibility
        end
      end
      ret = ghostmod_classicplus_pbEXPBar(battler,startExp,endExp,tempExp1,tempExp2)
      if db && db.respond_to?(:ghostmod_exp_animating=)
        db.ghostmod_exp_animating = false
        db.refresh # Final refresh to clear the bar if necessary
        db.ghostmod_sync_sub_visibility
      end
    ensure
      $gb_suppress_calc_stats = false
    end
    return ret
  end
end

#===============================================================================
# Premium Boss UI Enhancements (EBDX-inspired)
#===============================================================================
if defined?(BossDataBoxSprite)
  class BossDataBoxSprite
    alias ghost_premium_initialize initialize
    def initialize(viewport, battler)
      ghost_premium_initialize(viewport, battler)
      @glimmer_x = -100
      @pulse_alpha = 255
      @pulse_dir = -1
      @shake_timer = 0
      
      # Enhance the name banner with a gradient and border, and REDUCE HEIGHT
      if @sprites[:name_bg]
        @sprites[:name_bg].bitmap.clear
        # New height: 32 (old 50)
        @sprites[:name_bg].bitmap = Bitmap.new(Graphics.width, 32)
        @sprites[:name].bitmap = Bitmap.new(Graphics.width, 32)
        
        # Deep gradient background
        @sprites[:name_bg].bitmap.gradient_fill_rect(0, 0, Graphics.width, 32, Color.new(20, 20, 30, 200), Color.new(60, 20, 20, 200))
        # Top/Bottom golden borders
        @sprites[:name_bg].bitmap.fill_rect(0, 0, Graphics.width, 2, Color.new(255, 215, 0, 150))
        @sprites[:name_bg].bitmap.fill_rect(0, 30, Graphics.width, 2, Color.new(255, 215, 0, 150))
      end
      
      # Move HP bar and other elements UP
      @sprites[:hpbg].y = 34
      @sprites[:hpbar].y = 38
      @sprites[:phase].y = 61
      @sprites[:shields].y = 61
      @sprites[:shield_label].y = 61
      @sprites[:status].y = 61
      
      # Create glimmer sprite overlay (adjust y)
      @sprites[:hp_glimmer] = Sprite.new(@viewport)
      @sprites[:hp_glimmer].bitmap = Bitmap.new(100, 16)
      @sprites[:hp_glimmer].bitmap.gradient_fill_rect(0, 0, 100, 16, Color.new(255, 255, 255, 0), Color.new(255, 255, 255, 120), true)
      @sprites[:hp_glimmer].x = @sprites[:hpbar].x
      @sprites[:hp_glimmer].y = @sprites[:hpbar].y
      @sprites[:hp_glimmer].z = @sprites[:hpbar].z + 2
      @sprites[:hp_glimmer].visible = true
      @sprites[:hp_glimmer].src_rect.set(0, 0, 0, 16) # Initially hidden

      # GHOST: Single HP bar breaks overlay
      @sprites[:hp_breaks] = Sprite.new(@viewport)
      @sprites[:hp_breaks].bitmap = Bitmap.new(@hp_bar_max_width, 16)
      @sprites[:hp_breaks].x = @sprites[:hpbar].x
      @sprites[:hp_breaks].y = @sprites[:hpbar].y
      @sprites[:hp_breaks].z = @sprites[:hpbar].z + 1
      draw_hp_breaks

      # GHOST: Initialize boss types
      @type_glow_timer = 0
      draw_boss_types
    end

    alias ghost_premium_update update
    def update
      # 0. Opacity and Tone Logic (Sync with regular databoxes)
      active_op   = pbGhostGetActiveOpacity
      inactive_op = pbGhostGetInactiveOpacity
      
      # Determine if boss is currently "active"
      # We check if it's currently being targeted or if it's the battler at the head of the command menu
      # (Note: Boss databoxes are usually for enemies, so being targeted is the main active state)
      is_high = @selected && @selected > 0
      
      mult = is_high ? (active_op / 100.0) : (inactive_op / 100.0)
      tone = is_high ? Tone.new(0, 0, 0, 0) : Tone.new(0, 0, 0, 102)
      
      # Base 255 opacity scaled by mod settings
      target_opacity = (255 * mult).to_i
      
      ghost_premium_update
      return if disposed?
      
      # 1. HP Bar Glimmer Animation
      @glimmer_x += 4
      # Adjust glimmer width based on HP bar fill
      bar_width = @hp_bar_max_width * @sprites[:hpbar].zoom_x
      if @glimmer_x > bar_width + 100
        @glimmer_x = -150
      end
      
      if @glimmer_x > 0 && @glimmer_x < bar_width
        visible_glimmer = [100, bar_width - @glimmer_x].min
        @sprites[:hp_glimmer].x = @sprites[:hpbar].x + @glimmer_x
        @sprites[:hp_glimmer].src_rect.set(0, 0, visible_glimmer.to_i, 16)
        @sprites[:hp_glimmer].visible = true
      else
        @sprites[:hp_glimmer].visible = false
      end

      # 2. Pulsing Low HP (Current phase < 25%)
      hp_ratio = @sprites[:hpbar].zoom_x
      if hp_ratio < 0.25
        @pulse_alpha += 8 * @pulse_dir
        if @pulse_alpha <= 100 || @pulse_alpha >= 255
          @pulse_dir *= -1
        end
        @sprites[:hpbar].opacity = (@pulse_alpha * mult).to_i
      else
        @sprites[:hpbar].opacity = target_opacity
      end
      @sprites[:hpbar].tone = tone if @sprites[:hpbar].respond_to?(:tone=)

      # 3. Shield/UI Vibration on Damage
      if @shake_timer > 0
        @shake_timer -= 1
        offset_x = (rand(3) - 1) * 2
        offset_y = (rand(3) - 1) * 2
        @sprites[:shields].x = 30 + offset_x
        @sprites[:shields].y = 61 + offset_y
        @sprites[:hpbg].x = 30 + offset_x
        @sprites[:hpbg].y = 34 + offset_y
        @sprites[:hpbar].x = 34 + offset_x
        @sprites[:hpbar].y = 38 + offset_y
        @sprites[:hp_breaks].x = @sprites[:hpbar].x if @sprites[:hp_breaks]
        @sprites[:hp_breaks].y = @sprites[:hpbar].y if @sprites[:hp_breaks]
        @sprites[:hp_glimmer].x += offset_x if @sprites[:hp_glimmer].visible
        @sprites[:hp_glimmer].y = @sprites[:hpbar].y
      else
        @sprites[:shields].x = 30
        @sprites[:shields].y = 61
        @sprites[:hpbg].x = 30
        @sprites[:hpbg].y = 34
        @sprites[:hpbar].x = 34
        @sprites[:hpbar].y = 38
        @sprites[:hp_breaks].x = @sprites[:hpbar].x if @sprites[:hp_breaks]
        @sprites[:hp_breaks].y = @sprites[:hpbar].y if @sprites[:hp_breaks]
        @sprites[:hp_glimmer].y = @sprites[:hpbar].y
      end

      # 4. Boss Type Ominous Animation
      @type_glow_timer += 0.1
      pulse = (Math.sin(@type_glow_timer) * 40).to_i
      types_to_animate = [:type_0, :type_1]
      types_to_animate.each_with_index do |key, i|
        s = @sprites[key]
        next if !s || s.disposed?
        # Pulsing opacity for "ominous" feel
        s.opacity = 215 + pulse
        # Slight vertical hover
        hover = (Math.cos(@type_glow_timer + (i * Math::PI)) * 2).to_i
        s.y = 2 + hover
        # Glow tone
        g_pulse = (Math.sin(@type_glow_timer * 2) * 20).to_i
        s.tone = Tone.new(20 + g_pulse + tone.red, tone.green, tone.blue, tone.gray)
      end

      # 5. Apply Global Opacity/Tone to all remaining sprites
      @sprites.each do |key, s|
        next if !s || s.disposed?
        next if key == :hpbar # Already handled by pulse logic
        if [:type_0, :type_1].include?(key)
           # Pulsing types handled in section 4, but let's ensure tone is mixed above
           next
        end
        s.opacity = target_opacity
        s.tone    = tone if s.respond_to?(:tone=)
      end
    end

    alias ghost_premium_damage damage
    def damage
      ghost_premium_damage
      @shake_timer = 20 # Shake for ~20 frames
    end

    # Redefine draw_boss_name for the smaller 32px height
    def draw_boss_name
      return unless @pokemon&.is_boss?
      bitmap = @sprites[:name].bitmap
      bitmap.clear
  
      # Get family and subfamily names
      family_name = nil
      subfamily_name = nil
      family_font = nil
  
      if defined?(PokemonFamilyConfig) && @pokemon.respond_to?(:family) && @pokemon.family
        family_data = PokemonFamilyConfig::FAMILIES[@pokemon.family]
        if family_data
          family_name = family_data[:name]
          family_font = family_data[:font_name]
        end
  
        if @pokemon.respond_to?(:subfamily) && @pokemon.subfamily
          global_subfamily = @pokemon.family * 4 + @pokemon.subfamily
          subfamily_data = PokemonFamilyConfig::SUBFAMILIES[global_subfamily]
          subfamily_name = subfamily_data[:name] if subfamily_data
        end
      end
  
      species_name = @pokemon.speciesName rescue @pokemon.species.to_s
      text_color = Color.new(255, 255, 255)
      outline_color = Color.new(40, 40, 40)
      standard_font = "Pokemon DS"
  
      # Start with base font size, scale down if too wide
      base_size = 24 # Reduced from 28
      bitmap.font.bold = true
  
      # Build the parts without slashes
      parts = []
      parts << { text: family_name, font: standard_font } if family_name
      parts << { text: subfamily_name, font: standard_font } if subfamily_name
      parts << { text: species_name, font: family_font || standard_font }
  
      # If no family, just show "BOSS Species"
      if parts.length == 1
        parts.unshift({ text: "BOSS", font: standard_font })
      end
  
      # Calculate total width and scale if needed
      font_size = base_size
      spacing = 15 # Reduced from 20
      # GHOST: Limit width to fit between the two type badges (10px + 64px + 10px margin each side)
      max_width = Graphics.width - 164
  
      loop do
        bitmap.font.size = font_size
        total_width = 0
        parts.each_with_index do |part, i|
          bitmap.font.name = part[:font] rescue standard_font
          total_width += bitmap.text_size(part[:text]).width
          total_width += spacing if i < parts.length - 1
        end
        break if total_width <= max_width || font_size <= 14
        font_size -= 2
      end
  
      # Calculate starting position for centered text
      bitmap.font.size = font_size
      total_width = 0
      parts.each_with_index do |part, i|
        bitmap.font.name = part[:font] rescue standard_font
        total_width += bitmap.text_size(part[:text]).width
        total_width += spacing if i < parts.length - 1
      end
      start_x = (Graphics.width - total_width) / 2
      y_pos = (32 - font_size) / 2 # Centered for 32px height
  
      # Draw each part
      current_x = start_x
      parts.each_with_index do |part, i|
        bitmap.font.name = part[:font] rescue standard_font
        bitmap.font.size = font_size
        part_width = bitmap.text_size(part[:text]).width
        pbDrawOutlineText(bitmap, current_x, y_pos, part_width + 10, font_size + 4, part[:text], text_color, outline_color, 0)
        current_x += part_width + spacing
      end
      bitmap.font.name = standard_font
    end

    # GHOST: Draw flashy, ominous types for the boss
    def draw_boss_types
      return unless @pokemon&.is_boss?
      types = [@pokemon.type1, @pokemon.type2].compact.uniq
      types.reject! { |t| t == :NONE }
      
      types.each_with_index do |type, i|
        key = "type_#{i}".to_sym
        @sprites[key].dispose if @sprites[key]
        @sprites[key] = Sprite.new(@viewport)
        @sprites[key].bitmap = Bitmap.new(64, 28) # Reduced height from 32
        @sprites[key].z = @sprites[:name].z + 2
        
        # Position: Flanking the name banner
        # Banner is at 0, 32 height.
        if i == 0
          @sprites[key].x = 10
        else
          @sprites[key].x = Graphics.width - 74
        end
        @sprites[key].y = 2
        
        draw_ominous_type_badge(@sprites[key].bitmap, type)
      end
    end

    def draw_ominous_type_badge(bitmap, type)
      # Get type color mapping
      type_color = Color.new(160, 160, 160) # Default
      case type
      when :NORMAL;   type_color = Color.new(168, 168, 120)
      when :FIRE;     type_color = Color.new(240, 128, 48)
      when :WATER;    type_color = Color.new(104, 144, 240)
      when :GRASS;    type_color = Color.new(120, 200, 80)
      when :ELECTRIC; type_color = Color.new(248, 208, 48)
      when :ICE;      type_color = Color.new(152, 216, 216)
      when :FIGHTING; type_color = Color.new(192, 48, 40)
      when :POISON;   type_color = Color.new(160, 64, 160)
      when :GROUND;   type_color = Color.new(224, 192, 104)
      when :FLYING;   type_color = Color.new(168, 144, 240)
      when :PSYCHIC;  type_color = Color.new(248, 88, 136)
      when :BUG;      type_color = Color.new(168, 184, 32)
      when :ROCK;     type_color = Color.new(184, 160, 56)
      when :GHOST;    type_color = Color.new(112, 88, 152)
      when :DRAGON;   type_color = Color.new(112, 56, 248)
      when :DARK;     type_color = Color.new(112, 88, 72)
      when :STEEL;    type_color = Color.new(184, 184, 208)
      when :FAIRY;    type_color = Color.new(238, 153, 172)
      end

      # 1. Outer Ominous Glow - Adjusted for 28px height
      for j in 0..5
        alpha = 110 - (j * 15)
        bitmap.fill_rect(j, j, 64-(j*2), 28-(j*2), Color.new(type_color.red, type_color.green, type_color.blue, alpha))
      end
      
      # 2. Hard Border
      bitmap.fill_rect(5, 5, 54, 18, Color.new(0, 0, 0, 200))
      bitmap.fill_rect(6, 6, 52, 16, type_color)
      bitmap.fill_rect(7, 7, 50, 14, Color.new(20, 20, 20, 180)) # Dark center for text contrast
      
      # 3. Type Text
      bitmap.font.name = "Power Green"
      bitmap.font.size = 22
      bitmap.font.bold = true
      
      type_str = type.to_s.upcase
      # Draw ominous shadow/glow for text
      bitmap.font.color = Color.new(0, 0, 0)
      bitmap.draw_text(7, 4, 52, 20, type_str, 1) # Shadow - adjusted y
      
      bitmap.font.color = Color.new(255, 255, 255)
      bitmap.draw_text(6, 3, 52, 20, type_str, 1) # Main text - adjusted y
    end

    #=============================================================================
    # Single HP Bar Overrides
    #=============================================================================
    def draw_hp_breaks
      return unless @sprites[:hp_breaks]
      bitmap = @sprites[:hp_breaks].bitmap
      bitmap.clear
      num_phases = BossConfig::HP_PHASES rescue 4
      return if num_phases <= 1
      
      pixels_per_phase = @hp_bar_max_width.to_f / num_phases
      
      (1...num_phases).each do |i|
        x_pos = (i * pixels_per_phase).to_i
        # Draw black break (2 pixels wide)
        bitmap.fill_rect(x_pos - 1, 0, 2, 16, Color.new(20, 20, 20))
      end
    end

    def draw_hp_bar
      # Use @currenthp if animating, otherwise use battler.hp
      current = @animatingHP ? @currenthp : @battler.hp
      total = @battler.totalhp
      
      hp_ratio = total > 0 ? current.to_f / total.to_f : 0
      hp_ratio = 0 if hp_ratio < 0
      hp_ratio = 1 if hp_ratio > 1

      # Use zoom_x for fast width changes
      @sprites[:hpbar].zoom_x = hp_ratio

      # Determine color zone based on overall HP ratio
      new_zone = hp_ratio > 0.5 ? 0 : (hp_ratio > 0.25 ? 1 : 2)
      @hp_color_zone ||= -1

      if new_zone != @hp_color_zone
        @hp_color_zone = new_zone
        color = case new_zone
          when 0 then Color.new(0, 200, 50)   # Green
          when 1 then Color.new(255, 200, 0)  # Yellow
          else Color.new(220, 50, 50)         # Red
        end
        bitmap = @sprites[:hpbar].bitmap
        bitmap.clear
        bitmap.fill_rect(0, 0, @hp_bar_max_width, 16, color)
        # Add darker edge for 3D effect
        darker = Color.new([color.red - 40, 0].max, [color.green - 40, 0].max, [color.blue - 40, 0].max)
        bitmap.fill_rect(0, 13, @hp_bar_max_width, 3, darker)
      end
    end

    def draw_phase_counter
      # Hides the X3, X2 phase text to accommodate the single HP bar design
      @sprites[:phase].bitmap.clear if @sprites[:phase] && @sprites[:phase].bitmap
    end
  end
end

#===============================================================================
# Effectiveness Display Hooks
#===============================================================================
class PokeBattle_Battle
  alias ghost_effectiveness_pbChooseTarget pbChooseTarget
  def pbChooseTarget(battler, move)
    @scene.instance_variable_set(:@ghostmod_effectiveness_move, move)
    @scene.instance_variable_set(:@ghostmod_active_battler_idx, battler.index)
    @scene.instance_variable_set(:@ghostmod_in_targeting, true)
    ret = ghost_effectiveness_pbChooseTarget(battler, move)
    @scene.instance_variable_set(:@ghostmod_effectiveness_move, nil)
    @scene.instance_variable_set(:@ghostmod_active_battler_idx, -1)
    @scene.instance_variable_set(:@ghostmod_in_targeting, false)
    # Clear effectiveness after targeting
    @scene.sprites.each { |ki, si| si.pbHideEffectiveness if si.is_a?(PokemonDataBox) }
    return ret
  end
end

class PokeBattle_Scene
  alias ghost_effectiveness_pbSelectBattler pbSelectBattler
  def pbSelectBattler(idxBattler, selectMode = 1)
    return ghost_effectiveness_pbSelectBattler(idxBattler, selectMode) if (@battle.class.to_s == "PokeBattle_SafariZone") rescue false
    ghost_effectiveness_pbSelectBattler(idxBattler, selectMode)
    if @ghostmod_effectiveness_move && pbGhostGetEffectivenessMode != 0
      active_idx = @ghostmod_active_battler_idx || -1
      if idxBattler.is_a?(Array)
        pbRefreshBattlerTones(active_idx)
      else
        pbRefreshBattlerTones(active_idx, idxBattler)
      end
    end
  end

  alias ghost_effectiveness_pbInitSprites pbInitSprites
  def pbInitSprites
    return ghost_effectiveness_pbInitSprites if (@battle.class.to_s == "PokeBattle_SafariZone") rescue false
    ghost_effectiveness_pbInitSprites
    if @sprites["fightWindow"] && @sprites["fightWindow"].respond_to?(:scene=)
      @sprites["fightWindow"].scene = self
    end
  end

  # GHOST: Continuously sync Substitute visual state for Vanilla fallback
  alias ghostmod_substitute_pbFrameUpdate pbFrameUpdate
  def pbFrameUpdate(cw = nil)
    return ghostmod_substitute_pbFrameUpdate(cw) if (@battle.class.to_s == "PokeBattle_SafariZone") rescue false
    ghostmod_substitute_pbFrameUpdate(cw)
    if @battle && @battle.battlers
      @battle.battlers.each_with_index do |b, i|
        next if !b
        sprite = @sprites["pokemon_#{i}"]
        next if !sprite || !sprite.respond_to?(:setSubstitute)
        
        has_sub = (b.effects[PBEffects::Substitute] > 0)
        
        if has_sub && !sprite.isSub
          sprite.setSubstitute(b.pokemon)
        elsif !has_sub && sprite.isSub
          sprite.removeSubstitute
        end
      end
    end
  end
end

class FightMenuDisplay
  attr_accessor :scene
  alias ghost_effectiveness_refreshMoveData refreshMoveData
  def refreshMoveData(move)
    ghost_effectiveness_refreshMoveData(move)
    if @scene && @scene.is_a?(PokeBattle_Scene)
      @scene.instance_variable_set(:@ghostmod_effectiveness_move, move)
      @scene.instance_variable_set(:@ghostmod_active_battler_idx, @battler.index) if @battler
      # Trigger a tone refresh to show effectiveness on the default target
      @scene.pbRefreshBattlerTones(@battler.index) if @battler
    end
  end
end
#===============================================================================
# GhostBattle_ClassicPlus: Substitute HP Display
#===============================================================================
class SubstituteDataBox < PokemonDataBox
  def initialize(battler, sideSize, viewport)
    @is_substitute_box = true
    @sub_max_hp = 0
    super(battler, sideSize, viewport)
    @showExp = false # Always hide EXP bar for substitute
    @expBar.visible = false if @expBar
    @showHP = true if !@battler.opposes?(0) # GHOST FIX: Always show HP text for our substitute
  end

  def refresh
    return if !@battler || !@battler.pokemon
    self.bitmap.clear
    # Draw background panel
    self.bitmap.blt(0, 0, @databoxBitmap.bitmap, Rect.new(0, 0, @databoxBitmap.width, @databoxBitmap.height))
    
    eb_x, eb_y, eb_w, eb_h = [31, 60, 128, 6]
    if respond_to?(:pbGhostEXPParams)
      eb_x, eb_y, eb_w, eb_h = pbGhostEXPParams
    end
    self.bitmap.fill_rect(@spriteBaseX + eb_x, eb_y, eb_w, eb_h, Color.new(0, 0, 0, 0))

    @sprites.each { |k, s| s.visible = false if k.to_s.downcase.include?("exp") } if @sprites
    @expBar.visible = false if @expBar

    pbSetSystemFont(self.bitmap)
    name_str = "Substitute"
    base_color = PokemonDataBox::NAME_BASE_COLOR rescue Color.new(255, 255, 255)
    shadow_color = PokemonDataBox::NAME_SHADOW_COLOR rescue Color.new(32, 32, 32)
    
    text_pos = [[name_str, @spriteBaseX + 8, 0, false, base_color, shadow_color]]
    pbDrawTextPositions(self.bitmap, text_pos)
    
    refreshHP
  end

  def refreshHP
    return if !@battler || !@battler.pokemon
    current_hp = @battler.effects[PBEffects::Substitute] rescue 0
    if current_hp <= 0
      @sub_max_hp = 0
      @hpNumbers.bitmap.clear if @hpNumbers && @hpNumbers.bitmap
      @hpBar.src_rect.width = 0 if @hpBar
      return
    end
    @sub_max_hp = current_hp if current_hp > (@sub_max_hp || 0)
    max_hp = @sub_max_hp
    max_hp = 1 if max_hp < 1
    
    w = 0
    if current_hp > 0
      w = @hpBarBitmap.width.to_f * current_hp / max_hp
      w = @hpBarBitmap.width if w > @hpBarBitmap.width
      w = 1 if w < 1
      w = ((w / 2.0).round) * 2
    end
    @hpBar.src_rect.width = w if @hpBar
    hp_color = 0 # Green
    hp_color = 1 if current_hp <= max_hp / 2
    hp_color = 2 if current_hp <= max_hp / 4
    @hpBar.src_rect.y = hp_color * @hpBarBitmap.height / 3 if @hpBar
    
    if @showHP && @hpNumbers && !@hpNumbers.disposed?
      @hpNumbers.bitmap.clear
      pbDrawNumber(current_hp, @hpNumbers.bitmap, 54, 2, 1)
      pbDrawNumber(-1, @hpNumbers.bitmap, 54, 2)
      pbDrawNumber(max_hp, @hpNumbers.bitmap, 70, 2)
    end
  end

  def refreshExp; end # Do nothing
  def drawtypeDisplay; end # Substitute boxes should not show type icons
  def refreshtypeDisplay; end

  def x=(value)
    # GHOST FIX: Prepend to the left of the owner
    s_zoom = pbGhostGetDataboxScale rescue 1.0
    shift_amt = (216 * s_zoom).to_i
    super(value - shift_amt)
  end
  
  def y=(value)
    # GHOST FIX: Same height as owner
    super(value)
  end
end

class PokeBattle_Scene
  alias ghost_classicplus_substitute_pbStartBattle pbStartBattle
  def pbStartBattle(battle)
    ghost_classicplus_substitute_pbStartBattle(battle)
    return if (@battle.class.to_s == "PokeBattle_SafariZone") rescue false
    @battle.battlers.each_with_index do |b, i|
      next if !b || b.opposes?(0)
      @sprites["substituteBox_#{i}"] = SubstituteDataBox.new(b, @battle.pbSideSize(i), @viewport)
      @sprites["substituteBox_#{i}"].visible = false
      @sprites["substituteBox_#{i}"].z = (@sprites["dataBox_#{i}"].z rescue 50) - 1
    end
  end

  alias ghost_classicplus_substitute_pbUpdate pbUpdate
  def pbUpdate(cw = nil)
    ghost_classicplus_substitute_pbUpdate(cw)
    return if (@battle.class.to_s == "PokeBattle_SafariZone") rescue false
    @battle.battlers.each_with_index do |b, i|
      next if !b || b.opposes?(0)
      sub_box = @sprites["substituteBox_#{i}"]
      next if !sub_box
      
      should_show = b.effects[PBEffects::Substitute] > 0 && !b.fainted? rescue false
      if should_show
        owner_box = @sprites["dataBox_#{i}"]
        sub_box.visible = owner_box ? owner_box.visible : true
        # Avoid calling refresh every frame! Only refresh if HP changed.
        # Track previous substitute HP to only refresh when it changes.
        sub_hp = b.effects[PBEffects::Substitute] rescue 0
        if sub_box.instance_variable_get(:@last_sub_hp) != sub_hp
          sub_box.refresh
          sub_box.instance_variable_set(:@last_sub_hp, sub_hp)
        end
        if owner_box
          sub_box.x = owner_box.x
          sub_box.y = owner_box.y 
          sub_box.z = owner_box.z - 1
        end
      else
        sub_box.visible = false
        sub_box.instance_variable_set(:@last_sub_hp, -1)
      end
    end
  end

  if method_defined?(:pbRefreshBattlerTones)
    alias ghost_classicplus_sub_tones pbRefreshBattlerTones
    def pbRefreshBattlerTones(active_idx, target_idx = -1)
      ghost_classicplus_sub_tones(active_idx, target_idx)
      @battle.battlers.each_with_index do |b, i|
        next if !b || b.opposes?(0)
        sub_box = @sprites["substituteBox_#{i}"]
        owner_box = @sprites["dataBox_#{i}"]
        if sub_box && owner_box
          sub_box.opacity = owner_box.opacity
          if sub_box.respond_to?(:ghostmod_highlighted=) && owner_box.respond_to?(:ghostmod_highlighted=)
             sub_box.ghostmod_highlighted = owner_box.ghostmod_highlighted
          end
        end
      end
    end
  end
end

#=============================================================================
# [AUDIT FIX] Global Origin and Visibility Management for ClassicPlus animations
#=============================================================================
# Redefine the global pbSpriteSetAnimFrame to fix coordinate math for tall sheets
# and force visibility layering (A/B split) for all ClassicPlus animations.
#=============================================================================
alias ghostmod_animation_pbSpriteSetAnimFrame pbSpriteSetAnimFrame
def pbSpriteSetAnimFrame(sprite, frame, user = nil, target = nil, inEditor = false)
  # 1. Standard player processing
  ghostmod_animation_pbSpriteSetAnimFrame(sprite, frame, user, target, inEditor)
  
  return if !sprite || !sprite.bitmap || sprite.bitmap.disposed?
  
  # 2. Pattern detection
  pattern = frame[1] rescue 0
  
  # 3. Keep battler cels foot-anchored regardless of sheet aspect ratio.
  # The base player centers origin every frame; for battler cels (pattern < 0)
  # this can create a one-frame half-height drop on some AOE animations.
  if pattern && pattern < 0
    sprite.ox = sprite.src_rect.width / 2
    sprite.oy = sprite.src_rect.height
  elsif sprite.bitmap.height > sprite.bitmap.width * 2
    # Preserve bottom anchor for exceptionally tall effect sheets as before.
    sprite.ox = sprite.src_rect.width / 2
    sprite.oy = sprite.src_rect.height
  end
  
  # 4. Forced Layering for A/B Split (Skills in Front)
  if sprite == user || sprite == target
    sprite.visible = true
    sprite.opacity = 255
    # Body layer: Above dimming (80)
    sprite.z = 95
  elsif pattern && pattern >= 0
    # Skill layer: Always in front of everything
    sprite.z = 150
  elsif pattern && pattern < 0
    # Clone/Glow layer: In front of the body
    sprite.z = 120
  end
end
