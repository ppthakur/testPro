# rsync_copy.ps1 — Copy files/folders between two Windows laptops on the same WiFi.
#
# Requirements (install once):
#   1. OpenSSH Client  : Settings > System > Optional Features > "OpenSSH Client"
#   2. rsync via one of:
#        - WSL2  (recommended) : wsl --install  (then run this script from PowerShell)
#        - cwRsync              : https://www.itefix.net/cwrsync  (free edition)
#        - winget               : winget install -e --id WinSCP.WinSCP  (GUI alt)
#
# SSH on the REMOTE laptop:
#   Settings > System > Optional Features > "OpenSSH Server"
#   Then in an Admin PowerShell: Start-Service sshd; Set-Service sshd -StartupType Automatic
#
# Usage:
#   .\rsync_copy.ps1 -User alice -Host 192.168.1.42 -Source "C:\Users\You\Documents" -Dest "/home/alice/Documents"
#   .\rsync_copy.ps1 -User alice -Host 192.168.1.42 -Direction pull -Source "/home/alice/photos" -Dest "C:\Users\You\Pictures\photos"
#   .\rsync_copy.ps1 -Scan    # list devices on your WiFi network (requires nmap)

param(
    [string]$User      = $env:REMOTE_USER,
    [string]$Host      = $env:REMOTE_HOST,
    [string]$Port      = $(if ($env:REMOTE_PORT) { $env:REMOTE_PORT } else { "22" }),
    [string]$Key       = $env:SSH_KEY,          # path to private key (optional)
    [string]$Direction = "push",                # push = local->remote | pull = remote->local
    [string]$Source,
    [string]$Dest,
    [switch]$DryRun,
    [switch]$Scan
)

# ── Helper: detect rsync command ───────────────────────────────────────────────
function Get-RsyncCmd {
    # Prefer WSL rsync (most compatible)
    if (Get-Command wsl -ErrorAction SilentlyContinue) {
        $r = wsl which rsync 2>$null
        if ($r) { return "wsl rsync" }
    }
    # Fallback: native rsync (cwRsync or MSYS2)
    if (Get-Command rsync -ErrorAction SilentlyContinue) { return "rsync" }
    Write-Error @"
rsync not found. Install one of:
  - WSL2       : wsl --install
  - cwRsync    : https://www.itefix.net/cwrsync
  - MSYS2      : https://www.msys2.org  then: pacman -S rsync
"@
    exit 1
}

# ── Convert Windows path to WSL/Unix path ─────────────────────────────────────
function ConvertTo-UnixPath([string]$p) {
    if ($p -match '^[A-Za-z]:\\') {
        # C:\Users\alice\Docs  ->  /mnt/c/Users/alice/Docs
        $drive = $p[0].ToString().ToLower()
        $rest  = $p.Substring(2).Replace('\', '/')
        return "/mnt/$drive$rest"
    }
    return $p.Replace('\', '/')
}

# ── Scan WiFi for live hosts ───────────────────────────────────────────────────
if ($Scan) {
    if (-not (Get-Command nmap -ErrorAction SilentlyContinue)) {
        Write-Host "nmap not found. Install: https://nmap.org/download.html" -ForegroundColor Yellow
        exit 1
    }
    # Detect local WiFi subnet
    $ip = (Get-NetIPAddress -AddressFamily IPv4 |
           Where-Object { $_.InterfaceAlias -match 'Wi.?Fi|Wireless|WLAN' } |
           Select-Object -First 1).IPAddress
    if (-not $ip) {
        $ip = (Get-NetIPAddress -AddressFamily IPv4 |
               Where-Object { $_.PrefixOrigin -eq 'Dhcp' } |
               Select-Object -First 1).IPAddress
    }
    $subnet = ($ip -replace '\.\d+$', '.0') + '/24'
    Write-Host "Scanning $subnet for live hosts..." -ForegroundColor Cyan
    nmap -sn $subnet
    exit 0
}

# ── Validate inputs ────────────────────────────────────────────────────────────
$errors = 0
if (-not $User)      { Write-Error "Remote username required. Use -User alice"; $errors++ }
if (-not $Host)      { Write-Error "Remote host/IP required. Use -Host 192.168.1.42"; $errors++ }
if (-not $Source)    { Write-Error "Source path required. Use -Source 'C:\path'"; $errors++ }
if (-not $Dest)      { Write-Error "Destination path required. Use -Dest '/remote/path'"; $errors++ }
if ($Direction -notin @('push','pull')) { Write-Error "Direction must be 'push' or 'pull'"; $errors++ }
if ($errors -gt 0)   { exit 1 }

$RsyncCmd = Get-RsyncCmd

# ── Convert paths if using WSL ─────────────────────────────────────────────────
$useWSL = $RsyncCmd -eq "wsl rsync"
if ($useWSL) {
    if ($Direction -eq "push") { $Source = ConvertTo-UnixPath $Source }
    else                       { $Dest   = ConvertTo-UnixPath $Dest   }
}

# ── Build SSH options ──────────────────────────────────────────────────────────
$sshOpts = "-o StrictHostKeyChecking=ask -o ConnectTimeout=10 -p $Port"
if ($Key) { $sshOpts += " -i `"$(ConvertTo-UnixPath $Key)`"" }

# ── Build rsync arguments ──────────────────────────────────────────────────────
$rsyncArgs = @(
    "--archive",
    "--verbose",
    "--human-readable",
    "--progress",
    "--compress",
    "--partial",
    "--exclude=.DS_Store",
    "--exclude=Thumbs.db",
    "--exclude=desktop.ini",
    "--exclude=*.tmp"
)
if ($DryRun) { $rsyncArgs += "--dry-run" }

$remote = "${User}@${Host}"
if ($Direction -eq "push") {
    $src = $Source
    $dst = "${remote}:${Dest}"
} else {
    $src = "${remote}:${Source}"
    $dst = $Dest
    New-Item -ItemType Directory -Force -Path $Dest | Out-Null
}

# ── Summary ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "  rsync copy  (WiFi LAN)"                       -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ("  {0,-12} {1}" -f "Direction:", "$Direction  (push = local→remote | pull = remote→local)")
Write-Host ("  {0,-12} {1}" -f "From:",      $src)
Write-Host ("  {0,-12} {1}" -f "To:",        $dst)
Write-Host ("  {0,-12} {1}" -f "Remote IP:", "$Host  port $Port")
if ($Key)    { Write-Host ("  {0,-12} {1}" -f "SSH key:",  $Key) }
if ($DryRun) { Write-Host ("  {0,-12} {1}" -f "Mode:",     "DRY RUN — no files will be transferred") -ForegroundColor Yellow }
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

# ── Run ────────────────────────────────────────────────────────────────────────
if ($useWSL) {
    # Pass everything through WSL so paths and SSH agent work correctly
    $rsyncArgStr = ($rsyncArgs | ForEach-Object { "'$_'" }) -join " "
    wsl rsync $rsyncArgs -e "ssh $sshOpts" $src $dst
} else {
    & rsync @rsyncArgs -e "ssh $sshOpts" $src $dst
}

Write-Host ""
Write-Host "Transfer complete." -ForegroundColor Green
