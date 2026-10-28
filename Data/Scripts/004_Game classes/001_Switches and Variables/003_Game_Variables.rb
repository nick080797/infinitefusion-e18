#===============================================================================
# ** Game_Variables
#-------------------------------------------------------------------------------
#  This class handles variables. It's a wrapper for the built-in class "Array."
#  Refer to "$game_variables" for the instance of this class.
#===============================================================================
class Game_Variables
  #-----------------------------------------------------------------------------
  # * Object Initialization
  #-----------------------------------------------------------------------------
  def initialize
    @data = []
  end
  #-----------------------------------------------------------------------------
  # * Get Variable
  #     variable_id : variable ID
  #-----------------------------------------------------------------------------
  def [](variable_id)
    return @data[variable_id] if variable_id <= 1000000 && !@data[variable_id].nil?
    return 0
  end
  #-----------------------------------------------------------------------------
  # * Set Variable
  #     variable_id : variable ID
  #     value       : the variable's value
  #-----------------------------------------------------------------------------
  def []=(variable_id, value)
    # NOTE: cap raised from 5000 to 1000000 (2026-09-04) -- see matching note
    # in Game_Switches; Mods/PIF2Port remaps ported variable ids by +50000
    # (PIF2PortSettings::VARIABLE_OFFSET), which the old cap silently dropped.
    @data[variable_id] = value if variable_id <= 1000000
  end
end
