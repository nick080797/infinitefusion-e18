#===============================================================================
# Ghost's Quality of Life (QoL) Modular Mod
#===============================================================================
# This mod is a collection of various smaller QoL improvements.
# Each feature can be toggled individually in the Mod Settings menu.
#===============================================================================

module GhostQoL
    @active_windows = []
    def self.add_window(w); @active_windows.push(w); end
        def self.remove_window(w); @active_windows.delete(w); end
            def self.any_ui_visible?(exclude_window=nil)
                @active_windows.delete_if { |w| w.disposed? }
                for w in @active_windows
                    next if w == exclude_window
                    return true if w.visible && w.z > 100
                end
                return false
            end

            def self.refresh_pocketwatch
                return if !$ghost_qol_pocketwatch_window || $ghost_qol_pocketwatch_window.disposed?
                $ghost_qol_pocketwatch_window.refresh_visibility
            end

            @features = {}

            # EasyDisguise: Add persistence to Trainer for previous outfit
        end

        class Trainer
            attr_accessor :ghost_qol_prev_clothes
            attr_accessor :ghost_qol_prev_hat
        end

        module GhostQoL

            # --- Master Initializer ---
            def self.init
                # Initialize all registered sub-mods
                @features.each do |key, data|
                    self.register_feature_setting(key, data)
                    # Ensure new features default to ON (1) if they aren't in the save file yet.
                    # This keeps the fixes isolated to this file as requested.
                    if ModSettingsMenu.get(key).nil?
                        ModSettingsMenu.set(key, data[:default])
                    end
                end
            end

            # --- API for Sub-Mods ---

            # Registers a new sub-mod feature
            def self.register_feature(key, name, description, default = 0, type = :toggle, values = nil)
                @features[key] = {
                    name: name,
                    description: description,
                    default: default,
                    type: type,
                    values: values
                }
            end

            # Internal: Registers the setting in the ModSettingsMenu for an individual feature
            def self.register_feature_setting(key, data)
                unless ModSettingsMenu.categories.any? { |c| c[:name] == "Ghost Settings" }
                    ModSettingsMenu.categories << {
                        name: "Ghost Settings",
                        priority: 85,
                        description: "Settings for GhostXYZ mods",
                        collapsed: true
                    }
                end
                ModSettingsMenu.register(key, {
                                               name: "QoL: #{data[:name]}",
                                               type: data[:type] || :toggle,
                                               values: data[:values],
                                               description: data[:description],
                                               default: data[:default],
                                               category: "Ghost Settings"
                                              })
            end

            def self.enabled?(key)
                # Check individual feature toggle
                setting = ModSettingsMenu.get(key)
                # If the setting hasn't been saved yet, default to disabled (0)
                return false if setting.nil?
                return setting == 1
            end

            def self.has_rocket_disguise?
                return false if !$Trainer
                return (hasClothes?(CLOTHES_TEAM_ROCKET_MALE) || hasClothes?(CLOTHES_TEAM_ROCKET_FEMALE)) && hasHat?(HAT_TEAM_ROCKET)
            end

            def self.is_wearing_rocket_disguise?
                return false if !$Trainer
                # Using the existing game function for consistency
                return isWearingTeamRocketOutfit()
            end

            def self.toggle_disguise
                return if !has_rocket_disguise?
                if is_wearing_rocket_disguise?
                    # Remove disguise
                    prev_clothes = $Trainer.ghost_qol_prev_clothes || getDefaultClothes()
                    prev_hat = $Trainer.ghost_qol_prev_hat # can be nil
                    # Update state before calling game functions
                    $Trainer.clothes = prev_clothes
                    $Trainer.hat     = prev_hat
                    $Trainer.ghost_qol_prev_clothes = nil
                    $Trainer.ghost_qol_prev_hat     = nil

                    # Use game functions to apply changes (true for silent)
                    putOnClothes(prev_clothes, true)
                    putOnHat(prev_hat, true) if prev_hat
                    $Trainer.hat = nil if !prev_hat # Ensure nil persists if it was nil

                    pbMessage(_INTL("Removed the disguise."))
                else
                    # Equip disguise
                    $Trainer.ghost_qol_prev_clothes = $Trainer.clothes
                    $Trainer.ghost_qol_prev_hat     = $Trainer.hat
                    gender = pbGet(VAR_TRAINER_GENDER)
                    rocket_clothes = (gender == GENDER_MALE) ? CLOTHES_TEAM_ROCKET_MALE : CLOTHES_TEAM_ROCKET_FEMALE

                    # Apply disguise
                    putOnClothes(rocket_clothes, true)
                    putOnHat(HAT_TEAM_ROCKET, true)

                    pbMessage(_INTL("Equipped the Team Rocket disguise!"))
                end
                updateOutfitSwitches()
                refreshPlayerOutfit()
            end

            # --- BOILERPLATE / EXAMPLE SUB-MODS ---
            # To add a new sub-mod:
            # 1. Register it below using GhostQoL.register_feature
            # 2. Use `if GhostQoL.enabled?(:your_key)` in your code to gate the functionality.

            # Sub-mod: Learn Move Stats
            self.register_feature(:qol_move_learn_stats_v2, "Learn Move Stats", "Press LEFT on move learn screen for stats.", 0)

            # Sub-mod: Pokedex Search
            self.register_feature(:qol_pokedex_search_v2, "Pokedex Search", "Enables full-text Pokédex name search.", 0)

            # Sub-mod: Tutor.net Upgrade
            self.register_feature(:qol_tutor_net_upgrade_v2, "Tutor.net Upgrade", "Upgrades Tutor.net with dynamic info panel.", 0)

            # Sub-mod: Slots AutoPlay
            self.register_feature(:qol_slots_autoplay_v2, "Slots AutoPlay", "Enables AutoPlay for slot machines.", 0)

            # Sub-mod: Intro Skip
            self.register_feature(:qol_skip_intro_v2, "Intro Skip", "Skips intro cinematics and logos.", 0)

            # Sub-mod: Shop Move Preview
            self.register_feature(:qol_shop_move_preview_v2, "Shop Move Preview", "Press X in mart to preview TM/HM moves.", 0)

            # Sub-mod: Battle Size Selector
            # Incrementing version keys to ensure defaults are applied correctly.
            self.register_feature(:qol_battle_size_wild_v6, "Wild Size", "Prompt for battle size in wild encounters.", 0)
            self.register_feature(:qol_battle_size_trainer_v6, "Trainer Size", "Prompt for battle size in trainer battles.", 0)
            self.register_feature(:qol_wild_battle_size_randomizer_v6, "Random Size", "Randomize wild sizes (bypass prompt).", 0, :enum, ["Off", "2v2", "3v3"])

            # Sub-mod: Battle Move Info
            self.register_feature(:qol_battle_move_info_v4, "Battle Move Info", "Press X in battle for detailed move info.", 0)

            # Sub-mod: Hotel Multi-sleep
            self.register_feature(:qol_hotel_multi_sleep_v2, "Hotel Multi-sleep", "Adds options for longer hotel stays.", 0)

            # Sub-mod: Tutor.net Filter
            self.register_feature(:qol_tutor_net_filter_v2, "Tutor.net Filter", "Press RIGHT in Tutor.net to filter by Pokémon.", 0)

            # Sub-mod: EasyDisguise
            self.register_feature(:qol_easy_disguise_v1, "EasyDisguise", "Toggle TR disguise from the Outfit menu.", 0)

            # Sub-mod: PocketWatch
            self.register_feature(:qol_pocketwatch_v1, "PocketWatch", "Permanent clock in the top-left corner.", 0)


            # Sub-mod: PC-Plus
            self.register_feature(:qol_pc_plus_v1, "PC-Plus", "Adds Box Visual Renaming and Bulk Action features.", 0)

        end

        # --- Integration with Game Startup ---
        # Initialize if ModSettingsMenu is available. If not, queue for when it loads.
        # This handles both legacy (alphabetical) and managed (Mod Manager) loading.
        if defined?(ModSettingsMenu)
            GhostQoL.init
        else
            $MOD_SETTINGS_PENDING_REGISTRATIONS ||= []
            $MOD_SETTINGS_PENDING_REGISTRATIONS << proc { GhostQoL.init }
        end

        # Also re-initialize on save load to ensure defaults are present if the save was missing them.
        EventHandlers.add(:on_load_save_file, :ghost_qol_init) do |save_data|
            GhostQoL.init
        end if defined?(EventHandlers)

        #===============================================================================
        # SUB-MOD IMPLEMENTATIONS
        #===============================================================================

        # --- [GhostQoL] Learn Move Stats ---
        # Press LEFT on Move Learn screen to view stats.
        #-------------------------------------------------------------------------------
        class PokemonSummary_Scene
            alias ghost_qol_pbStartForgetScene pbStartForgetScene
            def pbStartForgetScene(party, partyindex, move_to_learn)
                @ghost_qol_stats_view = false
                ghost_qol_pbStartForgetScene(party, partyindex, move_to_learn)
            end

            alias ghost_qol_pbChooseMoveToForget pbChooseMoveToForget
            def pbChooseMoveToForget(move_to_learn)
                return ghost_qol_pbChooseMoveToForget(move_to_learn) unless GhostQoL.enabled?(:qol_move_learn_stats_v2)

                new_move = (move_to_learn) ? Pokemon::Move.new(move_to_learn) : nil
                selmove = 0
                maxmove = (new_move) ? Pokemon::MAX_MOVES : Pokemon::MAX_MOVES - 1
                loop do
                    Graphics.update
                    Input.update
                    pbUpdate
                    if Input.trigger?(Input::BACK)
                        selmove = Pokemon::MAX_MOVES
                        pbPlayCloseMenuSE if new_move
                        break
                    elsif Input.trigger?(Input::USE)
                        if @ghost_qol_stats_view
                            @ghost_qol_stats_view = false
                            pbPlayDecisionSE
                            drawSelectedMove(new_move, (selmove == Pokemon::MAX_MOVES) ? new_move : @pokemon.moves[selmove])
                        else
                            pbPlayDecisionSE
                            break
                        end
                    elsif Input.trigger?(Input::UP)
                        next if @ghost_qol_stats_view
                        selmove -= 1
                        selmove = maxmove if selmove < 0
                        if selmove < Pokemon::MAX_MOVES && selmove >= @pokemon.numMoves
                            selmove = @pokemon.numMoves - 1
                        end
                        @sprites["movesel"].index = selmove
                        selected_move = (selmove == Pokemon::MAX_MOVES) ? new_move : @pokemon.moves[selmove]
                        drawSelectedMove(new_move, selected_move)
                    elsif Input.trigger?(Input::DOWN)
                        next if @ghost_qol_stats_view
                        selmove += 1
                        selmove = 0 if selmove > maxmove
                        if selmove < Pokemon::MAX_MOVES && selmove >= @pokemon.numMoves
                            selmove = (new_move) ? maxmove : 0
                        end
                        @sprites["movesel"].index = selmove
                        selected_move = (selmove == Pokemon::MAX_MOVES) ? new_move : @pokemon.moves[selmove]
                        drawSelectedMove(new_move, selected_move)
                    elsif Input.trigger?(Input::LEFT)
                        if !@ghost_qol_stats_view
                            @ghost_qol_stats_view = true
                            pbPlayDecisionSE
                            @sprites["movesel"].visible = false
                            drawSelectedMove(new_move, (selmove == Pokemon::MAX_MOVES) ? new_move : @pokemon.moves[selmove])
                        end
                    elsif Input.trigger?(Input::RIGHT)
                        if @ghost_qol_stats_view
                            @ghost_qol_stats_view = false
                            pbPlayDecisionSE
                            @sprites["movesel"].visible = true
                            drawSelectedMove(new_move, (selmove == Pokemon::MAX_MOVES) ? new_move : @pokemon.moves[selmove])
                        end
                    end
                end
                return (selmove == Pokemon::MAX_MOVES) ? -1 : selmove
            end

            alias ghost_qol_drawPageFourSelecting drawPageFourSelecting
            def drawPageFourSelecting(move_to_learn)
                if GhostQoL.enabled?(:qol_move_learn_stats_v2) && @ghost_qol_stats_view
                    ghost_qol_draw_stats_in_move_list(move_to_learn)
                else
                    ghost_qol_drawPageFourSelecting(move_to_learn)
                end
            end

            def ghost_qol_draw_stats_in_move_list(move_to_learn)
                overlay = @sprites["overlay"].bitmap
                overlay.clear
                base = Color.new(248, 248, 248)
                shadow = Color.new(104, 104, 104)
                stat_base = Color.new(64, 64, 64)
                stat_shadow = Color.new(176, 176, 176)

                # Background for stats view
                if move_to_learn
                    @sprites["background"].setBitmap("Graphics/Pictures/Summary/bg_learnmove")
                else
                    @sprites["background"].setBitmap("Graphics/Pictures/Summary/bg_movedetail")
                end

                # --- EXACT REPLICATION: Load and blit official Skills background ---
                skills_bg = AnimatedBitmap.new("Graphics/Pictures/Summary/bg_3")
                # Blit the right side (where stats are) to cover move slots
                # Added 5px shift to the right
                overlay.blt(238 + 5, 50, skills_bg.bitmap, Rect.new(238, 50, 274, 310))
                skills_bg.dispose

                # Header and Type info
                textpos = [
                    [_INTL("SKILLS"), 26, 10, 0, base, shadow],
                    [_INTL("CATEGORY"), 20, 116, 0, base, shadow],
                    [_INTL("POWER"), 20, 148, 0, base, shadow],
                    [_INTL("ACCURACY"), 20, 180, 0, base, shadow]
                ]

                type1_number = GameData::Type.get(@pokemon.type1).id_number
                type2_number = GameData::Type.get(@pokemon.type2).id_number
                type1rect = Rect.new(0, type1_number * 28, 64, 28)
                type2rect = Rect.new(0, type2_number * 28, 64, 28)
                if @pokemon.type1 == @pokemon.type2
                    overlay.blt(130, 78, @typebitmap.bitmap, type1rect)
                else
                    overlay.blt(96, 78, @typebitmap.bitmap, type1rect)
                    overlay.blt(166, 78, @typebitmap.bitmap, type2rect)
                end

                # Official Summary Screen Stats Layout
                stats = [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED]
                stats_value = [:totalhp, :attack, :defense, :spatk, :spdef, :speed]
                stats_displayname = [_INTL("HP"), _INTL("Attack"), _INTL("Defense"), _INTL("Sp. Atk"), _INTL("Sp. Def"), _INTL("Speed")]

                statshadows = {}
                GameData::Stat.each_main { |s| statshadows[s.id] = shadow }
                if !@pokemon.shadowPokemon? || @pokemon.heartStage > 3
                    @pokemon.nature_for_stats.stat_changes.each do |change|
                        statshadows[change[0]] = Color.new(136, 96, 72) if change[1] > 0
                        statshadows[change[0]] = Color.new(64, 120, 152) if change[1] < 0
                    end
                end

                stats.length.times do |i|
                    # Precise official Y positions
                    case i
                    when 0 then y = 70
                    when 1 then y = 114
                    when 2 then y = 146
                    when 3 then y = 178
                    when 4 then y = 210
                    when 5 then y = 242
                    end

                    base_stat = @pokemon.baseStats[stats[i]]
                    ev_stat = ($PokemonSystem.noevsmode && $PokemonSystem.noevsmode > 0) ? 0 : @pokemon.ev[stats[i]]
                    iv_stat = ($PokemonSystem.maxivsmode && $PokemonSystem.maxivsmode > 0) ? Pokemon::IV_STAT_LIMIT : @pokemon.iv[stats[i]]

                    # Shifted stat names by an additional 6px (total 236 + 11)
                    # Other columns maintain their +5 shift
                    textpos += [
                        [stats_displayname[i], 236 + 11, y, 0, base, statshadows[stats[i]]],
                        [sprintf("%d", @pokemon.send(stats_value[i].downcase)), 380 + 5, y, 1, stat_base, stat_shadow],
                        [sprintf("%d", iv_stat), 420 + 5, y, 1, Color.new(84, 64, 44), Color.new(248, 148, 0)],
                        [sprintf("%d", ev_stat), 460 + 5, y, 1, Color.new(54, 84, 54), Color.new(24, 192, 32)],
                        [sprintf("%d", base_stat), 500 + 5, y, 1, Color.new(36, 60, 80), Color.new(88, 152, 248)]
                    ]

                    if i == 0 # HP specific row extras
                        # Removed redundant current HP display to fix "double HP" issue
                        textpos << ["IV", 420 + 5, y - 23, 1, Color.new(64, 44, 24), Color.new(228, 128, 0)]
                        textpos << ["EV", 460 + 5, y - 23, 1, Color.new(34, 64, 34), Color.new(4, 172, 12)]
                        textpos << ["BST", 500 + 5, y - 23, 1, Color.new(36, 60, 80), Color.new(88, 152, 248)]
                    end
                end

                pbDrawTextPositions(overlay, textpos)

                # Precise HP Bar replication (5px shift added to X)
                if @pokemon.hp > 0
                    w = @pokemon.hp * 96 * 1.0 / @pokemon.totalhp
                    w = 1 if w < 1
                    w = ((w / 2).round) * 2
                    hpzone = 0
                    hpzone = 1 if @pokemon.hp <= (@pokemon.totalhp / 2).floor
                    hpzone = 2 if @pokemon.hp <= (@pokemon.totalhp / 4).floor
                    imagepos = [
                        ["Graphics/Pictures/Summary/overlay_hp", 360 + 5, 110, 0, hpzone * 6, w, 6]
                    ]
                    pbDrawImagePositions(overlay, imagepos)
                end

                # Help text (5px shift added to X)
                textpos_help = [[_INTL("Press RIGHT to see moves"), 375 + 5, 340, 1, Color.new(128, 128, 128), Color.new(192, 192, 192)]]
                pbDrawTextPositions(overlay, textpos_help)
            end
        end

        # --- [GhostQoL] Pokedex Search ---
        # Enables full-text name search in the Pokédex using keyboard input.
        #-------------------------------------------------------------------------------
        class PokemonPokedex_Scene
            def pbEnterPokedexSearchName(current_text)
                initial_text = current_text.is_a?(String) ? current_text : ""
                helptext = _INTL("Search Pokédex (min 3 chars):")
                minlength = 3
                maxlength = 15
                scene = PokemonEntryScene.new
                screen = PokemonEntry.new(scene)
                ret = screen.pbStartScreen(helptext, minlength, maxlength, initial_text)
                return (ret == "") ? -1 : ret
            end

            alias ghost_qol_pbRefreshDexSearch pbRefreshDexSearch
            def pbRefreshDexSearch(params, index)
                if GhostQoL.enabled?(:qol_pokedex_search_v2)
                    old_val = params[1]
                    params[1] = -1 if old_val.is_a?(String)
                    ghost_qol_pbRefreshDexSearch(params, index)
                    params[1] = old_val
                    if params[1].is_a?(String)
                        overlay = @sprites["overlay"].bitmap
                        base   = Color.new(248,248,248)
                        shadow = Color.new(72,72,72)
                        pbDrawTextPositions(overlay, [[params[1], 176, 116, 2, base, shadow, 1]])
                    end
                else
                    ghost_qol_pbRefreshDexSearch(params, index)
                end
            end

            alias ghost_qol_pbSearchDexList pbSearchDexList
            def pbSearchDexList(params)
                if GhostQoL.enabled?(:qol_pokedex_search_v2) && params[1].is_a?(String)
                    $PokemonGlobal.pokedexMode = params[0]
                    dexlist = pbGetDexList
                    search_query = params[1].downcase
                    dexlist = dexlist.find_all { |item|
                                                 next false if !$Trainer.seen?(item[0])
                                               name = item[1].downcase
                                               next name.include?(search_query)
                                               }
                    # Replicate other filters (Type, Height, Weight, Color, Shape)
                    if params[2]>=0 || params[3]>=0
                        stype1 = (params[2]>=0) ? @typeCommands[params[2]].id : nil
                        stype2 = (params[3]>=0) ? @typeCommands[params[3]].id : nil
                        dexlist = dexlist.find_all { |item|
                                                     next false if !$Trainer.owned?(item[0])
                                                   t1 = item[6]; t2 = item[7]
                                                   if stype1 && stype2
                                                   next (t1==stype1 && t2==stype2) || (t1==stype2 && t2==stype1)
                                                   elsif stype1
                                                   next t1==stype1 || t2==stype1
                                                   elsif stype2
                                                   next t1==stype2 || t2==stype2
                                                   else
                                                   next false
                                                   end
                                                   }
                    end
                    if params[4]>=0 || params[5]>=0
                        minh = (params[4]<0) ? 0 : (params[4]>=@heightCommands.length) ? 999 : @heightCommands[params[4]]
                        maxh = (params[5]<0) ? 999 : (params[5]>=@heightCommands.length) ? 0 : @heightCommands[params[5]]
                        dexlist = dexlist.find_all { |item|
                                                     next false if !$Trainer.owned?(item[0])
                                                   h = item[2]
                                                   next h>=minh && h<=maxh
                                                   }
                    end
                    if params[6]>=0 || params[7]>=0
                        minw = (params[6]<0) ? 0 : (params[6]>=@weightCommands.length) ? 9999 : @weightCommands[params[6]]
                        maxw = (params[7]<0) ? 9999 : (params[7]>=@weightCommands.length) ? 0 : @weightCommands[params[7]]
                        dexlist = dexlist.find_all { |item|
                                                     next false if !$Trainer.owned?(item[0])
                                                   w = item[3]
                                                   next w>=minw && w<=maxw
                                                   }
                    end
                    if params[8]>=0
                        scolor = @colorCommands[params[8]].id
                        dexlist = dexlist.find_all { |item|
                                                     next false if !$Trainer.seen?(item[0])
                                                   next item[8] == scolor
                                                   }
                    end
                    if params[9]>=0
                        sshape = @shapeCommands[params[9]].id
                        dexlist = dexlist.find_all { |item|
                                                     next false if !$Trainer.seen?(item[0])
                                                   next item[9] == sshape
                                                   }
                    end
                    dexlist = dexlist.find_all { |item| next $Trainer.seen?(item[0]) }
                    case $PokemonGlobal.pokedexMode
                    when 0 then dexlist.sort! { |a,b| a[4]<=>b[4] }
                    when 1 then dexlist.sort! { |a,b| a[1]<=>b[1] }
                    when 2 then dexlist.sort! { |a,b| b[3]<=>a[3] }
                    when 3 then dexlist.sort! { |a,b| a[3]<=>b[3] }
                    when 4 then dexlist.sort! { |a,b| b[2]<=>a[2] }
                    when 5 then dexlist.sort! { |a,b| a[2]<=>b[2] }
                    end
                    return dexlist
                else
                    return ghost_qol_pbSearchDexList(params)
                end
            end

            alias ghost_qol_pbDexSearchCommands pbDexSearchCommands
            def pbDexSearchCommands(mode, selitems, mainindex)
                if GhostQoL.enabled?(:qol_pokedex_search_v2) && mode == 1
                    new_name = pbEnterPokedexSearchName(selitems[0])
                    return [new_name] if new_name != selitems[0]
                    return nil
                end
                return ghost_qol_pbDexSearchCommands(mode, selitems, mainindex)
            end
        end

        # --- [GhostQoL] Tutor.net Upgrade ---
        # Upgrades the Tutor.net menu with a dynamic move info panel.
        #-------------------------------------------------------------------------------
        class Window_TutorNet
            # Removed index= alias as we now use update_indicators hook for better reliability.
        end

        # Guarded: TutorNetPartyPanel is not defined anywhere in this build (no
        # mod or base script defines it -- confirmed by project-wide search), so
        # without this guard `class TutorNetPartyPanel` below silently creates a
        # brand-new empty class and `alias ghost_qol_refresh refresh` then raises
        # NameError, aborting the rest of this 2000+ line file's load. Skipping
        # this vestigial integration when the real class isn't present lets the
        # rest of Ghost_QoL load normally; it re-activates automatically if a
        # real Tutor.net-providing mod/script is ever added ahead of this file.
        if defined?(TutorNetPartyPanel)
        class TutorNetPartyPanel
            attr_accessor :ghost_qol_stab
            attr_accessor :ghost_qol_dimmed

            alias ghost_qol_initialize initialize
            def initialize(pokemon, index, viewport = nil, comp = 0)
                ghost_qol_initialize(pokemon, index, viewport, comp)
                @ghost_qol_hue = 0
                @ghost_qol_stab = false
                @ghost_qol_filter_active = false
                @ghost_qol_dimmed = false
            end

            def ghost_qol_dimmed=(value)
                if @ghost_qol_dimmed != value
                    @ghost_qol_dimmed = value
                    refresh
                end
            end

            def ghost_qol_filter_active=(value)
                if @ghost_qol_filter_active != value
                    @ghost_qol_filter_active = value
                    refresh
                end
            end

            alias ghost_qol_refresh refresh
            def refresh
                ghost_qol_refresh
                return if disposed?

                # Apply greyscale if dimmed
                tone = @ghost_qol_dimmed ? Tone.new(0, 0, 0, 255) : Tone.new(0, 0, 0, 0)
                @pkmnsprite.tone = tone if @pkmnsprite && !@pkmnsprite.disposed?
                @overlaysprite.tone = tone if @overlaysprite && !@overlaysprite.disposed?

                return if !@ghost_qol_filter_active

                # Draw a distinct filter highlight box
                if @overlaysprite && !@overlaysprite.disposed?
                    # Icon is drawn at (0, 0) on the @overlaysprite bitmap (which is offset to self.x-20, self.y)
                    # Compatibility icon size is 48x48
                    rect_color = Color.new(0, 255, 0, 200) # Slightly more opaque green
                    @overlaysprite.bitmap.fill_rect(0, 0, 48, 2, rect_color)
                    @overlaysprite.bitmap.fill_rect(0, 46, 48, 2, rect_color)
                    @overlaysprite.bitmap.fill_rect(0, 0, 2, 48, rect_color)
                    @overlaysprite.bitmap.fill_rect(46, 0, 2, 48, rect_color)
                end
            end

            alias ghost_qol_update update
            def update
                ghost_qol_update
                if @ghost_qol_stab && @comp == 1 && !@ghost_qol_dimmed && @overlaysprite && !@overlaysprite.disposed?
                    @ghost_qol_hue = (@ghost_qol_hue + 10) % 360
                    t = @ghost_qol_hue
                    r = (Math.sin(t * Math::PI / 180) * 127 + 128).to_i
                    g = (Math.sin((t + 120) * Math::PI / 180) * 127 + 128).to_i
                    b = (Math.sin((t + 240) * Math::PI / 180) * 127 + 128).to_i
                    @overlaysprite.color = Color.new(r, g, b, 160)
                elsif @overlaysprite && !@overlaysprite.disposed?
                    @overlaysprite.color = Color.new(0, 0, 0, 0)
                end
            end
        end
        end # defined?(TutorNetPartyPanel)

        # Guarded for the same reason as TutorNetPartyPanel above: PokemonTutorNet_Scene
        # is not defined anywhere in this build either, so `alias ghost_qol_pbStartScene
        # pbStartScene` below would otherwise raise NameError and abort the rest of the file.
        if defined?(PokemonTutorNet_Scene)
        class PokemonTutorNet_Scene
            alias ghost_qol_pbStartScene pbStartScene
            def pbStartScene(commands, party, move_list, last_move_index = 0, last_mon_index = 0)
                # Store initial lists for filtering
                @ghost_qol_full_commands = commands.clone
                @ghost_qol_full_move_list = move_list.clone
                @ghost_qol_filtered_to_original = (0...commands.length).to_a
                @ghost_qol_filter_index = nil
                @ghost_qol_submode = :move_list
                @ghost_qol_party_index = 0

                ghost_qol_pbStartScene(commands, party, move_list, last_move_index, last_mon_index)
                return if !GhostQoL.enabled?(:qol_tutor_net_upgrade_v2)

                # Shrink the command window to make room for info
                @sprites["commands"].height = 250
                @sprites["commands"].update_cursor_rect

                # Create info panel sprites
                @sprites["info_overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
                @sprites["info_overlay"].z = @sprites["commands"].z + 10

                @ghost_qol_last_index = -1
                ghost_qol_draw_move_info
            end

            alias ghost_qol_update_indicators update_indicators
            def update_indicators(move_list = @move_list)
                ghost_qol_update_indicators(move_list)
                return if !GhostQoL.enabled?(:qol_tutor_net_upgrade_v2)

                list = @sprites["commands"]
                return if !list

                # Selection update logic
                if list.index != @ghost_qol_last_index
                    @ghost_qol_last_index = list.index
                    ghost_qol_draw_move_info
                end

                # STAB glow logic
                move_data = list.move(move_list)
                if move_data.is_a?(Array)
                    move_id = move_data[0][0]
                    move = GameData::Move.get(move_id)
                    for i in 0...Settings::MAX_PARTY_SIZE
                        sprite = @sprites["pokemon#{i}"]
                        if sprite.is_a?(TutorNetPartyPanel)
                            pkmn = @party[i]
                            sprite.ghost_qol_stab = (pkmn && !pkmn.egg? && pkmn.hasType?(move.type))
                        end
                    end
                end
            end

            # Removed pbUpdate alias as we now use update_indicators hook.

            def ghost_qol_draw_move_info
                return if !@sprites["info_overlay"]
                overlay = @sprites["info_overlay"].bitmap
                overlay.clear

                list = @sprites["commands"]
                move_data = list.move(@move_list)
                return if !move_data.is_a?(Array)

                move_id = move_data[0][0]

                # Use helper
                GhostQoL.draw_move_info(overlay, list.x, list.y + list.height, (list.width * 0.85).to_i, move_id)
            end

            def ghost_qol_rebuild_list
                @ghost_qol_filtered_to_original = []
                if @ghost_qol_filter_index.nil?
                    @sprites["commands"].commands = @ghost_qol_full_commands.clone
                    @move_list = @ghost_qol_full_move_list.clone
                    @ghost_qol_filtered_to_original = (0...@ghost_qol_full_commands.length).to_a
                else
                    pokemon = @party[@ghost_qol_filter_index]
                    new_commands = []
                    new_move_list = []
                    @ghost_qol_full_move_list.each_with_index do |move_entry, i|
                        # Only filter moves (arrays), keep utility commands like "Exit" or "Back"
                        is_util = (@ghost_qol_full_commands[i] == _INTL("Exit") || @ghost_qol_full_commands[i] == _INTL("Back") || @ghost_qol_full_commands[i] == "Exit" || @ghost_qol_full_commands[i] == "Back")

                        if move_entry.is_a?(Array) && move_entry[0].is_a?(Array)
                            move_id = move_entry[0][0]
                            if pokemon.compatible_with_move?(move_id)
                                new_commands << @ghost_qol_full_commands[i]
                                new_move_list << move_entry
                                @ghost_qol_filtered_to_original << i
                            end
                        elsif is_util
                            new_commands << @ghost_qol_full_commands[i]
                            new_move_list << move_entry
                            @ghost_qol_filtered_to_original << i
                        end
                    end
                    # Ensure there's always an exit if it got filtered out
                    unless new_commands.any? { |c| c == _INTL("Exit") || c == _INTL("Back") || c == "Exit" || c == "Back" }
                        new_commands << _INTL("Back")
                        new_move_list << nil
                        @ghost_qol_filtered_to_original << -1 # -1 handled in pbScene
                    end
                    @sprites["commands"].commands = new_commands
                    @move_list = new_move_list
                end
                @sprites["commands"].index = 0
                update_indicators
            end

            alias ghost_qol_pbScene pbScene
            def pbScene(noshift = false)
                return ghost_qol_pbScene(noshift) if !GhostQoL.enabled?(:qol_tutor_net_filter_v2)

                ret = -1
                loop do
                    Graphics.update
                    Input.update
                    pbUpdate
                    update_indicators

                    if @ghost_qol_submode == :move_list
                        if Input.trigger?(Input::RIGHT) && GhostQoL.enabled?(:qol_tutor_net_filter_v2)
                            @ghost_qol_submode = :party
                            @sprites["commands"].ignore_input = true
                            @sprites["commands"].active = false
                            @sprites["pokemon#{@ghost_qol_party_index}"].selected = true
                            pbPlayCursorSE
                        elsif Input.trigger?(Input::BACK)
                            break
                        elsif Input.trigger?(Input::SHIFT) && !noshift
                            # Fallback to original shift logic if needed
                            return ghost_qol_pbScene(noshift)
                        elsif Input.trigger?(Input::ACTION)
                            move_info
                        elsif Input.trigger?(Input::USE)
                            orig_idx = @ghost_qol_filtered_to_original[@sprites["commands"].index]
                            if orig_idx == -1 # New Back button
                                break
                            end
                            ret = orig_idx
                            break
                        end
                    else # :party mode
                        if Input.trigger?(Input::LEFT) && (@ghost_qol_party_index % 2 == 0)
                            @ghost_qol_submode = :move_list
                            @sprites["commands"].ignore_input = false
                            @sprites["commands"].active = true
                            @sprites["pokemon#{@ghost_qol_party_index}"].selected = false
                            pbPlayCursorSE
                        elsif Input.trigger?(Input::BACK)
                            @ghost_qol_submode = :move_list
                            @sprites["commands"].ignore_input = false
                            @sprites["commands"].active = true
                            @sprites["pokemon#{@ghost_qol_party_index}"].selected = false
                            pbPlayCursorSE
                        elsif Input.trigger?(Input::USE)
                            # Toggle filter
                            if @ghost_qol_filter_index == @ghost_qol_party_index
                                @ghost_qol_filter_index = nil
                            elsif !@party[@ghost_qol_party_index].egg? && !@party[@ghost_qol_party_index].shadowPokemon?
                                @ghost_qol_filter_index = @ghost_qol_party_index
                            else
                                pbPlayCancelSE
                                next
                            end

                            # Update visual highlights
                            for i in 0...Settings::MAX_PARTY_SIZE
                                sprite = @sprites["pokemon#{i}"]
                                if sprite.is_a?(TutorNetPartyPanel)
                                    sprite.ghost_qol_filter_active = (i == @ghost_qol_filter_index)
                                    sprite.ghost_qol_dimmed = (@ghost_qol_filter_index != nil && i != @ghost_qol_filter_index)
                                end
                            end

                            ghost_qol_rebuild_list
                            pbPlayDecisionSE
                        else
                            old_idx = @ghost_qol_party_index
                            if Input.repeat?(Input::UP)
                                @ghost_qol_party_index = pbChangeSelection(Input::UP, @ghost_qol_party_index)
                            elsif Input.repeat?(Input::DOWN)
                                @ghost_qol_party_index = pbChangeSelection(Input::DOWN, @ghost_qol_party_index)
                            elsif Input.repeat?(Input::LEFT)
                                @ghost_qol_party_index = pbChangeSelection(Input::LEFT, @ghost_qol_party_index)
                            elsif Input.repeat?(Input::RIGHT)
                                @ghost_qol_party_index = pbChangeSelection(Input::RIGHT, @ghost_qol_party_index)
                            end

                            if old_idx != @ghost_qol_party_index
                                pbPlayCursorSE
                                @sprites["pokemon#{old_idx}"].selected = false
                                @sprites["pokemon#{@ghost_qol_party_index}"].selected = true
                            end
                        end
                    end
                end
                return ret
            end
        end
        end # defined?(PokemonTutorNet_Scene)

        # --- [GhostQoL] PC-Plus ---
        # Bulk PC Management & Box Sorting
        #-------------------------------------------------------------------------------

        class PokemonBoxIcon
            attr_accessor :ghost_qol_selected

            alias ghost_qol_pcplus_update update
            def update
                ghost_qol_pcplus_update
                if @ghost_qol_selected
                    self.color = Color.new(0, 255, 0, 128)
                end
            end
        end

        class PokemonBoxSprite
            alias ghost_qol_pcplus_refresh refresh
            def refresh
                ghost_qol_pcplus_refresh
                ghost_qol_pcplus_highlights if GhostQoL.enabled?(:qol_pc_plus_v1)
            end

            def ghost_qol_pcplus_highlights
                return if !defined?($GhostQoL_PCPlus_Selections) || !$GhostQoL_PCPlus_Selections
                for i in 0...PokemonBox::BOX_SIZE
                    sprite = @pokemonsprites[i]
                    pkmn = @storage[@boxnumber, i]
                    if sprite && pkmn && !sprite.disposed?
                        is_selected = $GhostQoL_PCPlus_Selections.any? { |s| s[:box] == @boxnumber && s[:index] == i && s[:pid] == pkmn.personalID }
                        sprite.ghost_qol_selected = is_selected
                    end
                end
            end
        end

        $GhostQoL_PCPlus_Selections = []

        class PokemonStorageScreen
            alias ghost_qol_pcplus_pbStartScreen pbStartScreen
            def pbStartScreen(command)
                $GhostQoL_PCPlus_Selections = []
                ghost_qol_pcplus_pbStartScreen(command)
                $GhostQoL_PCPlus_Selections = []
            end
        end

        class PokemonStorageScene
            attr_accessor :ghost_qol_last_selected

            alias ghost_qol_pcplus_pbShowCommands pbShowCommands
            def pbShowCommands(msg, commands, index = 0)
                if GhostQoL.enabled?(:qol_pc_plus_v1)
                    if msg == _INTL("Pick the wallpaper.")
                        ret = -1
                        msgwindow = Window_UnformattedTextPokemon.newWithSize("", 180, 0, Graphics.width - 180, 32)
                        msgwindow.viewport = @viewport
                        msgwindow.visible = true
                        msgwindow.letterbyletter = false
                        msgwindow.text = msg
                        msgwindow.resizeHeightToFit(msg, Graphics.width - 180)
                        pbBottomRight(msgwindow)
                        cmdwindow = Window_CommandPokemon.new(commands)
                        cmdwindow.viewport = @viewport
                        cmdwindow.visible = true
                        cmdwindow.resizeToFit(cmdwindow.commands)
                        cmdwindow.height = Graphics.height - msgwindow.height if cmdwindow.height > Graphics.height - msgwindow.height
                        pbBottomRight(cmdwindow)
                        cmdwindow.y -= msgwindow.height
                        cmdwindow.index = index

                        papers = @storage.availableWallpapers
                        original_bg = @storage[@storage.currentBox].background
                        last_index = index

                        loop do
                            Graphics.update
                            Input.update
                            msgwindow.update
                            cmdwindow.update

                            if cmdwindow.index != last_index
                                last_index = cmdwindow.index
                                @storage[@storage.currentBox].background = papers[1][last_index]
                                pbHardRefresh
                            end

                            if Input.trigger?(Input::BACK)
                                ret = -1
                                @storage[@storage.currentBox].background = original_bg
                                pbHardRefresh
                                break
                            elsif Input.trigger?(Input::USE)
                                ret = cmdwindow.index
                                @storage[@storage.currentBox].background = original_bg
                                pbHardRefresh
                                break
                            end
                            self.update
                        end
                        msgwindow.dispose
                        cmdwindow.dispose
                        Input.update
                        return ret
                    end
                end

                is_box_commands = (commands[0] == _INTL("Jump") && commands[2] == _INTL("Name"))
                is_pkmn_commands = (commands.include?(_INTL("Summary")) && commands.include?(_INTL("Cancel")))

                if GhostQoL.enabled?(:qol_pc_plus_v1)
                    if is_box_commands
                        my_commands = commands.clone
                        jump_idx = my_commands.index(_INTL("Jump"))
                        cancel_idx = my_commands.index(_INTL("Cancel"))
                        if jump_idx && cancel_idx
                            my_commands.insert(jump_idx + 1, _INTL("Move Box"))
                            ret = ghost_qol_pcplus_pbShowCommands(msg, my_commands, index)

                            if ret == jump_idx + 1
                                # Move Box
                                destbox = pbChooseBox(_INTL("Swap with which Box?"))
                                if destbox >= 0 && destbox != @storage.currentBox
                                    tmp_box = @storage.boxes[@storage.currentBox]
                                    @storage.boxes[@storage.currentBox] = @storage.boxes[destbox]
                                    @storage.boxes[destbox] = tmp_box

                                    pbHardRefresh
                                end
                                return commands.index(_INTL("Cancel"))
                            elsif ret > jump_idx + 1
                                return ret - 1
                            else
                                return ret
                            end
                        end
                    elsif is_pkmn_commands
                        if $GhostQoL_PCPlus_Selections && $GhostQoL_PCPlus_Selections.length > 0 && !@screen.pbHolding? && !msg.include?("Party")
                            pkmn = nil
                            sel_box = nil
                            sel_index = nil
                            if @ghost_qol_last_selected && @ghost_qol_last_selected[0] >= 0
                                sel_box = @ghost_qol_last_selected[0]
                                sel_index = @ghost_qol_last_selected[1]
                                pkmn = @storage[sel_box, sel_index]
                            end

                            if pkmn
                                existing = $GhostQoL_PCPlus_Selections.find { |s| s[:box] == sel_box && s[:index] == sel_index && s[:pid] == pkmn.personalID }
                                toggle_text = existing ? _INTL("Deselect") : _INTL("Select")
                                bulk_cmds = [
                                    toggle_text,
                                    _INTL("Clear selection"),
                                    _INTL("Withdraw selected"),
                                    _INTL("Release selected"),
                                    _INTL("Cancel")
                                ]
                                ret = ghost_qol_pcplus_pbShowCommands(msg, bulk_cmds, 0)
                                if ret == 0 # Select/Deselect
                                    if existing
                                        $GhostQoL_PCPlus_Selections.delete(existing)
                                    else
                                        $GhostQoL_PCPlus_Selections.push({:box => sel_box, :index => sel_index, :pid => pkmn.personalID})
                                    end
                                    @sprites["box"].refresh if @sprites["box"]
                                    pbRefresh
                                elsif ret == 1 # Clear selection
                                    $GhostQoL_PCPlus_Selections.clear
                                    pbDisplay(_INTL("Cleared all selections."))
                                    @sprites["box"].refresh if @sprites["box"]
                                    pbRefresh
                                elsif ret == 2 # Withdraw selected
                                    withdraw_count = 0
                                    $GhostQoL_PCPlus_Selections.dup.each do |sel|
                                        break if @storage.party_full?
                                        pkmn_to_move = @storage[sel[:box], sel[:index]]
                                        next if !pkmn_to_move || pkmn_to_move.personalID != sel[:pid]
                                        @storage.party.push(pkmn_to_move)
                                        @storage.pbDelete(sel[:box], sel[:index])
                                        $GhostQoL_PCPlus_Selections.delete(sel)
                                        withdraw_count += 1
                                    end
                                    pbDisplay(_INTL("Withdrew {1} Pokémon.", withdraw_count))
                                    pbHardRefresh
                                elsif ret == 3 # Release selected
                                    if pbConfirmMessageSerious(_INTL("Release all {1} selected Pokémon?", $GhostQoL_PCPlus_Selections.length))
                                        rel_count = 0
                                        $GhostQoL_PCPlus_Selections.dup.each do |sel|
                                            pkmn_to_rel = @storage[sel[:box], sel[:index]]
                                            next if !pkmn_to_rel || pkmn_to_rel.personalID != sel[:pid]
                                            next if pkmn_to_rel.owner.name == "RENTAL" || pkmn_to_rel.egg? || pkmn_to_rel.mail
                                            @storage.pbDelete(sel[:box], sel[:index])
                                            $GhostQoL_PCPlus_Selections.delete(sel)
                                            rel_count += 1
                                        end
                                        pbDisplay(_INTL("Released {1} Pokémon.", rel_count))
                                        pbHardRefresh
                                    end
                                end
                                cancel_ret = commands.index(_INTL("Cancel"))
                                return cancel_ret ? cancel_ret : (commands.length - 1)
                            end
                        else
                            move_idx = commands.index(_INTL("Move")) || commands.index(_INTL("Shift")) || commands.index(_INTL("Place"))
                            if move_idx && !@screen.pbHolding? && !msg.include?("Party")
                                my_commands = commands.clone
                                my_commands.insert(move_idx + 1, _INTL("Select"))
                                ret = ghost_qol_pcplus_pbShowCommands(msg, my_commands, index)
                                if ret == move_idx + 1
                                    # Which Box and Index are we pointing at?
                                    # We captured it in pbSelectBox before this menu was called.
                                    if @ghost_qol_last_selected && @ghost_qol_last_selected[0] >= 0
                                        sel_box = @ghost_qol_last_selected[0]
                                        sel_index = @ghost_qol_last_selected[1]
                                        pkmn = @storage[sel_box, sel_index]

                                        if pkmn
                                            $GhostQoL_PCPlus_Selections ||= []
                                            # Check if already selected
                                            existing = $GhostQoL_PCPlus_Selections.find { |s| s[:box] == sel_box && s[:index] == sel_index && s[:pid] == pkmn.personalID }
                                            if existing
                                                $GhostQoL_PCPlus_Selections.delete(existing)
                                            else
                                                $GhostQoL_PCPlus_Selections.push({:box => sel_box, :index => sel_index, :pid => pkmn.personalID})
                                            end
                                        end
                                    end
                                    @sprites["box"].refresh if @sprites["box"]
                                    pbRefresh
                                    return commands.index(_INTL("Cancel"))
                                elsif ret > move_idx + 1
                                    return ret - 1
                                else
                                    return ret
                                end
                            end
                        end
                    end
                end
                return ghost_qol_pcplus_pbShowCommands(msg, commands, index)
            end

            alias ghost_qol_pcplus_pbSelectBox pbSelectBox
            def pbSelectBox(party)
                selected = ghost_qol_pcplus_pbSelectBox(party)
                if GhostQoL.enabled?(:qol_pc_plus_v1) && selected && selected.is_a?(Array) && selected.length == 2
                    @ghost_qol_last_selected = [selected[0], selected[1]]

                    box = selected[0]
                    index = selected[1]
                    pokemon = (box >= 0 && index >= 0) ? @storage[box, index] : nil

                    if box >= 0 && index >= 0 && !pokemon && !@screen.pbHolding? && $GhostQoL_PCPlus_Selections && $GhostQoL_PCPlus_Selections.length > 0
                        commands = [
                            _INTL("Move selected here"),
                            _INTL("Withdraw selected"),
                            _INTL("Release selected"),
                            _INTL("Cancel")
                        ]
                        cmdMove = 0
                        cmdWithdraw = 1
                        cmdRelease = 2

                        command = pbShowCommands(_INTL("Bulk Actions ({1} selected)", $GhostQoL_PCPlus_Selections.length), commands)

                        if command == cmdMove
                            if box >= 0
                                moved = 0
                                $GhostQoL_PCPlus_Selections.dup.each do |sel|
                                    firstfree = @storage.pbFirstFreePos(box)
                                    break if firstfree < 0

                                    pkmn = @storage[sel[:box], sel[:index]]
                                    next if !pkmn || pkmn.personalID != sel[:pid]

                                    @storage[box, firstfree] = pkmn
                                    @storage.pbDelete(sel[:box], sel[:index])
                                    $GhostQoL_PCPlus_Selections.delete(sel)
                                    moved += 1
                                end
                                pbDisplay(_INTL("Moved {1} Pokémon.", moved))
                                pbHardRefresh
                            else
                                pbDisplay(_INTL("Cannot move multiple to Party this way."))
                            end
                            return pbSelectBox(party)
                        elsif command == cmdWithdraw
                            withdraw_count = 0
                            $GhostQoL_PCPlus_Selections.dup.each do |sel|
                                break if @storage.party_full?
                                pkmn = @storage[sel[:box], sel[:index]]
                                next if !pkmn || pkmn.personalID != sel[:pid]
                                @storage.party.push(pkmn)
                                @storage.pbDelete(sel[:box], sel[:index])
                                $GhostQoL_PCPlus_Selections.delete(sel)
                                withdraw_count += 1
                            end
                            pbDisplay(_INTL("Withdrew {1} Pokémon.", withdraw_count))
                            pbHardRefresh
                            return pbSelectBox(party)
                        elsif command == cmdRelease
                            if pbConfirmMessageSerious(_INTL("Release all {1} selected Pokémon?", $GhostQoL_PCPlus_Selections.length))
                                rel_count = 0
                                $GhostQoL_PCPlus_Selections.dup.each do |sel|
                                    pkmn = @storage[sel[:box], sel[:index]]
                                    next if !pkmn || pkmn.personalID != sel[:pid]
                                    next if pkmn.owner.name == "RENTAL" || pkmn.egg? || pkmn.mail
                                    @storage.pbDelete(sel[:box], sel[:index])
                                    $GhostQoL_PCPlus_Selections.delete(sel)
                                    rel_count += 1
                                end
                                pbDisplay(_INTL("Released {1} Pokémon.", rel_count))
                                pbHardRefresh
                            end
                            return pbSelectBox(party)
                        end
                        return pbSelectBox(party)
                    end
                end
                return selected
            end
        end

        class PokeBattle_Scene
            alias ghost_qol_pbFightMenu pbFightMenu
            def pbFightMenu(idxBattler, megaEvoPossible = false, &block)
                return ghost_qol_pbFightMenu(idxBattler, megaEvoPossible, &block) unless GhostQoL.enabled?(:qol_battle_move_info_v4)

                # --- GhostBattle_ClassicPlus Compatibility: Setup ---
                pbRefreshBattlerTones(idxBattler) if respond_to?(:pbRefreshBattlerTones)
                old_force = defined?($ghost_force_gui) ? $ghost_force_gui : nil
                $ghost_force_gui = 0 if $PokemonSystem.battlegui == 3
                # ----------------------------------------------------

                battler = @battle.battlers[idxBattler]
                cw = @sprites["fightWindow"]
                cw.battler = battler
                moveIndex = 0
                if battler.moves[@lastMove[idxBattler]] && battler.moves[@lastMove[idxBattler]].id
                    moveIndex = @lastMove[idxBattler]
                end
                cw.shiftMode = (@battle.pbCanShift?(idxBattler)) ? 1 : 0
                cw.setIndexAndMode(moveIndex, (megaEvoPossible) ? 1 : 0)

                # Move Info Overlay
                @sprites["qol_move_info"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
                @sprites["qol_move_info"].z = cw.z + 100
                @sprites["qol_move_info"].visible = false
                info_overlay = @sprites["qol_move_info"].bitmap

                update_qol_info = proc {
                    info_overlay.clear
                move = battler.moves[cw.index]

                # GhostBattle_ClassicPlus: Update effectiveness move for highlighting (Safely)
                if respond_to?(:pbRefreshBattlerTones)
                @ghostmod_effectiveness_move = move
                @ghostmod_active_battler_idx = battler.index
                pbRefreshBattlerTones(battler.index)
                end

                if move && @sprites["qol_move_info"].visible
                # Draw at a fixed position above the fight window
                # Fight window is Graphics.height-96.
                # Panel height is 135.
                py = Graphics.height - 96 - 135
                GhostQoL.draw_move_info(info_overlay, 0, py, Graphics.width, move.id, true, battler)
                end
                }

                needFullRefresh = true
                needRefresh = false
                loop_ret = nil
                loop do
                    if needFullRefresh
                        pbShowWindow(FIGHT_BOX)
                        pbSelectBattler(idxBattler)
                        needFullRefresh = false
                    end
                    if needRefresh
                        if megaEvoPossible
                            newMode = (@battle.pbRegisteredMegaEvolution?(idxBattler)) ? 2 : 1
                            cw.mode = newMode if newMode != cw.mode
                        end
                        needRefresh = false
                    end

                    oldIndex = cw.index
                    pbUpdate(cw)

                    # Update selected command (Restored navigation logic)
                    if Input.trigger?(Input::LEFT)
                        cw.index -= 1 if (cw.index & 1) == 1
                    elsif Input.trigger?(Input::RIGHT)
                        if battler.moves[cw.index + 1] && battler.moves[cw.index + 1].id
                            cw.index += 1 if (cw.index & 1) == 0
                        end
                    elsif Input.trigger?(Input::UP)
                        cw.index -= 2 if (cw.index & 2) == 2
                    elsif Input.trigger?(Input::DOWN)
                        if battler.moves[cw.index + 2] && battler.moves[cw.index + 2].id
                            cw.index += 2 if (cw.index & 2) == 0
                        end
                    end

                    if cw.index != oldIndex
                        pbPlayCursorSE
                        update_qol_info.call
                    end

                    if Input.trigger?(Input::USE)
                        pbPlayDecisionSE
                        ret = yield cw.index
                        if ret
                            loop_ret = ret
                            break
                        end
                        needFullRefresh = true
                        needRefresh = true
                    elsif Input.trigger?(Input::BACK)
                        pbPlayCancelSE
                        ret = yield -1
                        if ret
                            loop_ret = ret
                            break
                        end
                        needRefresh = true
                    elsif Input.trigger?(Input::ACTION)
                        # Toggle Move Info
                        @sprites["qol_move_info"].visible = !@sprites["qol_move_info"].visible
                        pbPlayDecisionSE
                        update_qol_info.call
                    elsif Input.trigger?(Input::SPECIAL)
                        if cw.shiftMode > 0
                            pbPlayDecisionSE
                            ret = yield -3
                            if ret
                                loop_ret = ret
                                break
                            end
                            needRefresh = true
                        end
                    end
                end

                # --- GhostBattle_ClassicPlus Compatibility: Cleanup ---
                @sprites["qol_move_info"].dispose if @sprites["qol_move_info"]
                @sprites.delete("qol_move_info")
                if respond_to?(:pbRefreshBattlerTones)
                    @ghostmod_effectiveness_move = nil
                    @ghostmod_active_battler_idx = -1
                    @sprites.each { |ki, si| si.pbHideEffectiveness if si.respond_to?(:pbHideEffectiveness) }
                    pbRefreshBattlerTones(-1)
                end
                $ghost_force_gui = old_force if defined?($ghost_force_gui)
                # -------------------------------------------------------

                @lastMove[idxBattler] = cw.index
                return loop_ret
            end
        end

        #===============================================================================
        # GhostQoL Global UI Helpers
        #===============================================================================
        module GhostQoL
            def self.draw_move_info(overlay, x, y, width, move_id, opaque = false, battler = nil)
                move = GameData::Move.get(move_id)

                base = Color.new(248, 248, 248)
                shadow = Color.new(104, 104, 104)
                label_base = Color.new(160, 160, 160)

                panel_x = x
                panel_width = width
                panel_y = y
                panel_height = 135

                # 1. Main Background
                bg_alpha = opaque ? 255 : 220
                overlay.fill_rect(panel_x, panel_y, panel_width, panel_height, Color.new(0, 0, 0, bg_alpha))
                # Border
                overlay.fill_rect(panel_x, panel_y, panel_width, 1, Color.new(255, 255, 255, 80))
                overlay.fill_rect(panel_x, panel_y + panel_height - 1, panel_width, 1, Color.new(255, 255, 255, 80))
                overlay.fill_rect(panel_x, panel_y, 1, panel_height, Color.new(255, 255, 255, 80))
                overlay.fill_rect(panel_x + panel_width - 1, panel_y, 1, panel_height, Color.new(255, 255, 255, 80))

                # 2. Header Row Background
                header_alpha = opaque ? 255 : 180
                overlay.fill_rect(panel_x + 1, panel_y + 1, panel_width - 2, 42, Color.new(60, 60, 70, header_alpha))
                overlay.fill_rect(panel_x + 1, panel_y + 42, panel_width - 2, 1, Color.new(255, 255, 255, 40))

                # 3. Types and Category Icons
                type_number = GameData::Type.get(move.type).id_number
                type_rect = Rect.new(0, type_number * 28, 64, 28)
                type_bitmap = AnimatedBitmap.new("Graphics/Pictures/types")
                overlay.blt(panel_x + 6, panel_y + 7, type_bitmap.bitmap, type_rect)
                type_bitmap.dispose

                cat_rect = Rect.new(0, move.category * 28, 64, 28)
                cat_bitmap = AnimatedBitmap.new("Graphics/Pictures/category")
                overlay.blt(panel_x + 72, panel_y + 7, cat_bitmap.bitmap, cat_rect)
                cat_bitmap.dispose

                # 4. Content Logic
                power = move.base_damage
                power = "---" if power == 0
                accuracy = move.accuracy
                accuracy = "---" if accuracy == 0
                accuracy = "#{accuracy}%" if accuracy.is_a?(Integer)

                # 5. Split Stat Boxes
                boxes = [
                    [panel_x + 140, 65, "POW", power.to_s],
                    [panel_x + 210, 65, "ACC", accuracy.to_s],
                    [panel_x + 280, 75, "PP", _INTL("{1}/{1}", move.total_pp)]
                ]

                if battler
                    atk_val = (move.category == 1) ? battler.spatk : battler.attack
                    atk_label = (move.category == 1) ? "S.ATK" : "ATK"
                    boxes << [panel_x + 360, 60, atk_label, atk_val.to_s]
                end

                pbSetSmallFont(overlay)
                boxes.each do |bx, bw, label, val|
                    # Draw box frame
                    if opaque
                        # Use solid colors to avoid alpha-channel "cutouts"
                        overlay.fill_rect(bx, panel_y + 4, bw, 36, Color.new(85, 85, 100))
                        overlay.fill_rect(bx, panel_y + 21, bw, 1, Color.new(120, 120, 135))
                    else
                        overlay.fill_rect(bx, panel_y + 4, bw, 36, Color.new(255, 255, 255, 30))
                        overlay.fill_rect(bx, panel_y + 21, bw, 1, Color.new(255, 255, 255, 50))
                    end

                    # Draw Label
                    pbDrawTextPositions(overlay, [
                                                  [label, bx + bw/2, panel_y - 5, 2, label_base, shadow]
                                                 ])

                    # Draw Value
                    pbDrawTextPositions(overlay, [
                                                  [val, bx + bw/2, panel_y + 11, 2, base, shadow]
                                                 ])
                end

                # 6. Description Area
                desc_y = panel_y + 48
                drawTextEx(overlay, panel_x + 10, desc_y, panel_width - 20, 3, move.description, base, shadow)
            end
        end

        # --- [GhostQoL] Shop Move Preview ---
        # Allows previewing move details for TMs and HMs in the mart.
        #-------------------------------------------------------------------------------
        class PokemonMart_Scene
            alias ghost_qol_pbChooseBuyItem pbChooseBuyItem
            def pbChooseBuyItem
                return ghost_qol_pbChooseBuyItem if !GhostQoL.enabled?(:qol_shop_move_preview_v2)

                itemwindow = @sprites["itemwindow"]
                @sprites["helpwindow"].visible = false

                # Create persistent overlay for automatic preview
                @sprites["move_preview_overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
                @sprites["move_preview_overlay"].z = @sprites["itemtextwindow"].z + 10
                preview_overlay = @sprites["move_preview_overlay"].bitmap

                # Helper to update the view state
                update_view = proc { |item|
                                     preview_overlay.clear
                                   if item && GameData::Item.get(item).is_machine?
                                   # Hide standard description text
                                   @sprites["itemtextwindow"].text = ""
                                   # Draw move info over the description area
                                   # Matches typical bottom message bar height/position
                                   move_id = GameData::Item.get(item).move
                                   GhostQoL.draw_move_info(preview_overlay, 0, Graphics.height - 135, Graphics.width, move_id, true)
                                   else
                                   # Restore standard description
                                   @sprites["itemtextwindow"].text = (item) ? @adapter.getDescription(item) : _INTL("Quit shopping.")
                                   end
                                   }

                pbActivateWindow(@sprites, "itemwindow") {
                    update_view.call(itemwindow.item)
                loop do
                Graphics.update
                Input.update
                olditem = itemwindow.item
                self.update

                if itemwindow.item != olditem
                @sprites["icon"].item = itemwindow.item
                update_view.call(itemwindow.item)
                end

                if Input.trigger?(Input::BACK)
                pbPlayCloseMenuSE
                @sprites["move_preview_overlay"].dispose
                @sprites.delete("move_preview_overlay")
                return nil
                elsif Input.trigger?(Input::USE)
                if itemwindow.index < @stock.length
                pbRefresh
                @sprites["move_preview_overlay"].dispose
                @sprites.delete("move_preview_overlay")
                return @stock[itemwindow.index]
                else
                @sprites["move_preview_overlay"].dispose
                @sprites.delete("move_preview_overlay")
                return nil
                end
                end
                end
                }
            end
        end

        # --- [GhostQoL] Slots AutoPlay ---
        # Enables an AutoPlay menu when playing slot machines.
        #-------------------------------------------------------------------------------
        class SlotMachineScene
            attr_accessor :ghost_autoplay_config # { wager: 1..3, spins: 10/25/50/100 }
            attr_accessor :ghost_autoplay_active
            attr_accessor :ghost_stakes          # 1, 5, or 10

            def pbPayout
                @replay = false
                payout = 0
                bonus = 0
                wonRow = []
                # Get reel pictures
                reel1 = @sprites["reel1"].showing
                reel2 = @sprites["reel2"].showing
                reel3 = @sprites["reel3"].showing
                combinations = [[reel1[1], reel2[1], reel3[1]], # Centre row
                                [reel1[0], reel2[0], reel3[0]], # Top row
                                [reel1[2], reel2[2], reel3[2]], # Bottom row
                                [reel1[0], reel2[1], reel3[2]], # Diagonal top left -> bottom right
                                [reel1[2], reel2[1], reel3[0]], # Diagonal bottom left -> top right
                                ]
                for i in 0...combinations.length
                    break if i >= 1 && @wager <= 1 # One coin = centre row only
                    break if i >= 3 && @wager <= 2 # Two coins = three rows only
                    wonRow[i] = true
                    case combinations[i]
                    when [1,1,1]   # Three Magnemites
                        payout += 8
                    when [2,2,2]   # Three Shellders
                        payout += 8
                    when [3,3,3]   # Three Pikachus
                        payout += 15
                    when [4,4,4]   # Three Psyducks
                        payout += 15
                    when [5,5,6], [5,6,5], [6,5,5], [6,6,5], [6,5,6], [5,6,6]   # 777 multi-colored
                        payout += 90
                        bonus = 1 if bonus < 1
                    when [5,5,5], [6,6,6]   # Red 777, blue 777
                        payout += 300
                        bonus = 2 if bonus < 2
                    when [7,7,7]   # Three replays
                        @replay = true
                    else
                        if combinations[i][0] == 0   # Left cherry
                            if combinations[i][1] == 0   # Centre cherry as well
                                payout += 4
                            else
                                payout += 2
                            end
                        else
                            wonRow[i] = false
                        end
                    end
                end

                # Apply Stakes Multiplier
                multiplier = @ghost_stakes || 1
                payout *= multiplier

                @sprites["payout"].score = payout
                frame = 0
                if payout > 0 || @replay
                    if bonus > 0
                        pbMEPlay("Slots big win")
                    else
                        pbMEPlay("Slots win")
                    end
                    # Show winning animation
                    timePerFrame = Graphics.frame_rate / 8
                    until frame == Graphics.frame_rate * 3
                        Graphics.update
                        Input.update
                        update
                        @sprites["window2"].bitmap.clear if @sprites["window2"].bitmap
                        @sprites["window1"].setBitmap(sprintf("Graphics/Pictures/Slot Machine/win"))
                        @sprites["window1"].src_rect.set(152 * ((frame / timePerFrame) % 4), 0, 152, 208)
                        if bonus > 0
                            @sprites["window2"].setBitmap(sprintf("Graphics/Pictures/Slot Machine/bonus"))
                            @sprites["window2"].src_rect.set(152 * (bonus - 1), 0, 152, 208)
                        end
                        @sprites["light1"].visible = true
                        @sprites["light1"].src_rect.set(0, 26 * ((frame / timePerFrame) % 4), 96, 26)
                        @sprites["light2"].visible = true
                        @sprites["light2"].src_rect.set(0, 26 * ((frame / timePerFrame) % 4), 96, 26)
                        for i in 1..5
                            if wonRow[i - 1]
                                @sprites["row#{i}"].visible = ((frame / timePerFrame) % 2) == 0
                            else
                                @sprites["row#{i}"].visible = false
                            end
                        end
                        frame += 1
                    end
                    @sprites["light1"].visible = false
                    @sprites["light2"].visible = false
                    @sprites["window1"].src_rect.set(0, 0, 152, 208)
                    # Pay out
                    loop do
                        break if @sprites["payout"].score <= 0
                        Graphics.update
                        Input.update
                        update
                        @sprites["payout"].score -= 1
                        @sprites["credit"].score += 1
                        if Input.trigger?(Input::USE) || @sprites["credit"].score == Settings::MAX_COINS
                            @sprites["credit"].score += @sprites["payout"].score
                            @sprites["payout"].score = 0
                        end
                    end
                    (Graphics.frame_rate / 2).times do
                        Graphics.update
                        Input.update
                        update
                    end
                else
                    # Show losing animation
                    timePerFrame = Graphics.frame_rate / 4
                    until frame == Graphics.frame_rate * 2
                        Graphics.update
                        Input.update
                        update
                        @sprites["window2"].bitmap.clear if @sprites["window2"].bitmap
                        @sprites["window1"].setBitmap(sprintf("Graphics/Pictures/Slot Machine/lose"))
                        @sprites["window1"].src_rect.set(152 * ((frame / timePerFrame) % 2), 0, 152, 208)
                        frame += 1
                    end
                end
                @wager = 0
            end

            def pbMain
                if @ghost_autoplay_active && @ghost_autoplay_config
                    ghost_qol_auto_pbMain
                else
                    ghost_qol_manual_pbMain
                end
            end

            def ghost_qol_manual_pbMain
                frame = 0
                insertFrameTime = Graphics.frame_rate * 4 / 10
                multiplier = @ghost_stakes || 1
                loop do
                    Graphics.update
                    Input.update
                    update
                    @sprites["window1"].bitmap.clear if @sprites["window1"].bitmap
                    @sprites["window2"].bitmap.clear if @sprites["window2"].bitmap
                    if @sprites["credit"].score == Settings::MAX_COINS
                        pbMessage(_INTL("You've got {1} Coins.", Settings::MAX_COINS.to_s_formatted))
                        break
                    elsif $Trainer.coins == 0 && @wager == 0 && !@gameRunning && !@gameEnd
                        pbMessage(_INTL("You've run out of Coins.\nGame over!"))
                        break
                    elsif @gameRunning
                        spinFrameTime = Graphics.frame_rate / 4
                        @sprites["window1"].setBitmap(sprintf("Graphics/Pictures/Slot Machine/stop"))
                        @sprites["window1"].src_rect.set(152 * ((frame / spinFrameTime) % 4), 0, 152, 208)
                        if Input.trigger?(Input::USE)
                            pbSEPlay("Slots stop")
                            if @sprites["reel1"].spinning
                                @sprites["reel1"].stopSpinning(@replay)
                                @sprites["button1"].visible = true
                            elsif @sprites["reel2"].spinning
                                @sprites["reel2"].stopSpinning(@replay)
                                @sprites["button2"].visible = true
                            elsif @sprites["reel3"].spinning
                                @sprites["reel3"].stopSpinning(@replay)
                                @sprites["button3"].visible = true
                            end
                        end
                        if !@sprites["reel3"].spinning
                            @gameEnd = true
                            @gameRunning = false
                        end
                    elsif @gameEnd
                        pbPayout
                        @sprites["button1"].visible = false
                        @sprites["button2"].visible = false
                        @sprites["button3"].visible = false
                        for i in 1..5
                            @sprites["row#{i}"].visible = false
                        end
                        @gameEnd = false
                    else
                        @sprites["window1"].setBitmap(sprintf("Graphics/Pictures/Slot Machine/insert"))
                        @sprites["window1"].src_rect.set(152 * ((frame / insertFrameTime) % 2), 0, 152, 208)
                        if @wager > 0
                            @sprites["window2"].setBitmap(sprintf("Graphics/Pictures/Slot Machine/press"))
                            @sprites["window2"].src_rect.set(152 * ((frame / insertFrameTime) % 2), 0, 152, 208)
                        end
                        if Input.trigger?(Input::DOWN) && @wager < 3 && @sprites["credit"].score >= multiplier
                            pbSEPlay("Slots coin")
                            @wager += 1
                            @sprites["credit"].score -= multiplier
                            if @wager >= 3
                                @sprites["row5"].visible = true
                                @sprites["row4"].visible = true
                            elsif @wager >= 2
                                @sprites["row3"].visible = true
                                @sprites["row2"].visible = true
                            elsif @wager >= 1
                                @sprites["row1"].visible = true
                            end
                        elsif @wager >= 3 || (@wager > 0 && @sprites["credit"].score < multiplier) ||
                                (Input.trigger?(Input::USE) && @wager > 0) || @replay
                            if @replay
                                @wager = 3
                                for i in 1..5
                                    @sprites["row#{i}"].visible = true
                                end
                            end
                            @sprites["reel1"].startSpinning
                            @sprites["reel2"].startSpinning
                            @sprites["reel3"].startSpinning
                            frame = 0
                            @gameRunning = true
                        elsif Input.trigger?(Input::BACK) && @wager == 0
                            break
                        end
                    end
                    frame = (frame + 1) % (Graphics.frame_rate * 4)
                end
                $Trainer.coins = @sprites["credit"].score
            end

            def ghost_qol_auto_pbMain
                frame = 0
                spinFrameTime   = Graphics.frame_rate / 4
                insertFrameTime = Graphics.frame_rate * 4 / 10

                spins_left = @ghost_autoplay_config[:spins]
                target_wager = @ghost_autoplay_config[:wager]
                starting_coins = @sprites["credit"].score

                # Create spin counter sprite
                @sprites["ghost_spin_counter"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
                @sprites["ghost_spin_counter"].z = 100000
                counter_overlay = @sprites["ghost_spin_counter"].bitmap
                pbSetSmallFont(counter_overlay)

                interrupt_flag = false

                loop do
                    Graphics.update
                    Input.update
                    update

                    # Detect interruption request
                    if !interrupt_flag && (Input.trigger?(Input::USE) || Input.trigger?(Input::BACK))
                        interrupt_flag = true
                    end

                    @sprites["window1"].bitmap.clear if @sprites["window1"].bitmap
                    @sprites["window2"].bitmap.clear if @sprites["window2"].bitmap

                    # Draw spin counter
                    counter_overlay.clear
                    counter_text = _INTL("Auto-Spins: {1}", spins_left)
                    pbDrawTextPositions(counter_overlay, [[counter_text, 176, 80, 2, Color.new(248, 248, 248), Color.new(64, 64, 64)]])

                    if @sprites["credit"].score == Settings::MAX_COINS
                        pbMessage(_INTL("You've got {1} Coins.", Settings::MAX_COINS.to_s_formatted))
                        break
                    elsif $Trainer.coins == 0 && @wager == 0 && !@gameRunning && !@gameEnd
                        pbMessage(_INTL("You've run out of Coins.\nGame over!"))
                        break
                    elsif @gameRunning   # Reels are spinning
                        @sprites["window1"].setBitmap(sprintf("Graphics/Pictures/Slot Machine/stop"))
                        @sprites["window1"].src_rect.set(152 * ((frame / spinFrameTime) % 4), 0, 152, 208)

                        # Auto-stop reels
                        if @sprites["reel1"].spinning && frame >= 20
                            pbSEPlay("Slots stop")
                            @sprites["reel1"].stopSpinning(@replay)
                            @sprites["button1"].visible = true
                        elsif @sprites["reel2"].spinning && frame >= 40
                            pbSEPlay("Slots stop")
                            @sprites["reel2"].stopSpinning(@replay)
                            @sprites["button2"].visible = true
                        elsif @sprites["reel3"].spinning && frame >= 60
                            pbSEPlay("Slots stop")
                            @sprites["reel3"].stopSpinning(@replay)
                            @sprites["button3"].visible = true
                        end

                        if !@sprites["reel3"].spinning
                            @gameEnd = true
                            @gameRunning = false
                        end
                    elsif @gameEnd   # Reels have been stopped
                        pbPayout
                        @sprites["button1"].visible = false
                        @sprites["button2"].visible = false
                        @sprites["button3"].visible = false
                        for i in 1..5
                            @sprites["row#{i}"].visible = false
                        end
                        @gameEnd = false
                        spins_left -= 1
                        if spins_left <= 0
                            break
                        elsif interrupt_flag
                            if pbMessage(_INTL("Cancel Auto-Play?"), [_INTL("Yes"), _INTL("No")], 1) == 0
                                break
                            else
                                interrupt_flag = false
                            end
                        end
                    else   # Awaiting coins for the next spin
                        @sprites["window1"].setBitmap(sprintf("Graphics/Pictures/Slot Machine/insert"))
                        @sprites["window1"].src_rect.set(152 * ((frame / insertFrameTime) % 2), 0, 152, 208)

                        if @wager > 0
                            @sprites["window2"].setBitmap(sprintf("Graphics/Pictures/Slot Machine/press"))
                            @sprites["window2"].src_rect.set(152 * ((frame / insertFrameTime) % 2), 0, 152, 208)
                        end

                        # Auto-wager
                        multiplier = @ghost_stakes || 1
                        if @wager < target_wager && @sprites["credit"].score >= multiplier
                            pbSEPlay("Slots coin")
                            @wager += 1
                            @sprites["credit"].score -= multiplier
                            # Update row visibility
                            if @wager >= 3
                                @sprites["row5"].visible = true
                                @sprites["row4"].visible = true
                            elsif @wager >= 2
                                @sprites["row3"].visible = true
                                @sprites["row2"].visible = true
                            elsif @wager >= 1
                                @sprites["row1"].visible = true
                            end
                        elsif @wager >= target_wager || (@wager > 0 && @sprites["credit"].score < multiplier) || @replay
                            if @replay
                                @wager = 3
                                for i in 1..5
                                    @sprites["row#{i}"].visible = true
                                end
                            end
                            @sprites["reel1"].startSpinning
                            @sprites["reel2"].startSpinning
                            @sprites["reel3"].startSpinning
                            frame = 0
                            @gameRunning = true
                        end
                    end
                    frame = (frame + 1) % (Graphics.frame_rate * 4)
                end
                $Trainer.coins = @sprites["credit"].score

                # Session Summary
                net_diff = @sprites["credit"].score - starting_coins
                if net_diff > 0
                    pbMessage(_INTL("Auto-session ended. You won {1} Coins!", net_diff.to_s_formatted))
                elsif net_diff < 0
                    pbMessage(_INTL("Auto-session ended. You lost {1} Coins.", (-net_diff).to_s_formatted))
                else
                    pbMessage(_INTL("Auto-session ended. No net change in Coins."))
                end
            end
        end

        alias ghost_qol_pbSlotMachine pbSlotMachine
        def pbSlotMachine(difficulty = 1)
            if !GhostQoL.enabled?(:qol_slots_autoplay_v2)
                ghost_qol_pbSlotMachine(difficulty)
                return
            end

            if GameData::Item.exists?(:COINCASE) && !$PokemonBag.pbHasItem?(:COINCASE)
                pbMessage(_INTL("It's a Slot Machine."))
                return
            elsif $Trainer.coins == 0
                pbMessage(_INTL("You don't have any Coins to play!"))
                return
            elsif $Trainer.coins == Settings::MAX_COINS
                pbMessage(_INTL("Your Coin Case is full!"))
                return
            end

            loop do
                cmd = pbMessage(_INTL("Would you like to play the slots?"),
                                [_INTL("Auto"), _INTL("Manual"), _INTL("Cancel")], 2)
                case cmd
                when 0 # Auto
                    wager_cmd = pbMessage(_INTL("How many reels you want to play?"),
                                          [_INTL("1 Reel"), _INTL("2 Reels"), _INTL("3 Reels")], 0)
                    next if wager_cmd < 0
                    wager = wager_cmd + 1

                    spins_cmd = pbMessage(_INTL("How many auto-spins to do?"),
                                          [_INTL("10 Spins"), _INTL("25 Spins"), _INTL("50 Spins"), _INTL("100 Spins")], 0)
                    next if spins_cmd < 0
                    spins = [10, 25, 50, 100][spins_cmd]

                    stakes_cmd = pbMessage(_INTL("Select Stakes:"),
                                           [_INTL("1x Stakes"), _INTL("5x Stakes"), _INTL("10x Stakes")], 0)
                    next if stakes_cmd < 0
                    stakes = [1, 5, 10][stakes_cmd]

                    pbFadeOutIn {
                        scene = SlotMachineScene.new
                    scene.ghost_autoplay_active = true
                    scene.ghost_autoplay_config = { wager: wager, spins: spins }
                    scene.ghost_stakes = stakes
                    screen = SlotMachine.new(scene)
                    screen.pbStartScreen(difficulty)
                    }
                when 1 # Manual
                    stakes_cmd = pbMessage(_INTL("Select Stakes:"),
                                           [_INTL("1x Stakes"), _INTL("5x Stakes"), _INTL("10x Stakes")], 0)
                    next if stakes_cmd < 0
                    stakes = [1, 5, 10][stakes_cmd]

                    pbFadeOutIn {
                        scene = SlotMachineScene.new
                    scene.ghost_stakes = stakes
                    screen = SlotMachine.new(scene)
                    screen.pbStartScreen(difficulty)
                    }
                    return
                else # Cancel or B button
                    return
                end
            end
        end

        # --- [GhostQoL] Intro Skip ---
        # Skips the intro cinematics and goes straight to the main menu.
        #-------------------------------------------------------------------------------
        class Scene_Intro
            alias ghost_qol_main main
            def main
                if GhostQoL.enabled?(:qol_skip_intro_v2)
                    Graphics.transition(0)
                    @skip = false
                    # Initializes load screen
                    sscene = PokemonLoad_Scene.new
                    sscreen = PokemonLoadScreen.new(sscene)

                    # Kuray Font Initialization logic (Safeguard for modded font settings)
                    if defined?($PokemonSystem) && $PokemonSystem
                        if !$PokemonSystem.kurayfonts
                            $PokemonSystem.kurayfonts = 0
                        elsif $PokemonSystem.kurayfonts == 1
                            MessageConfig.pbGetSystemFontSizeset(26)
                            MessageConfig.pbGetSmallFontSizeset(25)
                            MessageConfig.pbGetNarrowFontSizeset(26)
                            MessageConfig.pbSetSystemFontName("Power Red and Green")
                            MessageConfig.pbSetSmallFontName("Power Green Small")
                            MessageConfig.pbSetNarrowFontName("Power Green Small")
                        elsif $PokemonSystem.kurayfonts == 2
                            MessageConfig.pbGetSystemFontSizeset(29)
                            MessageConfig.pbGetSmallFontSizeset(25)
                            MessageConfig.pbGetNarrowFontSizeset(29)
                            MessageConfig.pbSetSystemFontName("Power Clear")
                            MessageConfig.pbSetSmallFontName("Power Clear")
                            MessageConfig.pbSetNarrowFontName("Power Clear")
                        elsif $PokemonSystem.kurayfonts == 3
                            MessageConfig.pbGetSystemFontSizeset(29)
                            MessageConfig.pbGetSmallFontSizeset(25)
                            MessageConfig.pbGetNarrowFontSizeset(29)
                            MessageConfig.pbSetSystemFontName("Power Red and Blue")
                            MessageConfig.pbSetSmallFontName("Power Red and Blue")
                            MessageConfig.pbSetNarrowFontName("Power Red and Blue")
                        end
                    end

                    sscreen.pbStartLoadScreen
                else
                    ghost_qol_main
                end
            end
        end
        # --- [GhostQoL] Battle Size Selector ---
        # Intercepts battle initiation to prompt for battle size.
        #-------------------------------------------------------------------------------
        module GhostQoL
            def self.pbGhostBattleSizePrompt(is_wild)
                # 1. Multiplayer Co-op Check
                # Skip prompt if we are already in a co-op battle or about to enter one with allies.
                if defined?(CoopBattleState) && CoopBattleState.in_coop_battle?
                    return "2v2"
                end
                # Check for pending invitation (relevant for non-initiators)
                if defined?(MultiplayerClient) && MultiplayerClient.respond_to?(:coop_battle_pending?) && MultiplayerClient.coop_battle_pending?
                    return "2v2"
                end
                # Check if we have nearby allies who will join our wild encounter (relevant for initiators)
                if is_wild && defined?(CoopWildHook) && CoopWildHook.respond_to?(:pick_nearby_allies)
                    if CoopWildHook.pick_nearby_allies(1).any?
                        return "2v2"
                    end
                end

                # 2. Toggle Check
                feature_key = is_wild ? :qol_battle_size_wild_v6 : :qol_battle_size_trainer_v6
                return nil unless self.enabled?(feature_key)

                # 3. Randomizer Check (Wild Battles Only)
                if is_wild
                    randomizer_setting = ModSettingsMenu.get(:qol_wild_battle_size_randomizer_v6) || 0
                    if randomizer_setting > 0 # 1 = 2v2, 2 = 3v3
                        max_size = randomizer_setting + 1 # 2 or 3
                        # Randomize between 1 and max_size
                        roll = rand(max_size) + 1
                        selected_size = "#{roll}v#{roll}"

                        # Apply the randomized size
                        case selected_size
                        when "1v1"
                            $PokemonSystem.force_double_wild = 0
                        when "2v2"
                            $PokemonSystem.force_double_wild = 1
                        when "3v3"
                            $PokemonSystem.force_double_wild = 2
                        end
                        return selected_size
                    end
                end

                # 4. Prompt User
                msg = is_wild ? "Choose wild battle size:" : "Choose trainer battle size:"
                commands = ["1v1", "2v2", "3v3"]
                # 1v1 is default top option.
                selection = pbMessage(msg, commands, 0)

                selected_size = case selection
            when 0 then "1v1"
            when 1 then "2v2"
            when 2 then "3v3"
            else "1v1"
            end

            # 5. Update PIF/KIF Settings
            # Wild setting: $PokemonSystem.force_double_wild (0, 1, 2)
            # Trainer setting: $game_variables[VAR_DEFAULT_BATTLE_TYPE] ([1,1], [2,2], [3,3])

            case selected_size
            when "1v1"
                $PokemonSystem.force_double_wild = 0
                $game_variables[VAR_DEFAULT_BATTLE_TYPE] = [1, 1] unless is_wild
            when "2v2"
                $PokemonSystem.force_double_wild = 1
                $game_variables[VAR_DEFAULT_BATTLE_TYPE] = [2, 2] unless is_wild
            when "3v3"
                $PokemonSystem.force_double_wild = 2
                $game_variables[VAR_DEFAULT_BATTLE_TYPE] = [3, 3] unless is_wild
            end

            return selected_size
        end
    end

    # Hook Wild Battles
    # We hook kurayEncounterInit because it's called exactly once per battle participant generation,
    # but ONLY after a battle is confirmed to start.
    # We also use a lock to ensure only one prompt per battle sequence.
    module GhostQoL
        @ghost_wild_prompt_lock = false
        def self.prompt_wild_battle
            return if @ghost_wild_prompt_lock
            @ghost_wild_prompt_lock = true
            self.pbGhostBattleSizePrompt(true)
        end
        def self.unlock_wild_prompt
            @ghost_wild_prompt_lock = false
        end
    end

    # kurayEncounterInit is a global hook from an optional "Kuray" encounter
    # mod that isn't defined anywhere in this build (no mod or base script
    # defines it -- confirmed by project-wide search) -- aliasing it
    # unconditionally raised NameError here and aborted the rest of this
    # file's load. Only hook it if it's actually present.
    if respond_to?(:kurayEncounterInit, true)
    alias ghost_qol_kurayEncounterInit kurayEncounterInit
    def kurayEncounterInit(encounter_type)
        GhostQoL.prompt_wild_battle
        return ghost_qol_kurayEncounterInit(encounter_type)
    end
    end

    # Reset the lock when the encounter sequence ends
    class PokemonTemp
        alias ghost_qol_encounterType_set encounterType=
                def encounterType=(value)
        GhostQoL.unlock_wild_prompt if value.nil?
        ghost_qol_encounterType_set(value)
    end
end

# Hook pbEncounter (Rock Smash, Headbutt, etc.)
alias ghost_qol_pbEncounter pbEncounter
def pbEncounter(enc_type)
    GhostQoL.prompt_wild_battle
    return ghost_qol_pbEncounter(enc_type)
end

# Hook pbWildBattle (Direct calls)
alias ghost_qol_pbWildBattle pbWildBattle
def pbWildBattle(species, level, outcomeVar=1, canRun=true, canLose=false)
    # Trigger prompt/randomizer
    GhostQoL.prompt_wild_battle

    # For direct single-battle calls, we just let it proceed.
    # Most direct calls are meant to be 1v1 unless forced by system flags
    # or subsequent logic in core.
    return ghost_qol_pbWildBattle(species, level, outcomeVar, canRun, canLose)
end

# Hook Trainer Battles
# We hook pbPrepareBattle which is called early in both pbWildBattleCore and pbTrainerBattleCore
# but we specifically want to prompt for trainers here if not already handled.
alias ghost_qol_pbPrepareBattle pbPrepareBattle
def pbPrepareBattle(battle)
    # Only prompt for trainer battles if it hasn't been set by rules
    # and if it's actually a trainer battle.
    if battle.opponent && $PokemonTemp.battleRules["size"].nil?
        selected = GhostQoL.pbGhostBattleSizePrompt(false)
        battle.setBattleMode(selected) if selected
    end
    ghost_qol_pbPrepareBattle(battle)
end

# --- [GhostQoL] Hotel Multi-sleep ---
# Custom menu for hotel stays to choose duration.
#-------------------------------------------------------------------------------
module GhostQoL
    def self.hotel_sleep_menu
        # Don't proceed if it's already a complex situation
        return if $game_temp.in_battle || $game_temp.in_menu

        options = [
            _INTL("6 hours"),
            _INTL("12 hours"),
            _INTL("24 hours"),
            _INTL("2 days"),
            _INTL("3 days"),
            _INTL("4 days"),
            _INTL("5 days"),
            _INTL("6 days"),
            _INTL("Cancel")
        ]

        # We ask the player how long they want to stay.
        # We assume the payment has already happened or is irrelevant for this mod.
        command = pbMessage(_INTL("How long would you like to stay?"), options, options.length)
        return if command == options.length - 1 || command == -1

        pbFadeOutIn {
            added_seconds = 0
        case command
        when 0 then added_seconds = 6 * 3600
        when 1 then added_seconds = 12 * 3600
        when 2 then added_seconds = 24 * 3600
        when 3 then added_seconds = 48 * 3600
        when 4 then added_seconds = 72 * 3600
        when 5 then added_seconds = 96 * 3600
        when 6 then added_seconds = 120 * 3600
        when 7 then added_seconds = 144 * 3600
        end

        # Use UnrealTime if available, otherwise fallback (if possible)
        if defined?(UnrealTime)
        UnrealTime.add_seconds(added_seconds)
        else
        # Fallback for systems without UnrealTime
        $PokemonGlobal.newFrameCount += added_seconds * Graphics.frame_rate if $PokemonGlobal.respond_to?(:newFrameCount=)
        end

        # Cure party
        $Trainer.party.each { |p| p.heal if p }

        # Optional: Visual/Audio feedback
        pbMEPlay("Hotel") if pbResolveAudioME("Hotel") rescue nil

        pbMessage(_INTL("You woke up feeling refreshed!"))
        }
    end
end

# Intercept Common Event 12 (Hotel Stay)
class Interpreter
    alias ghost_hotel_command_117 command_117
    def command_117
        # @parameters[0] is the common event ID
        if GhostQoL.enabled?(:qol_hotel_multi_sleep_v2) && @parameters[0] == 12
            GhostQoL.hotel_sleep_menu
            return true # Successfully handled
        end
        return ghost_hotel_command_117
    end
end

# --- [GhostQoL] EasyDisguise ---
# Intercepts the Outfit common event to provide a quick-swap option.
#-------------------------------------------------------------------------------
alias ghost_qol_original_pbCommonEvent pbCommonEvent
def pbCommonEvent(id)
    # COMMON_EVENT_OUTFIT is defined as 80 in Constants.rb
    outfit_ce_id = defined?(COMMON_EVENT_OUTFIT) ? COMMON_EVENT_OUTFIT : 80
    if id == outfit_ce_id && GhostQoL.enabled?(:qol_easy_disguise_v1) && GhostQoL.has_rocket_disguise?
        commands = [
            _INTL("Change Clothes"),
            GhostQoL.is_wearing_rocket_disguise? ? _INTL("Remove Disguise") : _INTL("Disguise"),
            _INTL("Cancel")
        ]
        choice = pbMessage(_INTL("What would you like to do?"), commands, 2)
        if choice == 0
            return ghost_qol_original_pbCommonEvent(id)
        elsif choice == 1
            GhostQoL.toggle_disguise
            return true
        end
        return false
    end
    return ghost_qol_original_pbCommonEvent(id)
end

# --- [GhostQoL] PocketWatch ---
# Adds a permanent UI to the top left showing time and day.
#-------------------------------------------------------------------------------
# Patch SpriteWindow to track active UI windows
class SpriteWindow
    alias ghost_qol_initialize initialize
    def initialize(*args)
        ghost_qol_initialize(*args)
        GhostQoL.add_window(self)
    end

    alias ghost_qol_dispose dispose
    def dispose
        GhostQoL.remove_window(self)
        ghost_qol_dispose
    end
end

# Global hook to refresh PocketWatch visibility regardless of paused scenes
module Input
    class << self
        alias ghost_qol_pocketwatch_update update
        def update
            ghost_qol_pocketwatch_update
            GhostQoL.refresh_pocketwatch
        end
    end
end

$ghost_qol_pocketwatch_window = nil

class Window_PocketWatch < Window_AdvancedTextPokemon
    def initialize
        super("")
        $ghost_qol_pocketwatch_window = self
        self.viewport = nil
        @last_time = nil
        @update_ticks = 0
        @last_update_frame = -1
        @last_disappear_time = Time.now - 10 # Long ago
        @visible_counter = 0
        @target_x = -300
        @current_x = -300
        self.windowskin = nil
        self.x = -300
        self.y = 8
        self.z = 999999
        self.lineHeight(22)
        self.startX = 0
        self.startY = 0
        self.endX = 0
        self.endY = 0
        update_text
    end

    def update_text
        now = pbGetTimeNow
        time_str = now.strftime("%I:%M%p").downcase
        # Remove leading zero if present
        time_str = time_str[1..-1] if time_str[0, 1] == "0"
        day_str = now.strftime("%a")

        # Using fs=14 for a slightly smaller, more compact look.
        new_text = "<fs=14>#{time_str} - #{day_str}</fs>"
        if new_text != @last_time
            @last_time = new_text
            self.text = new_text
            self.resizeToFit(new_text, Graphics.width)
        end
    end

    def refresh_visibility
        # Determine requested visibility
        is_map = $scene.is_a?(Scene_Map)
        in_battle = ($game_temp && $game_temp.respond_to?(:in_battle) && $game_temp.in_battle) || ($scene && $scene.class.to_s.include?("Battle"))
        in_msg = $game_temp.message_window_showing

        # Hide if not on map, in battle, or message is showing
        requested_visible = is_map && !in_battle && !in_msg && !GhostQoL.any_ui_visible?(self)

        # Hide if ANY UI window is active in the spriteset
        if requested_visible
            spriteset = $scene.spriteset rescue nil
            if spriteset && spriteset.respond_to?(:getAnimations)
                for sprite in spriteset.getAnimations
                    next if sprite == self
                    if sprite.is_a?(LocationWindow)
                        if !sprite.disposed?
                            requested_visible = false
                            break
                        end
                    elsif sprite.is_a?(Window)
                        if !sprite.disposed? && sprite.visible
                            requested_visible = false
                            break
                        end
                    end
                end
            end
        end

        # Handle stability counter and cooldown
        if requested_visible
            @visible_counter += 1
            # Only slide in if it's been stable for 30 frames AND 3s have passed since last disappearance
            if @visible_counter >= 30 && Time.now >= @last_disappear_time + 3
                @target_x = 8
            end
        else
            if @target_x != -310
                @last_disappear_time = Time.now
            end
            @target_x = -310
            @visible_counter = 0
        end
    end

    def update
        super
        return if @last_update_frame == Graphics.frame_count
        @last_update_frame = Graphics.frame_count

        refresh_visibility

        # Animate towards target x
        if @current_x != @target_x
            speed = 12
            if @current_x < @target_x
                @current_x = [@current_x + speed, @target_x].min
            else
                @current_x = [@current_x - speed, @target_x].max
            end
            self.x = @current_x
        end
        self.y = 8 if self.y != 8
        self.visible = (self.x > -300)

        @update_ticks += 1
        if @update_ticks >= 40 # approx 1 second
            @update_ticks = 0
            update_text
        end
    end

    def dispose
        $ghost_qol_pocketwatch_window = nil if $ghost_qol_pocketwatch_window == self
        self.viewport.dispose if self.viewport
        super
    end
end

class Scene_Map
    alias ghost_qol_pocketwatch_update update
    def update
        ghost_qol_pocketwatch_update
        if GhostQoL.enabled?(:qol_pocketwatch_v1)
            @ghost_qol_pocketwatch ||= Window_PocketWatch.new
            @ghost_qol_pocketwatch.update
        elsif @ghost_qol_pocketwatch
            @ghost_qol_pocketwatch.dispose
            @ghost_qol_pocketwatch = nil
        end
    end

    alias ghost_qol_pocketwatch_call_menu call_menu
    def call_menu
        ghost_qol_pocketwatch_call_menu
        # Instantly dispose any active location windows when menu closes
        current_spriteset = self.spriteset rescue nil
        if current_spriteset && current_spriteset.respond_to?(:getAnimations)
            for sprite in current_spriteset.getAnimations
                if sprite.is_a?(LocationWindow)
                    sprite.dispose
                end
            end
        end
    end

    alias ghost_qol_pocketwatch_dispose dispose
    def dispose
        @ghost_qol_pocketwatch.dispose if @ghost_qol_pocketwatch
        @ghost_qol_pocketwatch = nil
        ghost_qol_pocketwatch_dispose
    end

    alias ghost_qol_pocketwatch_updatemini updatemini
    def updatemini
        ghost_qol_pocketwatch_updatemini
        @ghost_qol_pocketwatch.update if @ghost_qol_pocketwatch
    end

    alias ghost_qol_pocketwatch_miniupdate miniupdate
    def miniupdate
        ghost_qol_pocketwatch_miniupdate
        @ghost_qol_pocketwatch.update if @ghost_qol_pocketwatch
    end
end

# Monkey-patch LocationWindow to keep it visible during menu
class LocationWindow
    alias ghost_qol_location_update update
    def update
        if $game_temp.in_menu && !@window.disposed?
            @window.update
            @window.y += 4 if @window.y < 0
            # Keep frames around the "fully visible" mark
            @frames = [ @frames, Graphics.frame_rate * 2 ].max
            return
        end
        ghost_qol_location_update
    end
end
