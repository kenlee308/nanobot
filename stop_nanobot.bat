@echo off
echo Stopping Nanobot processes...
powershell -NoProfile -Command "Get-WmiObject Win32_Process | Where-Object { $_.Name -eq 'python.exe' -and $_.CommandLine -like '*nanobot*' } | ForEach-Object { Write-Host 'Killing process ' $_.ProcessId; Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }"
echo Done.
pause
