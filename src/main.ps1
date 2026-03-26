[CmdletBinding()]
param()

$scriptpath = $PSScriptRoot
$rootpath = Split-Path -Path $scriptpath -Parent
$integrityfile = join-path $rootpath "config\integrity.sha256"
$configfile = join-path $rootpath "config\settings.b64"
$logpath = join-path $rootpath "logs"
$logfile = join-path $logpath "audit_$(Get-Date -Format 'yyyyMMdd_HHmm').log"
$downloadpath = "$env:USERPROFILE\Downloads"

if (-not (test-path $logpath)) { New-Item -ItemType Directory -Path $logpath | Out-Null }

function Write-SecureLog {
    param([string]$Message, [string]$level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logentry = "[$timestamp] [$level] $Message"
Add-Content -Path $logfile -value $logentry -encoding UTF8
    $Color = switch($level) {
        "ERROR" {  "Red"  }
        "WARN"  { "Yellow"}
        default { "Green" }
    }
    Write-Host $logentry -ForegroundColor $Color
 }

 try {
    . (Join-Path $scriptpath "helpers.ps1")
 }
 catch {
    Write-Host "FATAL: Could not load auxiliary functions/modules" -ForegroundColor Red
    exit 1
 }

 Write-SecureLog "Starting self-integrity check..." "SECURITY"
if(-not (Test-Path $integrityfile)) {
    Write-SecureLog "Integrity file not found. Aborting." "ERROR"
    exit 1
}

$CurrentScriptHash = (Get-FileHash -Path $myinvocation.mycommand.path -Algorithm SHA256).Hash.ToLower()
$CurrentConfigHash = (Get-FileHash -Path $configfile -Algorithm SHA256).Hash.ToLower()

$IntegrityData = Get-Content $integrityfile | Where-Object { $_ -notmatch "^#" -and $_.Trim() -ne "" }

$scriptvalid = $false
$configvalid = $false

foreach ($line in $IntegrityData) {
    $Parts = $Line -split '\s+'
    if ($Parts.Count -ge 2) {
        $Hash = $Parts[0].ToLower()
        $File = $Parts[1]
        if ($File -like "*main.ps1") {
            if ($Hash -eq $CurrentScriptHash) { $ScriptValid = $true }
        }
        if ($File -like "*settings.b64") {
            if ($Hash -eq $CurrentConfigHash) { $ConfigValid = $true }
        }
    }
}

if(-not $scriptvalid) {
    Write-SecureLog "Script integrity check failed! The script may have been tampered with." "ERROR"
    Write-SecureLog "Expected - Actual hash mismatch, aborting modification. :)"
    exit 1
}

if (-not $configvalid) {
    Write-SecureLog "Security Alert: Configuration file has been tampered with." "ERROR"
}

Write-SecureLog "Integrity check passed. Proceeding with execution of the script, enjoy."

# Load Configuration

try {
    $B64Content = Get-Content $configfile -raw 
    $config = ConvertFrom-Json $([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($B64Content)))
    if (-not $Config) { throw  "Decoding configuration failed." }

}

catch {
    Write-SecureLog "FATAL: Could not read secure configuration" "ERROR"
    exit 1 
}

# Enviroment PreChecks (see if system that's running this script, can run it)
if (-not (Test-DiskSpace -Path $downloadpath -RequiredMB 5000)) {
    Write-SecureLog "Fatal: Not enough disk space to download any ISO, please free up some space." "ERROR"
    exit 1
}

# Check network connectivity.
if (-not (Test-Connection -ComputerName 8.8.8.8 -Count 1 -Quiet)) {
    Write-SecureLog "Fatal: No network connectivity, please check your connection and try again." "ERROR"
    exit 1
}

# Force TLS12/13

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
$ProgressPreference = $SilentlyContinue

# Download Section

Clear-Host
Write-Host "Welcome to ISO Downloader Project, Verified & Secure" -ForegroundColor Cyan

Write-Host "Available ISOs:" -ForegroundColor Green
#Write-Host $config
Write-Host $config.Targets
foreach ($iso in $config.Targets.ISOs) {
    Write-Host "[$($iso.ID)] $($iso.Name)"
}
Write-Host "Exit [0]"

$Selection = Read-Host "Select an ISO to download by entering the corresponding number."
if ($Selection -eq "0") { exit }

$Target = $config.Targets.ISOs | Where-Object { $_.ID -eq $Selection}

if ($Target) {
    $DirectUrl = $Target.URL
    if ($TargetUrl -match "/file/d/(.*?)/") {
        $DirectUrl = "https://drive.google.com/file/d/1cifAGLR9rOqvB2m9SJF40fk0N-zqE92K/view?usp=sharing$(Matches[1])"
    }

    $DestFile = Join-Path $downloadpath $Target.FileName
    
    Write-Host ""
    Write-Host ">> Starting download of the ISO..."

    try {
        $Headers = @{ "User-Agent" = "Mozilla/5.0"}
        Invoke-WebRequest -Uri $DirectUrl -OutFile $Destfile -Headers $Headers -UseBasicParsing -ErrorAction Stop
        if ($Target.Sha256) {
            $ActualHash = (Get-FileHash -Path $DestFile -Algorithm SHA256).Hash.ToLower()
            if ($ActualHash -ne $Target.Sha256.ToLower()) {
                throw "SHA256 Hash Mismatched, file compromised."
            }
        }
        Write-Host ">> Download complete and verified." -ForegroundColor Green
        Write-SecureLog "Download succesful: $($Target.FileName)" "INFO"

        $RufusPath = Join-Path $DownloadPath "rufus.exe"
        if (-not (Test-Path $RufusPath)) {
            Write-Host ">> Rufus not found. Downloading Rufus for you..." -ForegroundColor Yellow
            Invoke-WebRequest -Uri "https://github.com/pbatard/rufus/releases/download/v4.13/rufus-4.13.exe" -OutFile $RufusPath -UseBasicParsing
        }
        Write-Host "Process completed." -ForegroundColor Green
        Invoke -item $downloadpath
    }
    catch {
        Write-SecureLog "Download failed: $($_.Exception.Message)" "ERROR"
        Write-Host ">> Critical error. Cleaning partial files..." -ForegroundColor Red
        Invoke-SecureDelete -Path $DestFile
        Write-Host ">> Process aborted."   -ForegroundColor Red

    }

}
else {
    Write-Host "Invalid selection!" -ForegroundColor Red
}

Write-Host ""
Read-Host "Press Enter to exit."
