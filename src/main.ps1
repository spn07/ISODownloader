using module ".\helpers.psm1"

#Load the helper functions
[ISODownloaderHelper]$downloadHelper = [ISODownloaderHelper]::new($PSScriptRoot)

# Force TLS12/13
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
$ProgressPreference = $SilentlyContinue

# Enviroment PreChecks (see if system that's running this script, can run it)
if (-not ([ISODownloaderHelper]::TestAvailableSpace($downloadHelper.downloadPath, 10240))) {
    $downloadHelper.WriteSecureLog("Fatal: Not enough disk space to download any ISO, please free up some space.", "ERROR")
    exit 1
}

# Check network connectivity.
if (-not (Test-Connection -ComputerName 8.8.8.8 -Count 1 -Quiet)) {
    $downloadHelper.WriteSecureLog("Fatal: No network connectivity, please check your connection and try again.", "ERROR")
    exit 1
}


# Download Section

Clear-Host
Write-Host "Welcome to ISO Downloader Project, Verified & Secure" -ForegroundColor Cyan

Write-Host "Available ISOs:" -ForegroundColor Green
$config = $downloadHelper.configObject
foreach ($iso in $config.Targets.ISOs) {
    Write-Host "[$($iso.ID)] $($iso.Name)"
}
Write-Host "Exit [0]"

$Selection = Read-Host "Select an ISO to download by entering the corresponding number."
if ($Selection -eq "0") { exit }

$Target = $config.Targets.ISOs | Where-Object { $_.ID -eq $Selection}

if ($Target) {
    $DestFile = Join-Path $downloadHelper.downloadPath $Target.FileName
    
    Write-Host ""
    Write-Host ">> Downloading.... (check on ~/ISODownloader-main/downloads)"

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
        $downloadHelper.WriteSecureLog("Download succesful: $($Target.FileName)", "INFO")
    }
    catch {
        $downloadHelper.WriteSecureLog("Download failed.", "ERROR")
        $downloadHelper.WriteSecureLog("Reason: $($_.Exception.Message)", "ERROR")
        Write-Host ">> Critical error. Cleaning partial files..." -ForegroundColor Red
        [ISODownloaderHelper]::FileSecureDelete($DestFile)
        Write-Host ">> Process aborted." -ForegroundColor Red
    }
}
else {
    Write-Host "Invalid selection!" -ForegroundColor Red
}

Write-Host ""
Read-Host "Press Enter to exit."
