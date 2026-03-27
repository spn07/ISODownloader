[CmdletBinding()]
param()

$scriptpath = $PSScriptRoot
$rootpath = Split-Path -Path $scriptpath -Parent
$integrityfile = join-path $rootpath "config\integrity.sha256"
$configfile = join-path $rootpath "config\settings.b64"
$logpath = join-path $rootpath "logs"
$logfile = join-path $logpath "audit_$(Get-Date -Format 'yyyyMMdd_HHmm').log"
$downloadpath = join-path $rootpath "data"

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

foreach ($iso in $config.Targets.ISOs) {
    Write-Host "[$($iso.ID)] $($iso.Name)"
}
Write-Host "Exit [0]"

$Selection = Read-Host "Select an ISO to download by entering the corresponding number."
if ($Selection -eq "0") { exit }

$Target = $config.Targets.ISOs | Where-Object { $_.ID -eq $Selection}

if ($Target) {
    $DestFile = Join-Path $downloadpath $Target.FileName
    
    Write-Host $Target.URL
    Write-Host ""
    Write-Host ">> Starting download of the ISO..."

    #We invoke the webclient, and download the iso
    $client = New-Object System.Net.WebClient
    try {
        $client.DownloadFile($Target.URL, $DestFile)
        if ($Target.Sha256) {
            #we check the hash
            $ActualHash = (Get-FileHash -Path $DestFile -Algorithm SHA256).Hash.ToLower()
            if ($ActualHash -ne $Target.Sha256.ToLower()) {
                throw "SHA256 Hash Mismatched, file compromised. You need to run the script again!"
            }
        }
        Write-Host ">> Download complete and verified." -ForegroundColor Green
        Write-SecureLog "Download succesful: $($Target.FileName)" "INFO"
    }
    catch {
        Write-SecureLog "Download failed." "ERROR"
        Write-SecureLog "Reason: $($_.Exception.Message)" "ERROR"
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
