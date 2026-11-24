@echo off
rem Close Notepad++ first. Installs light and dark mode colours.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-notepad++.ps1" %*
pause
