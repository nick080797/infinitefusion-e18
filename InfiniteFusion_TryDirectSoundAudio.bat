@echo off
REM Troubleshooting launcher: forces the game's audio backend (OpenAL Soft)
REM to use DirectSound/WinMM instead of WASAPI, working around a
REM "Failed to get padding: 0x88890004" (AUDCLNT_E_DEVICE_INVALIDATED)
REM WASAPI error seen in this game's logs on every boot. Safe to delete
REM this file at any time - it changes nothing permanent, just an
REM environment variable for this one launch.
set ALSOFT_DRIVERS=dsound,winmm
start "" "%~dp0InfiniteFusion.exe"
