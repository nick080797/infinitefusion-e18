# Ghostbuddy Pokepets - Single Follower System
# Clean Fork: Debloated, repolished, and optimized.

class PokemonGlobalMetadata
  attr_writer :ghostbuddy_pet_colors
  attr_writer :ghostbuddy_active

  def ghostbuddy_pet_colors
    @ghostbuddy_pet_colors ||= {}
    return @ghostbuddy_pet_colors
  end

  def ghostbuddy_active
    @ghostbuddy_active = true if @ghostbuddy_active.nil?
    return @ghostbuddy_active
  end
end

class Game_Character
  attr_accessor :step_anime unless method_defined?(:step_anime=)
  attr_accessor :move_type unless method_defined?(:move_type=)
  attr_accessor :move_frequency unless method_defined?(:move_frequency=)
  attr_accessor :ghostbuddy_returning

  alias ghostbuddy_poke_moveto moveto unless method_defined?(:ghostbuddy_poke_moveto)
  def moveto(x, y)
    if @id == 9000 && defined?(PlayerHousing) && PlayerHousing.at_home?
      return if @move_type == 1
    end
    ghostbuddy_poke_moveto(x, y) rescue nil
  end


  attr_accessor :ghostbuddy_steps_remaining
  attr_accessor :ghostbuddy_target_furniture

  alias ghostbuddy_poke_move_random move_random unless method_defined?(:ghostbuddy_poke_move_random)
  def move_random
    if @id == 9000 && defined?(PlayerHousing) && PlayerHousing.at_home?
      if !@ghostbuddy_steps_remaining || @ghostbuddy_steps_remaining == 0
        @ghostbuddy_target_furniture = nil
        if rand(2) == 0
          @ghostbuddy_steps_remaining = 0
          return
        else
          action = rand(5)
          if action < 4
            @ghostbuddy_steps_remaining = action + 1
          else
            if PlayerHousing.respond_to?(:housing_data) && PlayerHousing.housing_data &&
               PlayerHousing.housing_data["furniture"] && !PlayerHousing.housing_data["furniture"].empty?
              f = PlayerHousing.housing_data["furniture"].sample
              @ghostbuddy_target_furniture = [f["x"], f["y"]]
              @ghostbuddy_steps_remaining = 15 # Timeout steps to reach it
            else
              @ghostbuddy_steps_remaining = rand(4) + 1
            end
          end
        end
      end
      
      @ghostbuddy_steps_remaining -= 1
      
      if @ghostbuddy_target_furniture
        tx = @ghostbuddy_target_furniture[0]
        ty = @ghostbuddy_target_furniture[1]
        dx = (@x - tx).abs
        dy = (@y - ty).abs
        
        if (dx == 1 && dy == 0) || (dy == 1 && dx == 0) || (dx == 0 && dy == 0)
          @ghostbuddy_steps_remaining = 0
          @ghostbuddy_target_furniture = nil
          if dx == 1
            @x < tx ? turn_right : turn_left
          elsif dy == 1
            @y < ty ? turn_down : turn_up
          end
          return
        end
        
        sx = @x - tx
        sy = @y - ty
        abs_sx = sx.abs
        abs_sy = sy.abs
        old_x = @x
        old_y = @y
        
        if abs_sx == abs_sy
          rand(2) == 0 ? abs_sx += 1 : abs_sy += 1
        end
        
        if abs_sx > abs_sy
          sx > 0 ? move_left : move_right
          if @x == old_x && @y == old_y && sy != 0
            sy > 0 ? move_up : move_down
          end
        else
          sy > 0 ? move_up : move_down
          if @x == old_x && @y == old_y && sx != 0
            sx > 0 ? move_left : move_right
          end
        end
        
        if @x == old_x && @y == old_y
          @ghostbuddy_target_furniture = nil
          @ghostbuddy_steps_remaining = 0
        end
        return
      end
    elsif @id == 9000
      # Overworld pet distance restriction: Max 4 tiles from player
      if (self.x - $game_player.x).abs + (self.y - $game_player.y).abs > 4
        move_toward_player
        return
      end
    end
    ghostbuddy_poke_move_random
  end

  alias ghostbuddy_poke_update_move_v2 update_move unless method_defined?(:ghostbuddy_poke_update_move_v2)
  def update_move
    ghostbuddy_poke_update_move_v2
    if !moving? && @ghostbuddy_steps_remaining && @ghostbuddy_steps_remaining > 0 && defined?(PlayerHousing) && PlayerHousing.at_home?
      move_random
    end
  end

  def ghostbuddy_hop
    @jump_peak = 10; @jump_distance = 0; @jump_count = 20
  end

  def ghostbuddy_fade_out
    20.times do
      self.set_opacity(@opacity - 13) if self.respond_to?(:set_opacity)
      Graphics.update
    end
  end

  attr_accessor :ghostbuddy_hue, :ghostbuddy_sat, :ghostbuddy_bri, :ghostbuddy_force, :ghostbuddy_shiny

  def ghostbuddy_hue; @ghostbuddy_hue || 0; end
  def ghostbuddy_sat; @ghostbuddy_sat || 0; end
  def ghostbuddy_bri; @ghostbuddy_bri || 0; end
  def ghostbuddy_force; @ghostbuddy_force || false; end
  def ghostbuddy_shiny; @ghostbuddy_shiny || false; end
