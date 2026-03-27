## This script contain security helper functions, useful. 
class ISODownloaderHelper {
    [string] $logPath #the location of the log ./log/audit_date.log
    [string] $rootPath #the root of the scripts ./
    [string] $stringPath #the path of the script

    [string] $configFile #config file ./config/settings.b64
    [string] $integrityFile #integrity file ./config/integrity.sha256
    [bool] $genuine #if the script is genuine and not tampered
    [object] $configObject #generated object from the configfile ./config/settings.b64 

    [string] $downloadPath #./downloads

    #the script init
    ISODownloaderHelper($stringPath) {

        $this.stringPath = $stringPath
        Write-Host $this.stringPath
        $this.rootPath = Split-Path -Path $this.stringPath -Parent
        $logFolder =  Join-Path $this.rootPath "logs"
        if(-not ([System.IO.Directory]::Exists($logFolder))){
            [System.IO.Directory]::CreateDirectory($logFolder)
        }
        $this.logPath = Join-Path $logFolder "audit_$(Get-Date -Format 'yyyyMMdd_HHmm').log"
        
        $this.downloadPath = Join-Path $this.rootPath "downloads"
        if(-not ([System.IO.Directory]::Exists($this.downloadPath))){
            [System.IO.Directory]::CreateDirectory($this.downloadPath)
        }

        $this.integrityFile = Join-Path $this.rootPath "config\integrity.sha256"
        $this.configFile = Join-Path $this.rootPath "config\settings.b64"

        $this.genuine = $this.CheckScriptIntegrity()

        if(-not $this.genuine){
            exit 1
        }
    }

    [bool] CheckScriptIntegrity() {
        if(-not (Test-Path $this.integrityFile)) {
           $this.WriteSecureLog("Integrity file not found. Aborting.", "ERROR")
           return $false;
        }

        $CurrentScriptHash = (Get-FileHash -Path $(Join-Path $this.stringPath "main.ps1") -Algorithm SHA256).Hash.ToLower()
        $CurrentConfigHash = (Get-FileHash -Path $this.configfile -Algorithm SHA256).Hash.ToLower()

        $IntegrityData = Get-Content $this.integrityfile | Where-Object { $_ -notmatch "^#" -and $_.Trim() -ne "" }

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
            $this.WriteSecureLog("Script integrity check failed! The script may have been tampered with.", "ERROR")
            return $false
        }

        if (-not $configvalid) {
            $this.WriteSecureLog("Security Alert: Configuration file has been tampered with.", "WARN")
        }
        
        try {
            $B64Content = Get-Content $this.configfile -raw 
            $this.configObject = ConvertFrom-Json $([System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($B64Content)))
            if (-not $this.configObject) { throw  "Decoding configuration failed." }
        }

        catch {
            $this.WriteSecureLog("FATAL: Could not read secure configuration", "ERROR")
            return $false
        }

        return $true
    }

    [void] WriteSecureLog([string]$Message, [string]$level = "INFO") {

        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logentry = "[$timestamp] [$level] $Message"
    
        Add-Content -Path $this.logPath -value $logentry -encoding UTF8
        $Color = switch($level) {
            "ERROR" {  "Red"  }
            "WARN"  { "Yellow"}
            default { "Green" }
        }
        Write-Host $logentry -ForegroundColor $Color
    }

    static [bool] FileSecureDelete([string]$path) {
        
        if(-not ([System.IO.Directory]::Exists($path))){
               return $false
        }
        
        try {      
          $fileLength = (Get-Item $path).Length
          $fileStream = New.Object System.IO.Filestream($path, [System.IO.Filemode]::Open, [System.IO.FileAccess]::Write, [System.IO.Fileshare]::None)
          $fileBinaryWriter = New-Object System.IO.BinaryWriter($fileStream)
            # Overwrite with zer0s to prevent recovery :)
            for ($i = 0; $i -lt  $fileLength; $i++) {
                $fileBinaryWriter.Write([byte]0)
            }
            $fileBinaryWriter.Close()
            $fileStream.Close()
            Remove-Item $path -Force
            return $true 
        }
        catch {
            Remove-Item $path -Force -ErrorAction SilentlyContinue
            return $false
        }
    }

    static [bool] TestAvailableSpace([string]$path, [string]$requiredMB) {
        
        $drive = (Get-Item $path).PSDrive.Root
        $availableSpace = (Get-PSDrive | Where-Object {$_.Root -eq $drive}).Free / 1MB
        if ($availableSpace -lt $requiredMB) {
           return $false
        }
        return $true
    }
}