<#  ZETX PC ARIZA TAKİP ONARIM — EXE OLUŞTURUCU (ps2exe)  #>
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
Get-ChildItem -LiteralPath $PSScriptRoot -File | Unblock-File
Write-Host '== ZETX EXE OLUŞTURUCU ==' -ForegroundColor Cyan
if (-not (Get-Module -ListAvailable -Name ps2exe)) {
    Write-Host 'ps2exe modülü kuruluyor (ilk seferde, internet gerekir)...' -ForegroundColor Yellow
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    if (-not (Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue)) { Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force | Out-Null }
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    Install-Module -Name ps2exe -Scope CurrentUser -Force
}
Import-Module ps2exe
$out = Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Downloads\ZETX PC Ariza Takip Onarim.exe'
Write-Host 'EXE oluşturuluyor...' -ForegroundColor Cyan
Invoke-ps2exe -inputFile (Join-Path $PSScriptRoot 'ZETX-PC-Ariza-Takip-Onarim.ps1') -outputFile $out `
    -iconFile (Join-Path $PSScriptRoot 'zetx.ico') -title 'ZETX PC ARIZA TAKİP ONARIM' -product 'ZETX PC ARIZA TAKİP ONARIM' `
    -description 'Donanım/sistem arıza tespit, onarım, darboğaz ve FPS — Volkan Sezer (ücretsiz)' -company 'ZETX' -copyright '© Volkan Sezer' `
    -version '1.3.2.0' -noConsole -STA -DPIAware -requireAdmin
Write-Host ''
Write-Host ('TAMAM! EXE İndirilenler klasörüne kaydedildi: ' + $out) -ForegroundColor Green
Read-Host 'Kapatmak için Enter'