end

          class Sprite_Character
            alias ghostbuddy_color_update update unless method_defined?(:ghostbuddy_color_update)
            def update
              if @character.is_a?(Game_Event) && @character.id == 9000
                self.tone = @ghostbuddy_native_tone.clone if @ghostbuddy_native_tone
              end

              ghostbuddy_color_update

              if @character.is_a?(Game_Event) && @character.id == 9000
                pkmn = GhostbuddyPokePets.get_active_pet
                if pkmn
                  key = pkmn.species.to_s
                  needs_update = !@character.instance_variable_defined?(:@ghostbuddy_hue)

                  if pkmn.species_data.id_number >= 1026 && !$PokemonGlobal.ghostbuddy_pet_colors.has_key?(key)
                    needs_update = true
                  end

                  GhostbuddyPokePets.apply_colors_to_event(@character, pkmn) if needs_update
                end

                if @character.ghostbuddy_hue == 0 && @character.ghostbuddy_sat == 0 && @character.ghostbuddy_bri == 0 && !@character.ghostbuddy_force
                  vanilla_bmp = RPG::Cache.character(@character.character_name, 0) rescue nil
                  if vanilla_bmp && self.bitmap != vanilla_bmp
                    old_rect = self.src_rect.clone
                    self.bitmap = vanilla_bmp
                    self.src_rect = old_rect
                    self.tone = Tone.new(0,0,0,0)
                  end
                else
                  @ghostbuddy_native_tone = self.tone.clone rescue Tone.new(0,0,0,0)

                  bmp = GhostbuddyPokePets.get_custom_bitmap(@character.character_name,
                                                             @character.ghostbuddy_hue, @character.ghostbuddy_sat, @character.ghostbuddy_force)
                  if bmp && self.bitmap != bmp
                    old_rect = self.src_rect.clone
                    self.bitmap = bmp
                    self.src_rect = old_rect
                  end

                  t = @ghostbuddy_native_tone.clone

                  if @character.ghostbuddy_sat < 0
                    intensity = (-@character.ghostbuddy_sat / 200.0)
                    intensity = 1.0 if intensity > 1.0
                    avg = (t.red + t.green + t.blue) / 3.0

                    t.red   += (avg - t.red)   * intensity
                    t.green += (avg - t.green) * intensity
                    t.blue  += (avg - t.blue)  * intensity
                    t.gray = [[t.gray + (-@character.ghostbuddy_sat * 1.275).to_i, 0].max, 255].min
                  end

                  bri = (@character.ghostbuddy_bri * 1.5).to_i
                  t.red   = [[t.red   + bri, -255].max, 255].min
                  t.green = [[t.green + bri, -255].max, 255].min
                  t.blue  = [[t.blue  + bri, -255].max, 255].min

                  self.tone = t
                end

                if @character.ghostbuddy_shiny
                  glow = (Math.sin(Graphics.frame_count * 0.1) * 30 + 50).to_i
                  self.tone.red   = [[self.tone.red   + glow, -255].max, 255].min
                  self.tone.green = [[self.tone.green + glow, -255].max, 255].min
                  self.tone.blue  = [[self.tone.blue  + glow, -255].max, 255].min
                end
              end
            end
          end

          class Game_Event
            # Standard engine movement handles visual smoothing efficiently.
            # Removed custom visual_rx/ry tracking to fix zipping glitches.
            
            alias ghostbuddy_set_starting set_starting unless method_defined?(:ghostbuddy_set_starting)
            def set_starting
              # Prevent DependentEvents.updateDependentEvents from freezing random moves
              if @id == 9000 && defined?(PlayerHousing) && PlayerHousing.at_home? && @move_type == 1
                return
              end
              ghostbuddy_set_starting
            end

            # Screen-space interpolation for seamless map transitions
            alias ghostbuddy_screen_x screen_x unless method_defined?(:ghostbuddy_screen_x)
            def screen_x
              base = ghostbuddy_screen_x
              if @id == 9000
                offset = GhostbuddyPokePets.smooth_offset_x rescue 0
                base += offset if offset && offset != 0
                
                if GhostbuddyPokePets.respond_to?(:is_large_sprite?) && GhostbuddyPokePets.is_large_sprite?(@character_name)
                  case @direction
                  when 4 then base += 32
                  when 6 then base -= 32
                  end
                end
              end
              return base
            end

            alias ghostbuddy_screen_y screen_y unless method_defined?(:ghostbuddy_screen_y)
            def screen_y
              base = ghostbuddy_screen_y
              if @id == 9000
                offset = GhostbuddyPokePets.smooth_offset_y rescue 0
                base += offset if offset && offset != 0
                
                if GhostbuddyPokePets.respond_to?(:is_large_sprite?) && GhostbuddyPokePets.is_large_sprite?(@character_name)
                  case @direction
                  when 8 then base += 32
                  when 2 then base -= 32
                  end
                end
              end
              return base
            end
          end

          class DependentEvents
            if method_defined?(:pbFollowEventAcrossMaps) && !method_defined?(:ghostbuddy_old_follow)
              alias ghostbuddy_old_follow pbFollowEventAcrossMaps
              def pbFollowEventAcrossMaps(leader, follower, instant = false, leaderIsTrueLeader = true)
                if follower.id == 9000
                  if defined?(PlayerHousing) && PlayerHousing.at_home?
                    return if follower.move_type == 1
                    return if GhostbuddyPokePets.respond_to?(:is_returning?) && GhostbuddyPokePets.is_returning?(follower)
                  end
                  
                  # Seamless Map Transition Smoothing:
                  # Capture the pet's current screen pixel position BEFORE the engine
                  # destroys the old event and creates a new one on the destination map.
                  old_screen_x = follower.screen_x rescue nil
                  old_screen_y = follower.screen_y rescue nil
                  old_map_id = follower.map ? follower.map.map_id : 0
                  
                  # Clear any existing offset so screen_x/y returns raw values for the old event
                  GhostbuddyPokePets.instance_variable_set(:@smooth_offset_x, 0)
                  GhostbuddyPokePets.instance_variable_set(:@smooth_offset_y, 0)
                  old_screen_x = follower.screen_x rescue nil
                  old_screen_y = follower.screen_y rescue nil
                  
                  ghostbuddy_old_follow(leader, follower, instant, leaderIsTrueLeader)
                  
                  # After the engine transition, find the new pet event and compute pixel offset
                  if old_screen_x && old_screen_y && !instant && $PokemonTemp && $PokemonTemp.dependentEvents
                    evs = $PokemonTemp.dependentEvents.instance_variable_get(:@realEvents) || []
                    pet = evs.find { |e| e && e.id == 9000 }
                    if pet && pet.map && pet.map.map_id != old_map_id
                      new_screen_x = pet.ghostbuddy_screen_x rescue pet.screen_x
                      new_screen_y = pet.ghostbuddy_screen_y rescue pet.screen_y
                      GhostbuddyPokePets.instance_variable_set(:@smooth_offset_x, old_screen_x - new_screen_x)
                      GhostbuddyPokePets.instance_variable_set(:@smooth_offset_y, old_screen_y - new_screen_y)
                    end
                  end
                  return
                end
                ghostbuddy_old_follow(leader, follower, instant, leaderIsTrueLeader)
              end
            end
          end

alias ghostbuddy_old_turn_toward_event pbTurnTowardEvent unless defined?(ghostbuddy_old_turn_toward_event)
def pbTurnTowardEvent(event, otherEvent)
  if event && event.is_a?(Game_Event) && event.id == 9000 && defined?(PlayerHousing) && PlayerHousing.at_home? && event.move_type == 1
    return
  end
  ghostbuddy_old_turn_toward_event(event, otherEvent)
end


