# ------------------------------------------------------------------------------
# Utilities adapted from rainefallUtils for Overworld Encounters
# ------------------------------------------------------------------------------

module RfSettings
  # disable this if you encounter any issues/incompatibilities involving map display positioning
  # as it overwrites Game_Player's screen position logic
  ENABLE_MAP_LOCKING = true
end

# ------------------------------------------------------------------------------
# Monkey-patch to fix missing chance_rolls in choose_wild_pokemon_for_map
# The base game has a bug where chance_rolls is used but not defined
# ------------------------------------------------------------------------------
class PokemonEncounters
  alias voe_original_choose_wild_pokemon_for_map choose_wild_pokemon_for_map unless method_defined?(:voe_original_choose_wild_pokemon_for_map)

  def choose_wild_pokemon_for_map(map_ID, enc_type, chance_rolls = 1)
      if !enc_type || !GameData::EncounterType.exists?(enc_type)
        raise ArgumentError.new(_INTL("Encounter type {1} does not exist", enc_type))
      end
      # GHOST/AFM: when querying the CURRENTLY loaded map, route through
      # choose_wild_pokemon instead of re-deriving encounter data ourselves.
      # choose_wild_pokemon is the method AnimeFusionQoL (hide-caught-species)
      # and KantoReloaded (Dynamic Wild Pokemon randomizer) actually alias -
      # this method used to bypass both silently by reimplementing selection
      # from scratch. Keep the standalone logic below only for the case of
      # querying a map that ISN'T the one currently loaded, since
      # choose_wild_pokemon always operates on the current map's tables.
      if $game_map && map_ID == $game_map.map_id
        return choose_wild_pokemon(enc_type, chance_rolls)
      end
      # Get the encounter table
      encounter_data = getEncounterMode().get(map_ID, $PokemonGlobal.encounter_version)

      return nil if !encounter_data
      enc_list = encounter_data.types[enc_type]
      if !@encounter_tables.nil? and !@encounter_tables.empty?
        enc_list = @encounter_tables[enc_type]
      end
      echoln enc_list
      return nil if !enc_list || enc_list.length == 0
      # Calculate the total probability value
      chance_total = 0
      enc_list.each { |a| chance_total += a[0] }
      # Choose a random entry in the encounter table based on entry probabilities
      rnd = 0
      chance_rolls.times do
        r = rand(chance_total)
        rnd = r if r > rnd   # Prefer rarer entries if rolling repeatedly
      end
      encounter = nil
      enc_list.each do |enc|
        rnd -= enc[0]
        next if rnd >= 0
        encounter = enc
        break
      end
      # Return [species, level]
      level = rand(encounter[2]..encounter[3])
      return [encounter[1], level]
    end

end

# Graphics functions
class Bitmap
  # INEFFICIENT, NOT RECOMMENDED FOR REALTIME USE
  def blur_rf(power, opacity = 128)
    power.times do |i|
      blur_fast(i, opacity / (i+1))
    end
  end
  
  # SLIGHTLY LESS INEFICCIENT
  def blur_fast(power, opacity = 128)
    blt(power * 2, 0, self, self.rect, opacity )
    blt(-power * 2, 0, self, self.rect, opacity)
    blt(0, power * 2, self, self.rect, opacity)
    blt(0, -power * 2, self, self.rect, opacity)
  end
end

class Sprite
  def create_outline_sprite(width = 2)
    return if !self.bitmap
    s = Sprite.new(self.viewport)
    s.x = self.x - width
    s.y = self.y - width
    s.z = self.z
    self.z += 1
    s.ox = self.ox
    s.oy = self.oy
    s.tone.set(255,255,255)
    s.bitmap = Bitmap.new(self.bitmap.width + width * 2, self.bitmap.height + width * 2)
    3.times do |y|
      3.times do |x|
        next if y == 1 && y == x
        s.bitmap.blt(x * width, y * width, self.bitmap, self.bitmap.rect)
      end
    end
    return s
  end
end

# Maths functions

module Math
  def self.lerp(a, b, t)
    return (1 - t) * a + t * b
  end
end

