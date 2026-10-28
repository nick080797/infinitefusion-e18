#===============================================================================
# ** Game_Switches
#-------------------------------------------------------------------------------
#  This class handles switches. It's a wrapper for the built-in class "Array."
#  Refer to "$game_switches" for the instance of this class.
#===============================================================================
class Game_Switches
  #-----------------------------------------------------------------------------
  # * Object Initialization
  #-----------------------------------------------------------------------------
  def initialize
    @data = []
  end
  #-----------------------------------------------------------------------------
  # * Get Switch
  #     switch_id : switch ID
  #-----------------------------------------------------------------------------
  def [](switch_id)
    return @data[switch_id] if switch_id <= 1000000 && @data[switch_id] != nil
    return false
  end
  #-----------------------------------------------------------------------------
  # * Set Switch
  #     switch_id : switch ID
  #     value     : ON (true) / OFF (false)
  #-----------------------------------------------------------------------------
  def []=(switch_id, value)
    # NOTE: cap raised from 5000 to 1000000 (2026-09-04) -- Mods/PIF2Port and
    # Mods/MultiverseHub remap ported games' own switch ids by adding a flat
    # +50000 offset (PIF2PortSettings::SWITCH_OFFSET) to avoid colliding with
    # the host's own ~1201 real switches. The old 5000 cap silently dropped
    # every one of those remapped writes/reads (id > 5000), which was the
    # real cause of e.g. the PIF2 Truck intro cutscene visibly playing but
    # never actually unlocking its exit doors -- the switch it set was
    # silently discarded by this cap, not a remapping or event-logic bug.
    @data[switch_id] = value if switch_id <= 1000000
  end
end