module GhostbuddyPokePets
            @last_state_key = nil
            @last_hp = 0
            @idle_timer = 0
            @is_idling = false
            @returning_followers = []
            @custom_cache = {}
            @smooth_offset_x = 0
            @smooth_offset_y = 0

            def self.smooth_offset_x
              @smooth_offset_x || 0
            end

            def self.smooth_offset_y
              @smooth_offset_y || 0
            end

            # Gradually decay the screen-space offset each frame for smooth visual glide
            def self.decay_smooth_offset
              return if (@smooth_offset_x || 0) == 0 && (@smooth_offset_y || 0) == 0
              # Decay rate: move ~X% of remaining offset per frame for smooth exponential slide
              decay = ($game_player && $game_player.move_speed >= 4) ? 0.3 : 0.21
              @smooth_offset_x = (@smooth_offset_x * (1.0 - decay)).round
              @smooth_offset_y = (@smooth_offset_y * (1.0 - decay)).round
              # Snap to zero when close enough
              @smooth_offset_x = 0 if @smooth_offset_x.abs <= 1
              @smooth_offset_y = 0 if @smooth_offset_y.abs <= 1
            end

            def self.get_active_pet
              return nil if !$Trainer || !$Trainer.party
              return nil if $PokemonGlobal && !$PokemonGlobal.ghostbuddy_active
              $Trainer.party.find { |p| p && !p.egg? && p.hp > 0 }
            end

            def self.get_custom_bitmap(char_name, hue, sat, force = false)
              return nil if char_name == ""

              if hue == 0 && sat <= 0 && !force
                return RPG::Cache.character(char_name, 0) rescue nil
              end

              sat_vivid = [sat, 0].max
              key = "#{char_name}_H#{hue}_S#{sat_vivid}_F#{force ? 1 : 0}"
              return @custom_cache[key] if @custom_cache[key] && !@custom_cache[key].disposed?

              begin
                orig_bmp = RPG::Cache.character(char_name, 0)
                new_bmp = Bitmap.new(orig_bmp.width, orig_bmp.height)
                new_bmp.blt(0, 0, orig_bmp, orig_bmp.rect)

                if force
                  h_val = hue / 60.0
                  mv = h_val
                  while mv >= 2.0; mv -= 2.0; end
                  while mv < 0.0; mv += 2.0; end
                  x_val = (1.0 - (mv - 1.0).abs)
                  tr, tg, tb = 0, 0, 0
                  if    h_val < 1 then tr, tg, tb = 1.0, x_val, 0.0
                  elsif h_val < 2 then tr, tg, tb = x_val, 1.0, 0.0
                  elsif h_val < 3 then tr, tg, tb = 0.0, 1.0, x_val
                  elsif h_val < 4 then tr, tg, tb = 0.0, x_val, 1.0
                  elsif h_val < 5 then tr, tg, tb = x_val, 0.0, 1.0
                  else                 tr, tg, tb = 1.0, 0.0, x_val
                  end

                      for x in 0...new_bmp.width
                        for y in 0...new_bmp.height
                          c = new_bmp.get_pixel(x,y); next if c.alpha == 0
                          lum = (c.red * 0.299 + c.green * 0.587 + c.blue * 0.114)
                          new_bmp.set_pixel(x, y, Color.new((tr * lum).to_i, (tg * lum).to_i, (tb * lum).to_i, c.alpha.to_i))
                        end
                      end
                elsif hue != 0
                  new_bmp.hue_change(hue)
                end

                if sat_vivid > 0
                  factor = 1.0 + (sat_vivid / 100.0)
                  for x in 0...new_bmp.width
                    for y in 0...new_bmp.height
                      c = new_bmp.get_pixel(x, y)
                      next if c.alpha == 0
                      lum = (c.red * 0.299 + c.green * 0.587 + c.blue * 0.114)
                      nr = [[lum + (c.red - lum) * factor, 0].max, 255].min
                      ng = [[lum + (c.green - lum) * factor, 0].max, 255].min
                      nb = [[lum + (c.blue - lum) * factor, 0].max, 255].min
                      new_bmp.set_pixel(x, y, Color.new(nr.to_i, ng.to_i, nb.to_i, c.alpha.to_i))
                    end
                  end
                end

                @custom_cache[key] = new_bmp
                return new_bmp
              rescue
                return nil
              end
            end

                def self.get_prominent_hue(bitmap)
                  return nil if !bitmap || bitmap.disposed?
                  histogram = {}
                  step = (bitmap.width > 64) ? 4 : 2
                  for x in (0...bitmap.width).step(step)
                    for y in (0...bitmap.height).step(step)
                      c = bitmap.get_pixel(x,y); next if c.alpha < 128
                      max_c = [c.red, c.green, c.blue].max
                      min_c = [c.red, c.green, c.blue].min
                      sat = max_c - min_c
                      next if sat < 12

                      q_key = [c.red.to_i & 0xF0, c.green.to_i & 0xF0, c.blue.to_i & 0xF0]
                      histogram[q_key] ||= [0.0, 0.0, 0.0, 0.0]
                      weight = sat.to_f
                      histogram[q_key][0] += c.red * weight
                      histogram[q_key][1] += c.green * weight
                      histogram[q_key][2] += c.blue * weight
                      histogram[q_key][3] += weight
                    end
                  end

                  return nil if histogram.empty?
                  best_bucket = histogram.max_by{|k,v| v[3]}[1]

                  r_raw = best_bucket[0] / best_bucket[3]
                  g_raw = best_bucket[1] / best_bucket[3]
                  b_raw = best_bucket[2] / best_bucket[3]

                  r = r_raw / 255.0; g = g_raw / 255.0; b = b_raw / 255.0
                  max = [r, g, b].max; min = [r, g, b].min
                  delta = max - min
                  hue = 0.0
                  if delta > 0.0001
                    if    max == r then hue = 60.0 * (g - b) / delta
                    elsif max == g then hue = 60.0 * (b - r) / delta + 120.0
                    elsif max == b then hue = 60.0 * (r - g) / delta + 240.0
                    end
                  end

                  lum = (r_raw * 0.299 + g_raw * 0.587 + b_raw * 0.114) / 255.0
                  bri = ((lum - 0.5) * 200).to_i
                  bri = [[bri, -120].max, 120].min

                  return [hue.to_i % 360, bri]
                end

                def self.get_sprite_base_hue(char_name)
                  return 0 if char_name == ""
                  bmp = RPG::Cache.character(char_name, 0) rescue nil
                  return 0 if !bmp || bmp.disposed?
                  frame_w = bmp.width / 4; frame_h = bmp.height / 4
                  first_frame = Bitmap.new(frame_w, frame_h)
                  first_frame.blt(0, 0, bmp, Rect.new(0, 0, frame_w, frame_h))
                  res = self.get_prominent_hue(first_frame)
                  first_frame.dispose
                  return res ? res[0] : 0
                end

                def self.is_large_sprite?(char_name)
                  return false if char_name.nil? || char_name == ""
                  bmp = RPG::Cache.character(char_name, 0) rescue nil
                  return false if !bmp || bmp.disposed?
                  frame_w = bmp.width / 4
                  return frame_w >= 96
                end

                def self.get_behind_position(leader, char_name = "")
                  d = leader.direction
                  dx = 0; dy = 0
                  gap = 1
                  case d
                  when 2 then dy = -gap
                  when 8 then dy = gap
                  when 4 then dx = gap
                  when 6 then dx = -gap
                  end
                  return leader.x + dx, leader.y + dy, d
                end

                def self.is_returning?(event)
                  return false if !@returning_followers || !event
                  @returning_followers.any? { |e| e.id == event.id }
                end

                def self.get_pet_colors(pkmn)
                  return [0, 0, 0, false] if !pkmn || !$PokemonGlobal
                  key = pkmn.species.to_s
                  data = $PokemonGlobal.ghostbuddy_pet_colors[key] || [0, 0, 0, false]
                  data << false if data.length < 4
                  return data[0..3]
                end

                def self.save_pet_colors(pkmn, hue, sat, bri, force)
                  return if !pkmn || !$PokemonGlobal
                  key = pkmn.species.to_s
                  $PokemonGlobal.ghostbuddy_pet_colors[key] = [hue, sat, bri, force]
                end

                def self.apply_colors_to_event(event, pkmn)
                  return if !event || !pkmn
                  key = pkmn.species.to_s

                  if pkmn.species_data.id_number >= 1026 && !$PokemonGlobal.ghostbuddy_pet_colors.has_key?(key)
                    temp_icon = PokemonIconSprite.new(pkmn) rescue nil
                    if temp_icon && temp_icon.bitmap && !temp_icon.bitmap.disposed?
                      res = self.get_prominent_hue(temp_icon.bitmap)
                      if res
                        hue, bri = res
                        base_hue = self.get_sprite_base_hue(event.character_name)
                        shift_hue = (hue - base_hue) % 360
                        self.save_pet_colors(pkmn, shift_hue, 0, bri, false)
                      end
                    end
                    temp_icon.dispose if temp_icon
                  end

                  hue, sat, bri, force = self.get_pet_colors(pkmn)
                  event.ghostbuddy_hue = hue
                  event.ghostbuddy_sat = sat
                  event.ghostbuddy_bri = bri
                  event.ghostbuddy_force = force
                end

                def self.get_pokemon_char_name(pkmn)
                  return "" if !pkmn
                  display_id = pkmn.isFusion? ? (pkmn.species_data.body_pokemon.id_number rescue 0) : (pkmn.species_data.id_number rescue 0)
                  id_str = display_id.to_s
                  id_3 = sprintf("%03d", display_id.to_i) rescue id_str.to_s
                  
                  species_obj = pkmn.isFusion? ? (pkmn.species_data.body_pokemon rescue nil) : pkmn.species_data
                  species_str = species_obj.id.to_s.upcase rescue ""

                  possible_names = []
                  folders = ["Followers/", "Overworld/", ""]

                  if species_str && species_str != ""
                    if pkmn.shiny?
                      possible_names << species_str + "s" << species_str + "s_0" << species_str + "_s"
                    end
                    possible_names << species_str << species_str + "_0"
                  end

                  if pkmn.shiny?
                    possible_names << id_str.to_s + "s" << id_3 + "s" << id_str.to_s + "s_0" << id_3 + "s_0"
                  end
                  possible_names << id_str.to_s << id_3 << id_str.to_s + "_0" << id_3 + "_0"
                  folders.each do |f|
                    possible_names.each do |p|
                      path = f + p
                      return path if pbResolveBitmap("Graphics/Characters/" + path)
                    end
                  end
                  id_3
                end

                def self.update_followers(force = false)
                  pkmn = self.get_active_pet

                  if !pkmn
                    $PokemonGlobal.dependentEvents.reject! { |e| e[1] == 9000 } if $PokemonGlobal
                    if $PokemonTemp && $PokemonTemp.dependentEvents
                      old_events = $PokemonTemp.dependentEvents.instance_variable_get(:@realEvents) || []
                      old_events.reject! { |e| e && e.id == 9000 }
                      $PokemonTemp.dependentEvents.instance_variable_set(:@realEvents, old_events)
                      $PokemonTemp.dependentEvents.instance_eval { @lastUpdate += 1 }
                    end
                    return
                  end

                  current_hp = pkmn.hp
                  state_key = [pkmn.species, current_hp, pkmn.shiny?]

                  return if @last_state_key == state_key && !force
                  @last_state_key = state_key
                  @last_hp = current_hp

                  char_name = self.get_pokemon_char_name(pkmn)

                  old_event = nil
                  if $PokemonTemp && $PokemonTemp.dependentEvents
                    evs = $PokemonTemp.dependentEvents.instance_variable_get(:@realEvents) || []
                    old_event = evs.find { |e| e && e.id == 9000 }
                  end

                  if old_event
                    old_event.character_name = char_name
                    GhostbuddyPokePets.apply_colors_to_event(old_event, pkmn)

                    event_data = $PokemonGlobal.dependentEvents.find { |e| e[1] == 9000 }
                    event_data[6] = char_name if event_data
                    return
                  end

                  map_id = $game_map ? $game_map.map_id : 0
                  spawn_x, spawn_y, pet_dir = self.get_behind_position($game_player, char_name)
                  event_data = [map_id, 9000, map_id, spawn_x, spawn_y, pet_dir, char_name, 0, "GB_PET", nil]

                  $PokemonGlobal.dependentEvents << event_data

                  if $PokemonTemp && $PokemonTemp.dependentEvents
                    $PokemonTemp.dependentEvents.instance_eval do
                      @realEvents = [] if !@realEvents
                      @realEvents.push(createEvent(event_data))

                      pet = @realEvents.last
                      if pet && pet.id == 9000
                        pkmn = GhostbuddyPokePets.get_active_pet
                        GhostbuddyPokePets.apply_colors_to_event(pet, pkmn) if pkmn
                      end
                      @lastUpdate += 1
                    end
                  end

                end

                def self.manage_idle_state
                  return unless $game_player && $PokemonTemp && $PokemonTemp.dependentEvents

                  if defined?(PlayerHousing) && PlayerHousing.at_home?
                    evs = $PokemonTemp.dependentEvents.instance_variable_get(:@realEvents) || []
                    needs_roaming = evs.any? { |e| e && e.id == 9000 && e.move_type != 1 }
                    if !@is_idling || needs_roaming
                      @is_idling = true
                      self.set_follower_roaming(true)
                    end
                    @idle_timer = 0
                    return
                  end

                  if $game_player.moving? || Input.dir4 > 0
                    if @is_idling
                      @idle_timer = 0
                      @is_idling = false
                      self.set_follower_roaming(false)
                    end
                    @idle_timer = 0
                  else
                    @idle_timer += 1
                    threshold = Graphics.frame_rate * 10
                    if @idle_timer >= threshold && !@is_idling
                      @is_idling = true
                      self.set_follower_roaming(true)
                    end
                  end
                end

                def self.set_follower_roaming(active)
                  events = $PokemonTemp.dependentEvents.instance_variable_get(:@realEvents) || []
                  @returning_followers = [] if active
                  events.each do |event|
                    if event && event.id == 9000
                      if active
                        event.move_type = 1
                        is_home = (defined?(PlayerHousing) && PlayerHousing.at_home?)
                        event.move_frequency = is_home ? 5 : 4
                        event.move_speed = is_home ? 3 : 2
                        event.step_anime = true
                        event.through = false
                      else
                        # Don't teleport — let the pet run back to the player
                        event.move_type = 0
                        event.step_anime = true
                        event.walk_anime = true
                        event.move_speed = 5  # Fast run speed
                        event.move_frequency = 6
                        event.through = true
                        @pet_returning = true
                      end
                    end
                  end
                end

                # Each frame while @pet_returning, walk the pet toward the
                # player at fast speed. Once adjacent, restore normal follow
                # mode and let the engine's follower system take over.
                def self.update_pet_return
                  return unless @pet_returning
                  return unless $PokemonTemp && $PokemonTemp.dependentEvents && $game_player
                  evs = $PokemonTemp.dependentEvents.instance_variable_get(:@realEvents) || []
                  pet = evs.find { |e| e && e.id == 9000 }
                  unless pet
                    @pet_returning = false
                    return
                  end

                  dist = (pet.x - $game_player.x).abs + (pet.y - $game_player.y).abs
                  if dist <= 2
                    # Close enough — resume normal following
                    @pet_returning = false
                    pet.step_anime = false
                    pet.move_speed = $game_player.move_speed
                    pet.move_frequency = 6
                    return
                  end

                  # Walk toward player if not already mid-step
                  if !pet.moving?
                    sx = pet.x - $game_player.x
                    sy = pet.y - $game_player.y
                    if sx.abs > sy.abs
                      sx > 0 ? pet.move_left : pet.move_right
                    else
                      sy > 0 ? pet.move_up : pet.move_down
                    end
                  end
                end

                # Re-bind pet event's @map to the current live Game_Map.
                # After $MapFactory.setup() rebuilds maps, the pet's @map
                # becomes an orphaned object whose display_x/display_y no
                # longer update with the camera, causing visual 2x drift.
                def self.refresh_pet_map_reference
                  return unless $PokemonTemp && $PokemonTemp.dependentEvents && $game_map
                  evs = $PokemonTemp.dependentEvents.instance_variable_get(:@realEvents) || []
                  evs.each do |event|
                    next unless event && event.id == 9000
                    current_map = $MapFactory.getMap(event.map.map_id) rescue $game_map
                    if event.map != current_map
                      event.instance_variable_set(:@map, current_map)
                    end
                  end
                end

                def self.interact(event = nil)
                  pkmn = self.get_active_pet
                  return if !pkmn

                  party_index = $Trainer.party.index(pkmn)
                  pbPlayCry(pkmn)

                  commands = [_INTL("Stats (Summary)"), _INTL("Adjust Colors"), _INTL("Estimate Colors (Auto)")]

                  choice = pbMessage(_INTL("What would you like to do with {1}?", pkmn.name), commands, -1)
                  case choice
                  when 0
                    pbFadeOutIn { scene = PokemonSummary_Scene.new; screen = PokemonSummaryScreen.new(scene); screen.pbStartScreen($Trainer.party, party_index) }
                  when 1
                    self.open_color_menu(event, pkmn)
                  when 2
                    self.open_estimation_menu(event, pkmn)
                  end
                end

                def self.open_estimation_menu(event, pkmn)
                  return if !event || !pkmn
                  temp_icon = PokemonSprite.new
                  temp_icon.setPokemonBitmap(pkmn)
                  target_res = self.get_prominent_hue(temp_icon.bitmap) if temp_icon.bitmap
                  temp_icon.dispose
                  return pbMessage(_INTL("Could not estimate color for this Pokémon.")) if !target_res

                  target_hue, target_bri = target_res
                  base_hue = self.get_sprite_base_hue(event.character_name)
                  shift_hue = (target_hue - base_hue) % 360

                  cur_hue = shift_hue; cur_bri = target_bri; cur_force = false

                  commands = [
                    _INTL("Option A: Hue Shift (OFF)"),
                    _INTL("Option B: Force Paint (ON)"),
                    _INTL("Save and Exit"),
                    _INTL("Cancel")
                  ]

                  cmd_window = Window_CommandPokemon.new(commands)
                  cmd_window.width = 180
                  cmd_window.x = Graphics.width - cmd_window.width
                  cmd_window.y = 0; cmd_window.z = 99999

                  icon = PokemonSprite.new
                  icon.setPokemonBitmap(pkmn)
                  icon.x = 120; icon.y = 150; icon.z = 99999

                  apply = proc {
                    event.ghostbuddy_hue = cur_hue
                  event.ghostbuddy_bri = cur_bri
                  event.ghostbuddy_force = cur_force
                  event.ghostbuddy_sat = 0
                  }
                  apply.call

                  loop do
                    Graphics.update; Input.update; cmd_window.update; icon.update
                    $scene.spriteset.update if $scene.respond_to?(:spriteset) && $scene.spriteset

                    if Input.trigger?(Input::C)
                      case cmd_window.index
                      when 0
                        cur_hue = shift_hue; cur_force = false; apply.call; pbPlayDecisionSE() rescue nil
                      when 1
                        cur_hue = target_hue; cur_force = true; apply.call; pbPlayDecisionSE() rescue nil
                      when 2
                        self.save_pet_colors(pkmn, cur_hue, 0, cur_bri, cur_force)
                        pbMessage(_INTL("Settings saved for {1}!", pkmn.speciesName))
                        break
                      when 3
                        self.apply_colors_to_event(event, pkmn)
                        break
                      end
                    elsif Input.trigger?(Input::B)
                      self.apply_colors_to_event(event, pkmn)
                      break
                    end
                  end
                  cmd_window.dispose; icon.dispose
                end

                def self.open_color_menu(event, pkmn)
                  return if !event || !pkmn
                  hue, sat, bri, force = self.get_pet_colors(pkmn)

                  commands = [
                    _INTL("Hue: {1}", hue),
                    _INTL("Sat: {1}", sat),
                    _INTL("Bri: {1}", bri),
                    _INTL("Force Color: {1}", force ? "ON" : "OFF"),
                    _INTL("Reset to Default"),
                    _INTL("Save and Exit"),
                    _INTL("Cancel")
                  ]
                  cmd_window = Window_CommandPokemon.new(commands)
                  cmd_window.width = 200
                  cmd_window.x = Graphics.width - cmd_window.width
                  cmd_window.y = 0; cmd_window.z = 99999

                  icon = PokemonSprite.new
                  icon.setPokemonBitmap(pkmn)
                  icon.x = 120; icon.y = 150; icon.z = 99999

                  loop do
                    Graphics.update; Input.update; cmd_window.update; icon.update
                    $scene.spriteset.update if $scene.respond_to?(:spriteset) && $scene.spriteset

                    cmd_window.commands[0] = _INTL("Hue: {1}", hue)
                    cmd_window.commands[1] = _INTL("Sat: {1}", sat)
                    cmd_window.commands[2] = _INTL("Bri: {1}", bri)
                    cmd_window.commands[3] = _INTL("Force Color: {1}", force ? "ON" : "OFF")
                    cmd_window.refresh

                    if Input.repeat?(Input::RIGHT)
                      case cmd_window.index
                      when 0 then hue = (hue + 10) % 360
                      when 1 then sat = [sat + 10, 200].min
                      when 2 then bri = [bri + 10, 200].min
                      when 3 then force = !force
                      end
                      event.ghostbuddy_hue = hue; event.ghostbuddy_sat = sat; event.ghostbuddy_bri = bri; event.ghostbuddy_force = force
                      pbPlayCursorSE() rescue nil
                    elsif Input.repeat?(Input::LEFT)
                      case cmd_window.index
                      when 0 then hue = (hue - 10) % 360
                      when 1 then sat = [sat - 10, -200].max
                      when 2 then bri = [bri - 10, -200].max
                      when 3 then force = !force
                      end
                      event.ghostbuddy_hue = hue; event.ghostbuddy_sat = sat; event.ghostbuddy_bri = bri; event.ghostbuddy_force = force
                      pbPlayCursorSE() rescue nil
                    elsif Input.trigger?(Input::C)
                      case cmd_window.index
                      when 3
                        force = !force; event.ghostbuddy_force = force; pbPlayDecisionSE() rescue nil
                      when 4
                        hue = 0; sat = 0; bri = 0; force = false
                        event.ghostbuddy_hue = hue; event.ghostbuddy_sat = sat; event.ghostbuddy_bri = bri; event.ghostbuddy_force = force
                        pbPlayDecisionSE() rescue nil
                      when 5
                        pbPlayDecisionSE() rescue nil
                        self.save_pet_colors(pkmn, hue, sat, bri, force)
                        pbMessage(_INTL("Settings saved for {1}!", pkmn.speciesName))
                        break
                      when 6
                        pbPlayCancelSE() rescue nil
                        self.apply_colors_to_event(event, pkmn)
                        break
                      end
                    elsif Input.trigger?(Input::B)
                      pbPlayCancelSE() rescue nil
                      self.apply_colors_to_event(event, pkmn)
                      break
                    end
                  end
                  cmd_window.dispose; icon.dispose
                end
              end

              class Player
                alias ghostbuddy_heal_party heal_party unless method_defined?(:ghostbuddy_heal_party)
                def heal_party
                  ghostbuddy_heal_party
                  if defined?(GhostbuddyPokePets)
                    GhostbuddyPokePets.update_followers
                  end
                end
              end

              class Game_Player
                alias ghostbuddy_check_trigger_there check_event_trigger_there unless method_defined?(:ghostbuddy_check_trigger_there)
                def check_event_trigger_there(triggers)
                  result = ghostbuddy_check_trigger_there(triggers)
                  return result if result
                  return false if $game_system.map_interpreter.running?
                  new_x = @x + (@direction == 6 ? 1 : @direction == 4 ? -1 : 0)
                  new_y = @y + (@direction == 2 ? 1 : @direction == 8 ? -1 : 0)
                  events = $PokemonTemp.dependentEvents.instance_variable_get(:@realEvents) || []
                  events.each do |event|
                    if event && event.id == 9000
                      if event.at_coordinate?(new_x, new_y)
                        GhostbuddyPokePets.interact(event)
                        return true
                      end
                    end
                  end
                  return false
                end
              end

              Events.onMapUpdate += proc { |_sender, _e|
                if $Trainer && $Trainer.party && $game_map && $scene.is_a?(Scene_Map)
                  GhostbuddyPokePets.update_followers
                  GhostbuddyPokePets.manage_idle_state
                  GhostbuddyPokePets.decay_smooth_offset
                  GhostbuddyPokePets.update_pet_return
                end
              }

              Events.onMapSceneChange += proc { |_sender, _e|
                if $Trainer && $Trainer.party && $game_map
                  GhostbuddyPokePets.update_followers
                  GhostbuddyPokePets.manage_idle_state
                  # Fix stale map reference: after $MapFactory.setup rebuilds
                  # the map, the pet's @map still points to the old orphaned
                  # Game_Map object. Re-bind so screen_x/screen_y use the
                  # live display_x/display_y values.
                  GhostbuddyPokePets.refresh_pet_map_reference
                end
              }




