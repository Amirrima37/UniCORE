@echo off
echo ===================================================
echo   UniCORE - Creating Desktop Shortcut with Icon
echo ===================================================

powershell -NoProfile -ExecutionPolicy Bypass -Command "$WshShell = New-Object -ComObject WScript.Shell; $Desktop = [System.Environment]::GetFolderPath('Desktop'); $Shortcut = $WshShell.CreateShortcut(\"$Desktop\UniCORE.lnk\"); $Shortcut.TargetPath = 'c:\dev\UniCORE\Launch_UniCORE.exe'; $Shortcut.WorkingDirectory = 'c:\dev\UniCORE'; $Shortcut.IconLocation = 'c:\dev\UniCORE\icon.ico,0'; $Shortcut.Description = 'UniCORE - Universal Core AI Runtime Environment'; $Shortcut.Save(); Write-Host 'Shortcut with UniCORE icon created successfully on Desktop!'"

echo.
echo Ready! You can now launch UniCORE with its icon directly from your Desktop.
pause
