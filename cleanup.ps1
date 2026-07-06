#Requires -RunAsAdministrator
# Advanced Trace Cleanup

Write-Host "[*] Cleaning traces..." -ForegroundColor Yellow

# 1. PowerShell History
Clear-History -ErrorAction SilentlyContinue
$hist = (Get-PSReadLineOption).HistorySavePath
if (Test-Path $hist) { Remove-Item $hist -Force }
Remove-Item "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\*.txt" -Force -ErrorAction SilentlyContinue

# 2. Event Logs
wevtutil cl "Windows PowerShell" 2>$null
wevtutil cl "Microsoft-Windows-PowerShell/Operational" 2>$null
wevtutil cl "Application" 2>$null
wevtutil cl "System" 2>$null
wevtutil cl "Security" 2>$null

# 3. Prefetch
Remove-Item "C:\Windows\Prefetch\POWERSHELL*.pf" -Force -ErrorAction SilentlyContinue
Remove-Item "C:\Windows\Prefetch\NOTEPAD*.pf" -Force -ErrorAction SilentlyContinue
Remove-Item "C:\Windows\Prefetch\CMD*.pf" -Force -ErrorAction SilentlyContinue

# 4. Temp files
Remove-Item "$env:TEMP\*" -Force -Recurse -ErrorAction SilentlyContinue
Remove-Item "C:\Windows\Temp\*" -Force -Recurse -ErrorAction SilentlyContinue

# 5. DNS Cache
ipconfig /flushdns | Out-Null

# 6. Recent Items
Remove-Item "$env:APPDATA\Microsoft\Windows\Recent\*" -Force -Recurse -ErrorAction SilentlyContinue

# 7. Run Dialog History (Registry)
Remove-Item "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU" -Force -Recurse -ErrorAction SilentlyContinue

# 8. TypedPaths (Explorer)
Remove-Item "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths" -Force -Recurse -ErrorAction SilentlyContinue

# 9. BAM (Background Activity Moderator)
Remove-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\bam\State\UserSettings\*" -Name "*powershell*" -Force -ErrorAction SilentlyContinue

# 10. Shimcache
# (ยากที่จะลบ ต้องรีบูต)

Write-Host "[+] Cleanup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Remaining traces:" -ForegroundColor Yellow
Write-Host "  - NTFS Journal (hard to clean)" -ForegroundColor DarkGray
Write-Host "  - Network logs (use VPN)" -ForegroundColor DarkGray
Write-Host "  - Memory (reboot to clear)" -ForegroundColor DarkGray
Write-Host ""