# ============================================================================
# SECTION: UNINSTALL SANITIZATION
# ============================================================================
module GhostbuddyPokePets
  def self.sanitize_for_uninstall
    if $PokemonGlobal && $PokemonGlobal.dependentEvents
      $PokemonGlobal.dependentEvents.reject! { |e| e[1] == 9000 }
    end

    # 2. Purge from the active map temporary events array
    if $PokemonTemp && $PokemonTemp.dependentEvents
      old_events = $PokemonTemp.dependentEvents.instance_variable_get(:@realEvents) || []
      old_events.reject! { |e| e && e.id == 9000 }
      $PokemonTemp.dependentEvents.instance_variable_set(:@realEvents, old_events)
      $PokemonTemp.dependentEvents.instance_eval { @lastUpdate += 1 }
    end

    # 3. Scrub the injected global color configurations to clean the payload
    if defined?($PokemonGlobal) && $PokemonGlobal.respond_to?(:ghostbuddy_pet_colors=)
      $PokemonGlobal.ghostbuddy_pet_colors = {}
    end

    pbMessage(_INTL("Ghostbuddy data wiped. You can now save your game normally and delete the mod script safely."))
  end
end

# Bypass travel restrictions for PokéPets
class Game_Player
  alias ghostbuddy_pbHasDependentEvents? pbHasDependentEvents? unless method_defined?(:ghostbuddy_pbHasDependentEvents?)
  def pbHasDependentEvents?
    return false if !$PokemonGlobal || !$PokemonGlobal.dependentEvents
    return $PokemonGlobal.dependentEvents.any? { |e| e[1] != 9000 && e[8] != "GB_PET" }
  end
