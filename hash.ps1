# If you want to re-generate the hash values for the config/integrity.sha256 file, you can run this script, and it will output the new hash values for all the files in the downloads folder, which you can then copy and paste into the integrity.sha256 file.

$Root = $PSScriptRoot

$HashMain = (Get-FileHash -Path "$Root\src\main.ps1" -Algorithm SHA256).Hash
$HashConfig = (Get-FileHash -Path "$Root\config\settings.b64" -Algorithm SHA256).Hash
$IntegrityFile = "$Root\config\integrity.sha256"

Set-Content -Path $IntegrityFile -Value "# Auto-generated Integrity File" -Encoding UTF8
Add-Content -Path $IntegrityFile -Value "$HashMain  src/main.ps1" -Encoding UTF8
Add-Content -Path $IntegrityFile -Value "$HashConfig  config/settings.b64" -Encoding UTF8

Write-Host "✅ Hash values regenerated, run script again." -ForegroundColor Green