# Map scroll locking
if RfSettings::ENABLE_MAP_LOCKING
  class Game_Temp
    attr_accessor :map_locked
  end

  class Game_Player
    # Center player on-screen
    def update_screen_position(last_real_x, last_real_y)
      return if self.map.scrolling? || !(@moved_last_frame || @moved_this_frame) || $game_temp.map_locked
      self.map.display_x = @real_x - SCREEN_CENTER_X
      self.map.display_y = @real_y - SCREEN_CENTER_Y
    end
  end
end

# add characters to spriteset_map
class Spriteset_Map
  def add_character(event)
    @character_sprites.push(Sprite_Character.new(@@viewport1, event))
    return @character_sprites[-1]
  end

  def delete_character(event)
    @character_sprites.each_with_index do |e, i|
      if e.character.id == event.id
        e.dispose
        @character_sprites.delete(e)
      end
    end
  end
end

module Rf
  def self.wait_for_move_route
    loop do
        Graphics.update
        $scene.miniupdate
  
        move_route_forcing = false
  
        move_route_forcing = true if $game_player.move_route_forcing
        $game_map.events.each_value do |event|
            move_route_forcing = true if event.move_route_forcing
        end
        $game_temp.followers.each_follower do |event, follower|
            move_route_forcing = true if event.move_route_forcing
        end
  
        break if !move_route_forcing
    end
  end
  
  def self.create_event(map_id = -1)
    # get the current map/specified map if applicable
    map = $game_map
    map = $map_factory.getMapNoAdd(map_id) if map_id > 0
    # get a valid number to use as an event ID
    new_id = map.events.length + 1
    # ensure unique ID
    new_id += 1 while map.events.key?(new_id)

    # create new event
    ev = RPG::Event.new(0,0)
    ev.id = new_id
    yield ev
    # add event & event character sprite to map
    map.events[ev.id] = Game_Event.new(map.map_id, ev, map) # logical event
    begin  
      $scene.spriteset&.add_character(map.events[ev.id]) # event sprite
    rescue
      Kernel.puts "Attempted to create event before map spriteset initialised..."
    end
    return {
        :event => map.events[ev.id],
        :map_id => map.map_id
    }
  end
    
  def self.delete_event(ev)
      $scene.spriteset&.delete_character(ev[:event])
      return unless $map_factory
      map = $map_factory.getMapNoAdd(ev[:map_id])
      map&.events&.delete(ev[:event].id) if map
  end
end
# ------------------------------------------------------------------------------
# Shiny Sparkle Implementation (Script-based)
# ------------------------------------------------------------------------------

def pbVOESparkle(event)
  return unless event && $scene.is_a?(Scene_Map)
  echoln "[VOE] pbVOESparkle called for #{event.name} at (#{event.x}, #{event.y})" if VOESettings::LOG_SPAWNS
  # Create a set of sparkles
  12.times do |i|
    sparkle = VOE_Sparkle.new(event, i)
    VOESettings.add_sparkle(sparkle)
  end
end