end

# Inject into the Mod Settings Menu
module GhostbuddyPokePets
  def self.register_settings
    return unless defined?(ModSettingsMenu)

    unless ModSettingsMenu.categories.any? { |c| c[:name] == "Ghost Settings" }
      ModSettingsMenu.categories << {
        name: "Ghost Settings",
        priority: 85,
        description: "Settings for GhostXYZ mods",
        collapsed: true
      }
    end

    ModSettingsMenu.register(:ghostbuddy_uninstall_prep, {
      name: "Buddy: Uninstall Prep",
      type: :button,
      category: "Ghost Settings",
      description: "Recalls your pet and wipes color settings to prepare for mod removal.",
      on_press: proc {
        GhostbuddyPokePets.sanitize_for_uninstall
      }
    })
  end
end

# Initialize if ModSettingsMenu is available. If not, queue for when it loads.
if defined?(ModSettingsMenu)
  GhostbuddyPokePets.register_settings
else
  $MOD_SETTINGS_PENDING_REGISTRATIONS ||= []
  $MOD_SETTINGS_PENDING_REGISTRATIONS << proc { GhostbuddyPokePets.register_settings }
end

# Follower Toggle Integration
class PokemonPartyScreen
  alias ghostbuddy_toggle_pbPokemonScreen pbPokemonScreen unless method_defined?(:ghostbuddy_toggle_pbPokemonScreen)

  def pbPokemonScreen
    # Maintain compatibility with WanderingTrainers scanning mode
    if defined?(WanderingTrainersMod) && WanderingTrainersMod.respond_to?(:is_scanning?) && WanderingTrainersMod.is_scanning?
      return ghostbuddy_toggle_pbPokemonScreen
    end

    @scene.pbStartScene(@party,
                        (@party.length > 1) ? _INTL("Choose a Pokémon.") : _INTL("Choose Pokémon or cancel."), nil)
    loop do
      @scene.pbSetHelpText((@party.length > 1) ? _INTL("Choose a Pokémon.") : _INTL("Choose Pokémon or cancel."))
      pkmnid = @scene.pbChoosePokemon(false, -1, 1)
      break if (pkmnid.is_a?(Numeric) && pkmnid < 0) || (pkmnid.is_a?(Array) && pkmnid[1] < 0)
      if pkmnid.is_a?(Array) && pkmnid[0] == 1 # Switch
        @scene.pbSetHelpText(_INTL("Move to where?"))
        oldpkmnid = pkmnid[1]
        pkmnid = @scene.pbChoosePokemon(true, -1, 2)
        if pkmnid >= 0 && pkmnid != oldpkmnid
          pbSwitch(oldpkmnid, pkmnid)
        end
        next
      end
      pkmn = @party[pkmnid]
      commands = []
      cmdSummary = -1
      cmdNickname = -1
      cmdDebug = -1
      cmdMoves = [-1] * pkmn.numMoves
      cmdSwitch = -1
      cmdMail = -1
      cmdItem = -1
      cmdHat = -1
      cmdFollow = -1

      # Build the commands
      commands[cmdSummary = commands.length] = _INTL("Summary")
      commands[cmdDebug = commands.length] = _INTL("Debug") if $DEBUG
      if !pkmn.egg?
        # Check for hidden moves and add any that were found
        pkmn.moves.each_with_index do |m, i|
          if [:MILKDRINK, :SOFTBOILED].include?(m.id) ||
            HiddenMoveHandlers.hasHandler(m.id)
            commands[cmdMoves[i] = commands.length] = [m.name, 1]
          end
        end
      end
      commands[cmdSwitch = commands.length] = _INTL("Switch") if @party.length > 1
      commands[cmdHat = commands.length] = _INTL("Hat") if canPutHatOnPokemon(pkmn)
      if !pkmn.egg?
        if pkmn.mail
          commands[cmdMail = commands.length] = _INTL("Mail")
        else
          commands[cmdItem = commands.length] = _INTL("Item")
        end
      end

      # PokéPet Follower Toggle (Slot 1 only)
      if pkmnid == 0 && pkmn && !pkmn.egg?
        if $PokemonGlobal.ghostbuddy_active
          commands[cmdFollow = commands.length] = _INTL("Stop Following")
        elsif pkmn.hp > 0
          commands[cmdFollow = commands.length] = _INTL("Follow Me")
        end
      end

      commands[cmdNickname = commands.length] = _INTL("Nickname") if !pkmn.egg?
      commands[commands.length] = _INTL("Cancel")
      command = @scene.pbShowCommands(_INTL("Do what with {1}?", pkmn.name), commands)
      havecommand = false
      cmdMoves.each_with_index do |cmd, i|
        next if cmd < 0 || cmd != command
        havecommand = true
        if [:MILKDRINK, :SOFTBOILED].include?(pkmn.moves[i].id)
          amt = [(pkmn.totalhp / 5).floor, 1].max
          if pkmn.hp <= amt
            pbDisplay(_INTL("Not enough HP..."))
            break
          end
          @scene.pbSetHelpText(_INTL("Use on which Pokémon?"))
          oldpkmnid = pkmnid
          loop do
            @scene.pbPreSelect(oldpkmnid)
            pkmnid = @scene.pbChoosePokemon(true, pkmnid)
            break if pkmnid < 0
            newpkmn = @party[pkmnid]
            movename = pkmn.moves[i].name
            if pkmnid == oldpkmnid
              pbDisplay(_INTL("{1} can't use {2} on itself!", pkmn.name, movename))
            elsif newpkmn.egg?
              pbDisplay(_INTL("{1} can't be used on an Egg!", movename))
            elsif newpkmn.hp == 0 || newpkmn.hp == newpkmn.totalhp
              pbDisplay(_INTL("{1} can't be used on that Pokémon.", movename))
            else
              pkmn.hp -= amt
              hpgain = pbItemRestoreHP(newpkmn, amt)
              @scene.pbDisplay(_INTL("{1}'s HP was restored by {2} points.", newpkmn.name, hpgain))
              pbRefresh
            end
            break if pkmn.hp <= amt
          end
          @scene.pbSelect(oldpkmnid)
          pbRefresh
          break
        elsif pbCanUseHiddenMove?(pkmn, pkmn.moves[i].id)
          if pbConfirmUseHiddenMove(pkmn, pkmn.moves[i].id)
            @scene.pbEndScene
            if pkmn.moves[i].id == :FLY || pkmn.moves[i].id == :TELEPORT
              ret = pbBetterRegionMap(-1, true, true)
              if ret
                $PokemonTemp.flydata = ret
                return [pkmn, pkmn.moves[i].id]
              end
              @scene.pbStartScene(@party,
                                  (@party.length > 1) ? _INTL("Choose a Pokémon.") : _INTL("Choose Pokémon or cancel."))
              break
            end
            return [pkmn, pkmn.moves[i].id]
          end
        end
      end
      next if havecommand
      if cmdSummary >= 0 && command == cmdSummary
        @scene.pbSummary(pkmnid) {
          @scene.pbSetHelpText((@party.length > 1) ? _INTL("Choose a Pokémon.") : _INTL("Choose Pokémon or cancel."))
        }
      elsif cmdHat >= 0 && command == cmdHat
        pbPokemonHat(pkmn)
      elsif cmdFollow >= 0 && command == cmdFollow
        $PokemonGlobal.ghostbuddy_active = !$PokemonGlobal.ghostbuddy_active
        GhostbuddyPokePets.update_followers(true)
        pbRefresh
      elsif cmdNickname >= 0 && command == cmdNickname
        pbPokemonRename(pkmn,pkmnid)
      elsif cmdDebug >= 0 && command == cmdDebug
        pbPokemonDebug(pkmn, pkmnid)
      elsif cmdSwitch >= 0 && command == cmdSwitch
        @scene.pbSetHelpText(_INTL("Move to where?"))
        oldpkmnid = pkmnid
        pkmnid = @scene.pbChoosePokemon(true)
        if pkmnid >= 0 && pkmnid != oldpkmnid
          pbSwitch(oldpkmnid, pkmnid)
        end
      elsif cmdMail >= 0 && command == cmdMail
        command = @scene.pbShowCommands(_INTL("Do what with the mail?"),
                                        [_INTL("Read"), _INTL("Take"), _INTL("Cancel")])
        case command
        when 0 # Read
          pbFadeOutIn {
            pbDisplayMail(pkmn.mail, pkmn)
            @scene.pbSetHelpText((@party.length > 1) ? _INTL("Choose a Pokémon.") : _INTL("Choose Pokémon or cancel."))
          }
        when 1 # Take
          if pbTakeItemFromPokemon(pkmn, self)
            pbRefreshSingle(pkmnid)
          end
        end
      elsif cmdItem >= 0 && command == cmdItem
        itemcommands = []
        cmdUseItem = -1
        cmdGiveItem = -1
        cmdTakeItem = -1
        cmdMoveItem = -1
        # Build the commands
        itemcommands[cmdUseItem = itemcommands.length] = _INTL("Use")
        itemcommands[cmdGiveItem = itemcommands.length] = _INTL("Give")
        itemcommands[cmdTakeItem = itemcommands.length] = _INTL("Take") if pkmn.hasItem?
        itemcommands[cmdMoveItem = itemcommands.length] = _INTL("Move") if pkmn.hasItem? &&
          !GameData::Item.get(pkmn.item).is_mail?
        itemcommands[itemcommands.length] = _INTL("Cancel")
        command = @scene.pbShowCommands(_INTL("Do what with an item?"), itemcommands)
        if cmdUseItem >= 0 && command == cmdUseItem # Use
          item = @scene.pbUseItem($PokemonBag, pkmn) {
            @scene.pbSetHelpText((@party.length > 1) ? _INTL("Choose a Pokémon.") : _INTL("Choose Pokémon or cancel."))
          }
          if item
            pbUseItemOnPokemon(item, pkmn, self)
            pbRefreshSingle(pkmnid)
          end
        elsif cmdGiveItem >= 0 && command == cmdGiveItem # Give
          item = @scene.pbChooseItem($PokemonBag) {
            @scene.pbSetHelpText((@party.length > 1) ? _INTL("Choose a Pokémon.") : _INTL("Choose Pokémon or cancel."))
          }
          if item
            if pbGiveItemToPokemon(item, pkmn, self, pkmnid)
              pbRefreshSingle(pkmnid)
            end
          end
        elsif cmdTakeItem >= 0 && command == cmdTakeItem # Take
          if pbTakeItemFromPokemon(pkmn, self)
            pbRefreshSingle(pkmnid)
          end
        elsif cmdMoveItem >= 0 && command == cmdMoveItem # Move
          item = pkmn.item
          itemname = item.name
          @scene.pbSetHelpText(_INTL("Move {1} to where?", itemname))
          oldpkmnid = pkmnid
          loop do
            @scene.pbPreSelect(oldpkmnid)
            pkmnid = @scene.pbChoosePokemon(true, pkmnid)
            break if pkmnid < 0
            newpkmn = @party[pkmnid]
            break if pkmnid == oldpkmnid
            if newpkmn.egg?
              pbDisplay(_INTL("Eggs can't hold items."))
            elsif !newpkmn.hasItem?
              newpkmn.item = item
              pkmn.item = nil
              @scene.pbClearSwitching
              pbRefresh
              pbDisplay(_INTL("{1} was given the {2} to hold.", newpkmn.name, itemname))
              break
            elsif GameData::Item.get(newpkmn.item).is_mail?
              pbDisplay(_INTL("{1}'s mail must be removed before giving it an item.", newpkmn.name))
            else
              newitem = newpkmn.item
              newitemname = newitem.name
              if newitem == :LEFTOVERS
                pbDisplay(_INTL("{1} is already holding some {2}.\1", newpkmn.name, newitemname))
              elsif newitemname.starts_with_vowel?
                pbDisplay(_INTL("{1} is already holding an {2}.\1", newpkmn.name, newitemname))
              else
                pbDisplay(_INTL("{1} is already holding a {2}.\1", newpkmn.name, newitemname))
              end
              if pbConfirm(_INTL("Would you like to switch the two items?"))
                newpkmn.item = item
                pkmn.item = newitem
                @scene.pbClearSwitching
                pbRefresh
                pbDisplay(_INTL("{1} was given the {2} to hold.", newpkmn.name, itemname))
                pbDisplay(_INTL("{1} was given the {2} to hold.", pkmn.name, newitemname))
                break
              end
            end
          end
        end
      end
    end
    @scene.pbEndScene
    return nil
  end
end