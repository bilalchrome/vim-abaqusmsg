@echo off
rem Close Notepad++ first. Add -Dark for dark-background colours.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-notepad++.ps1" %*
pause
