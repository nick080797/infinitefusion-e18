#===============================================================================
# VOE — Mod Settings Registration
# Registers all configurable settings with ModSettingsMenu (if available).
#===============================================================================

if defined?(ModSettingsMenu)
  category = "Encounters"
  
  ModSettingsMenu.register(:voe_disable_settings, {
    :name => "Disable Encounters",
    :type => :toggle,
    :default => 0, # False (Enabled)
    :description => "Disable overworld encounters.",
    :category => category
  })

  ModSettingsMenu.register(:voe_log_spawns, {
    :name => "Log Spawns",
    :type => :toggle,
    :default => 0,
    :description => "Log encounter spawns to console.",
    :category => category
  })
  
  ModSettingsMenu.register(:voe_shiny_rate, {
    :name => "Shiny Rate (1/X)",
    :type => :number,
    :min => 1,
    :max => 65536,
    :default => 8192,
    :description => "Chance denominator for shiny spawns.",
    :category => category
  })
  
  ModSettingsMenu.register(:voe_max_distance, {
    :name => "Spawn Distance",
    :type => :slider,
    :min => 1,
    :max => 20,
    :default => 12,
    :description => "Maximum distance from player before despawn.",
    :category => category
  })
  
  ModSettingsMenu.register(:voe_delete_events, {
    :name => "Despawn Far Events",
    :type => :toggle,
    :default => 1, # True
    :description => "Remove events that are too far away.",
    :category => category
  })
  
  ModSettingsMenu.register(:voe_brt_shiny, {
    :name => "Bright Shinies",
    :type => :toggle,
    :default => 1, # True
    :description => "Shinies are unaffected by day/night tone.",
    :category => category
  })

  ModSettingsMenu.register(:voe_colorful_text, {
    :name => "Colorful Names",
    :type => :toggle,
    :default => 1,
    :description => "Use gender colors for Pokemon names.",
    :category => category
  })

  ModSettingsMenu.register(:voe_water_surf_only, {
    :name => "Water Spawns (Surf)",
    :type => :toggle,
    :default => 1,
    :description => "Only spawn water Pokemon when surfing.",
    :category => category
  })
  
  ModSettingsMenu.register(:voe_spawn_anim, {
    :name => "Spawn Animation ID",
    :type => :number,
    :min => 0,
    :max => 999,
    :default => 2,
    :description => "Animation ID for spawning Pokemon.",
    :category => category
  })
  
  ModSettingsMenu.register(:voe_shiny_anim, {
    :name => "Shiny Animation ID",
    :type => :number,
    :min => 0,
    :max => 999,
    :default => 53,
    :description => "Animation ID for shiny Pokemon.",
    :category => category
  })

  ModSettingsMenu.register(:voe_delete_shiny, {
    :name => "Despawn Shinies",
    :type => :toggle,
    :default => 0,
    :description => "Allow shiny Pokemon to despawn.",
    :category => category
  })
  
  ModSettingsMenu.register(:voe_diff_enc, {
    :name => "Different Encounters",
    :type => :toggle,
    :default => 0,
    :description => "Use different encounter tables.",
    :category => category
  })
  
  ModSettingsMenu.register(:voe_enc_table, {
    :name => "Encounter Table ID",
    :type => :number,
    :min => 0,
    :max => 10,
    :default => 1,
    :description => "Encounter table index to use.",
    :category => category
  })

  ModSettingsMenu.register(:voe_max_encounters, {
    :name => "Max Encounters",
    :type => :slider,
    :min => 1,
    :max => 20,
    :default => 5,
    :description => "Maximum Pokemon spawned on each map.",
    :category => category
  })

  ModSettingsMenu.register(:voe_fusion_encounters, {
    :name => "Fusion Encounters",
    :type => :toggle,
    :default => 1,
    :description => "Enable wild fusion encounters.",
    :category => category
  })

  ModSettingsMenu.register(:voe_fusion_rate, {
    :name => "Fusion Rate (1/X)",
    :type => :number,
    :min => 1,
    :max => 100,
    :default => 10,
    :description => "Chance for encounter to be a fusion.",
    :category => category
  })

  ModSettingsMenu.register(:voe_horde_battles, {
    :name => "Horde Battles (2v1)",
    :type => :toggle,
    :default => 1,
    :description => "Nearby encounters team up against you.",
    :category => category
  })

  ModSettingsMenu.register(:voe_horde_distance, {
    :name => "Horde Distance",
    :type => :slider,
    :min => 1,
    :max => 5,
    :default => 2,
    :description => "Max tiles apart for horde battle.",
    :category => category
  })

  ModSettingsMenu.register(:voe_spawn_on_load, {
    :name => "Spawn on Map Load",
    :type => :toggle,
    :default => 0,
    :description => "Spawn multiple encounters immediately when entering a map.",
    :category => category
  })

  ModSettingsMenu.register(:voe_initial_spawn_count, {
    :name => "Initial Spawn Count",
    :type => :slider,
    :min => 1,
    :max => 15,
    :default => 6,
    :description => "Number of encounters to spawn when entering a map (if enabled).",
    :category => category
  })

  # =====================
  # OUTBREAK SETTINGS
  # =====================
  ModSettingsMenu.register(:voe_outbreak_enabled, {
    :name => "Outbreak Events",
    :type => :toggle,
    :default => 1,
    :description => "Enable random outbreak events on maps.",
    :category => category
  })

  ModSettingsMenu.register(:voe_outbreak_duration, {
    :name => "Outbreak Duration",
    :type => :enum,
    :values => ["5 Minutes", "10 Minutes", "15 Minutes"],
    :default => 1,
    :description => "How long outbreak events last.",
    :category => category
  })

  ModSettingsMenu.register(:voe_outbreak_type, {
    :name => "Outbreak Variety",
    :type => :enum,
    :values => ["Mixed Species", "Same Species"],
    :default => 0,
    :description => "Pokemon variety during outbreaks.",
    :category => category
  })

  ModSettingsMenu.register(:voe_outbreak_shiny_mult, {
    :name => "Outbreak Shiny Rate",
    :type => :slider,
    :min => 1,
    :max => 10,
    :default => 1,
    :description => "Shiny rate multiplier during outbreaks (1-10x).",
    :category => category
  })

  ModSettingsMenu.register(:voe_outbreak_no_shiny_despawn, {
    :name => "No Shiny Despawn (Outbreak)",
    :type => :toggle,
    :default => 1,
    :description => "Prevent shiny despawn during outbreaks.",
    :category => category
  })

  ModSettingsMenu.register(:voe_outbreak_spawn_count, {
    :name => "Outbreak Initial Spawns",
    :type => :slider,
    :min => 3,
    :max => 12,
    :default => 6,
    :description => "Pokemon spawned when outbreak starts.",
    :category => category
  })

  ModSettingsMenu.register(:voe_outbreak_max_override, {
    :name => "Outbreak Max Pokemon",
    :type => :slider,
    :min => 5,
    :max => 20,
    :default => 12,
    :description => "Max encounters during an outbreak.",
    :category => category
  })

  ModSettingsMenu.register(:voe_outbreak_spawn_rate, {
    :name => "Outbreak Spawn Rate",
    :type => :slider,
    :min => 50,
    :max => 500,
    :default => 200,
    :description => "Frames between spawns during outbreaks (Lower is faster).",
    :category => category
  })

  ModSettingsMenu.register(:voe_outbreak_radius, {
    :name => "Outbreak Radius",
    :type => :slider,
    :min => 5,
    :max => 30,
    :default => 15,
    :description => "Radius around the player where outbreak Pokemon appear.",
    :category => category
  })

  ModSettingsMenu.register(:voe_outbreak_shiny_panic, {
    :name => "Outbreak Shiny Panic",
    :type => :toggle,
    :default => true,
    :description => "1/8096 chance to turn all spawns Shiny for 1 minute during outbreaks.",
    :category => category
  })

  ModSettingsMenu.register(:voe_outbreak_debug_start, {
    :name => "[DEBUG] START EVENT",
    :type => :button,
    :on_press => proc {
      $game_temp.outbreak_debug_start_queued = true
      pbMessage(_INTL("Outbreak start queued for menu exit.")) if defined?(pbMessage)
    },
    :description => "Forces an outbreak to start when you exit the menu.",
    :category => category
  })

  ModSettingsMenu.register(:voe_outbreak_debug_panic, {
    :name => "[DEBUG] START PANIC",
    :type => :button,
    :on_press => proc {
      $game_temp.outbreak_debug_panic_queued = true
      pbMessage(_INTL("Panic Outbreak queued for menu exit.")) if defined?(pbMessage)
    },
    :description => "Forces a Shiny Panic outbreak to start when you exit the menu.",
    :category => category
  })

  ModSettingsMenu.register(:voe_outbreak_shiny_panic_debug, {
    :name => "[DEBUG] TRIGGER PANIC",
    :type => :button,
    :on_press => proc {
      if defined?(VOEOutbreak) && VOEOutbreak.active?
        VOEOutbreak.start_shiny_panic
        pbMessage(_INTL("SHINY PANIC TRIGGERED!")) if defined?(pbMessage)
      else
        pbMessage(_INTL("Start an outbreak first!")) if defined?(pbMessage)
      end
    },
    :description => "Forces a Shiny Panic event if an outbreak is active.",
    :category => category
  })

  ModSettingsMenu.register(:voe_outbreak_debug_end, {
    :name => "[DEBUG] END EVENT",
    :type => :button,
    :on_press => proc {
      $game_temp.outbreak_debug_end_queued = true
      pbMessage(_INTL("Outbreak end queued for menu exit.")) if defined?(pbMessage)
    },
    :description => "Forces the current outbreak to end when you exit the menu.",
    :category => category
  })

  # =====================
  # VERSION INFO
  # =====================
  ModSettingsMenu.register(:voe_version_info, {
    :name => "[INFO] Version Info",
    :type => :button,
    :on_press => proc {
      if defined?(VOEVersion)
        VOEVersion.show_version_dialog
      else
        pbMessage(_INTL("Version: Unknown\n\nRun VOE_Updater.bat to update.")) if defined?(pbMessage)
      end
    },
    :description => "Show version info. Run VOE_Updater.bat to check for updates.",
    :category => category
  })
end