class VOE_Sparkle
  def initialize(event, index)
    @event = event
    
    # Try multiple ways to get a valid viewport
    ss = $scene.spriteset
    @viewport = nil
    if ss
      @viewport = ss.instance_variable_get(:@viewport1)
      @viewport = ss.instance_variable_get(:@viewport) if !@viewport
      @viewport = ss.instance_variable_get(:@viewports)[1] if !@viewport && ss.instance_variable_get(:@viewports)
    end
    
    @sprite = Sprite.new(@viewport)
    
    # Try to find the shiny star graphic (160x192 sheet: 5 columns, 6 rows of 32x32)
    path = "Graphics/Pictures/shiny_anim"
    @sprite.bitmap = pbResolveBitmap(path) ? RPG::Cache.load_bitmap_path(path) : nil
    
    if !@sprite.bitmap
      echoln "[VOE] Sparkle bitmap NOT found at #{path}, using fallback" if VOESettings::LOG_SPAWNS && index == 0
      @sprite.bitmap = Bitmap.new(16, 16)
      @sprite.bitmap.fill_rect(0, 0, 16, 16, Color.new(255, 255, 255))
      @frame_width = 16
      @frame_height = 16
      @row_index = 0
    else
      echoln "[VOE] Sparkle bitmap LOADED (Size: #{@sprite.bitmap.width}x#{@sprite.bitmap.height})" if VOESettings::LOG_SPAWNS && index == 0
      
      # Check for 49x49 frames
      if @sprite.bitmap.width % 49 == 0 && @sprite.bitmap.height % 49 == 0
        @frame_width = 49
        @frame_height = 49
      else
        @frame_width = 32
        @frame_height = 32
      end
      
      # Auto-detect grid size
      @rows = @sprite.bitmap.height / @frame_height
      @cols = @sprite.bitmap.width / @frame_width
      @total_frames = @rows * @cols
      
      # For large animations (like 41 frames), we usually want to play the whole thing
      # For simple sheets (like the original), we pick a random row
      if @total_frames > 10
        @is_sequential = true
        @current_frame = rand(@total_frames) # Start at random point if looping, or 0 if once
      else
        @is_sequential = false
        @row_index = rand([@rows, 1].max)
        @num_frames = [@cols, 1].max
      end
    end
    
    if @is_sequential
      col = @current_frame % @cols
      row = @current_frame / @cols
      @sprite.src_rect = Rect.new(col * @frame_width, row * @frame_height, @frame_width, @frame_height)
    else
      @sprite.src_rect = Rect.new(0, @row_index * @frame_height, @frame_width, @frame_height)
    end

    @sprite.ox = @frame_width / 2
    @sprite.oy = @frame_height / 2
    @sprite.z = 999
    
    # Initial position
    angle = (index * 30 + rand(20)) * Math::PI / 180
    dist = rand(8..16)
    @offset_x = Math.cos(angle) * dist
    @offset_y = Math.sin(angle) * dist
    
    @sprite.x = safe_sprite_coord(@event.screen_x + @offset_x, 0)
    @sprite.y = safe_sprite_coord(@event.screen_y - 16 + @offset_y, 0)
    
    if @is_sequential
      # Ensure lifetime is at least one full loop + a bit more
      # Frame speed is 2, so total time = total_frames * 2
      min_lifetime = @total_frames * 2
      @timer = min_lifetime + rand(20)
    else
      @timer = 50 + rand(20)
    end

    @max_timer = @timer
    @sprite.zoom_x = 1.0 # 49px is big enough, no need to zoom
    @sprite.zoom_y = 1.0
    @velocity_x = (rand(40) - 20) / 10.0
    @velocity_y = (rand(40) - 20) / 10.0
    
    @frame_index = 0
    @frame_timer = 0
  end

  def update
    return true if disposed?
    @timer -= 1
    if @timer <= 0
      dispose
      return true
    end
    
    # Animation
    @frame_timer += 1
    if @frame_timer >= 2 # Faster update for smooth 41-frame animation
      if @is_sequential
        @current_frame = (@current_frame + 1) % @total_frames
        col = @current_frame % @cols
        row = @current_frame / @cols
        @sprite.src_rect.set(col * @frame_width, row * @frame_height, @frame_width, @frame_height)
      else
        @frame_index = (@frame_index + 1) % (@num_frames || 1)
        @sprite.src_rect.set(@frame_index * @frame_width, @row_index * @frame_height, @frame_width, @frame_height)
      end
      @frame_timer = 0
    end
    
    # Position
    if @event && !@event.disposed?
      @sprite.x = safe_sprite_coord(@event.screen_x + @offset_x, @sprite.x)
      @sprite.y = safe_sprite_coord(@event.screen_y - 16 + @offset_y, @sprite.y)
    else
      @sprite.x = safe_sprite_coord(@sprite.x + @velocity_x, @sprite.x)
      @sprite.y = safe_sprite_coord(@sprite.y + @velocity_y, @sprite.y)
    end
    
    @offset_x += @velocity_x
    @offset_y += @velocity_y
    
    # Effects
    @sprite.opacity = (@timer.to_f / @max_timer) * 255
    scale = 0.5 + (@timer.to_f / @max_timer) * 1.0
    @sprite.zoom_x = scale
    @sprite.zoom_y = scale
    
    return false
  end

  private

  def safe_sprite_coord(value, fallback = 0)
    return fallback unless value.is_a?(Numeric)
    return fallback if value.is_a?(Float) && (value.nan? || (value.respond_to?(:finite?) && !value.finite?))
    return value.round
  rescue
    return fallback
  end

  def dispose
    @sprite.dispose if @sprite && !@sprite.disposed?
  end

  def disposed?
    return !@sprite || @sprite.disposed?
  end
end
