if ENV['GBAWORLD_PLAYTEST_SAVEDIR']
  dir = ENV['GBAWORLD_PLAYTEST_SAVEDIR']
  Dir.mkdir(dir) unless File.directory?(dir)
  verbose = $VERBOSE
  $VERBOSE = nil
  SaveData::SAVE_DIR = dir
  $VERBOSE = verbose
  echoln("[PlaytestSaveIsolation] Saves redirected to #{dir}")
end
