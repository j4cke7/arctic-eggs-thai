@echo off
set "THAI_MOD_PICK=1"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Patch.ps1" -Action Install %*
if errorlevel 1 (echo Operation failed. & pause & exit /b 1)
pause
