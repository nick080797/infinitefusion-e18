# ==============================================================================
# VOE VERSION INFO
# ==============================================================================
# Simple version tracking - Update checking is done via external updater
# Repo: https://github.com/jov4n/KurayOverworldEncounters
# ==============================================================================

module VOEVersion
  VERSION = "2.2.5"
  VERSION_DATE = "2026-03-29"
  
  GITHUB_REPO = "jov4n/KurayOverworldEncounters"
  
  CHANGELOG = {
    "2.1.0" => [
      "BUGFIX: Fixed race conditions causing ghost encounters after battles",
      "BUGFIX: Fixed horde battles not properly despawning both Pokemon when running",
      "BUGFIX: Fixed shinies during PANIC! not despawning after battles",
      "BUGFIX: Fixed leftover encounters with partial HP triggering new battles",
      "BUGFIX: Fixed SHINY_PANIC_ENABLED setting not properly converting to boolean",
      "IMPROVEMENT: Added panic cleanup when shiny panic ends",
      "IMPROVEMENT: Better logging for despawn events",
      "FEATURE: Added standalone updater (VOE_Updater.bat)"
    ],
    "2.0.0" => [
      "Initial release with Outbreak system",
      "Horde battles (2v1)",
      "Fusion encounters",
      "Shiny Panic event"
    ]
  }
  
  class << self
    def version
      VERSION
    end
    
    def version_date
      VERSION_DATE
    end
    
    def changelog(ver = nil)
      ver ? CHANGELOG[ver] : CHANGELOG
    end
    
    def display_info
      echoln "=============================================="
      echoln " VOE - Kuray's Overworld Encounters"
      echoln " Version: #{VERSION} (#{VERSION_DATE})"
      echoln " Repo: github.com/#{GITHUB_REPO}"
      echoln " Run VOE_Updater.bat to check for updates"
      echoln "=============================================="
    end
    
    def show_version_dialog
      if defined?(pbMessage)
        pbMessage(_INTL("VOE - Kuray's Overworld Encounters\n\nVersion: #{VERSION}\nDate: #{VERSION_DATE}\n\nTo update, close the game and run VOE_Updater.bat"))
      end
    end
  end
end

# Display version on load
VOEVersion.display_info
