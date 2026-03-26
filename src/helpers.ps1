## This script contain security helper functions, useful. 
function Invoke-SecureDelete {
    param([string]$Path)
    if (Test-Path $Path) {
        try {
            $length = (Get-Item $Path).Length
            $Stream = New.Object System.IO.Filestream($Path, [System.IO.Filemode]::Open, [System.IO.FileAcces]::Write, [System.IO.Fileshare]::None)
            $Writer = New-Object System.IO.BinaryWriter($Stream)
            # Overwrite with zer0s to prevent recovery :)
            for ($i = 0; $i -lt  $length; $i++) {
                $Writer.Write([byte]0)
            }
            $Writer.Close()
            $Stream.Close()
            Remove-Item $Path -Force
            return $true
        }
        catch {
            Remove-Item $Path -Force -ErrorAction SilentlyContinue
            return $false
        }
    }
    return $true
}
function Test-DiskSpace {
    param([string]$Path, [long]$RequiredMB)
    $drive = (Get-Item $Path).PSDrive.Root
    $FreeSpace = (Get-PSDrive | Where-Object {$_.Root -eq $drive}).Free / 1MB
    if ($FreeSpace -lt $RequiredMB) {
        return $false
    }
    return $true
}

function ConvertFromBase64Config {
    param([string]$B64String)
    try {
        $Bytes = [System.Convert]::FromBase64String($B64String)
        return [System.Text.Encoding]::UTF8.GetString($Bytes) | ConvertFrom-Json
    }
    catch {
        return $null
    }
}