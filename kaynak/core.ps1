# =====================================================================
#  ZETX PC ARIZA TAKİP ONARIM  -  ÇEKİRDEK MOTOR
#  Geliştirici: Volkan Sezer (ZETX)
# =====================================================================

$Global:ZETX = [ordered]@{
    AppName    = 'ZETX PC ARIZA TAKİP ONARIM'
    Version    = '1.3.1'
    Owner      = 'Volkan Sezer'
    Brand      = 'ZETX'
    Channel    = 'ZETXTV'
    Email      = 'volkan.sezer@outlook.com.tr'
    Discord    = 'https://discord.gg/nvqc84AHZf'
    Edition    = 'Ücretsiz Sürüm'
    RegPath    = 'HKCU:\Software\ZETX\PCArizaTakipOnarim'
}

$Global:ZDocs = [Environment]::GetFolderPath('MyDocuments'); if (-not $Global:ZDocs) { $Global:ZDocs = $env:USERPROFILE }; if (-not $Global:ZDocs) { $Global:ZDocs = $HOME }
$Global:ZDataDir   = Join-Path $Global:ZDocs 'ZETX PC Ariza Takip'
$Global:ZReportDir = Join-Path $Global:ZDataDir 'Raporlar'
$Global:ZBackupDir = Join-Path $Global:ZDataDir 'Kayit Defteri Yedekleri'
$Global:ZLogDir    = Join-Path $Global:ZDataDir 'Kayitlar'
$Global:ZHistory   = Join-Path $Global:ZDataDir 'tarama-gecmisi.jsonl'
foreach ($d in @($Global:ZDataDir, $Global:ZReportDir, $Global:ZBackupDir, $Global:ZLogDir)) {
    if (-not (Test-Path $d)) { try { New-Item -ItemType Directory -Path $d -Force | Out-Null } catch {} }
}

# ---------------------------------------------------------------------
#  GÜNLÜK / ÇIKTI
# ---------------------------------------------------------------------
function Write-ZLog {
    param([string]$Text, [string]$Level = 'INFO')
    $line = '[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $Text
    if ($Level -eq 'OK')   { $line = '[{0}] ✔ {1}' -f (Get-Date -Format 'HH:mm:ss'), $Text }
    if ($Level -eq 'WARN') { $line = '[{0}] ⚠ {1}' -f (Get-Date -Format 'HH:mm:ss'), $Text }
    if ($Level -eq 'ERR')  { $line = '[{0}] ✖ {1}' -f (Get-Date -Format 'HH:mm:ss'), $Text }
    if ($Global:Sync -and $Global:Sync.Log) { $Global:Sync.Log.Enqueue($line) }
    try { Add-Content -Path (Join-Path $Global:ZLogDir ('zetx-' + (Get-Date -Format 'yyyy-MM-dd') + '.log')) -Value $line -Encoding UTF8 } catch {}
}

function Set-ZProgress {
    param([int]$Percent, [string]$Text = '')
    if ($Global:Sync) { $Global:Sync.Progress = $Percent; if ($Text) { $Global:Sync.Status = $Text } }
}

function Invoke-ZProcess {
    # Harici komutu çalıştırır, çıktıyı satır satır günlüğe akıtır.
    param([string]$File, [string]$Arguments, [switch]$Unicode, [int]$TimeoutMin = 180)
    Write-ZLog ("Komut: {0} {1}" -f $File, $Arguments)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $File
    $psi.Arguments = $Arguments
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    if ($Unicode) { $psi.StandardOutputEncoding = [Text.Encoding]::Unicode }
    else {
        try { $psi.StandardOutputEncoding = [Text.Encoding]::GetEncoding([Globalization.CultureInfo]::CurrentCulture.TextInfo.OEMCodePage) } catch {}
    }
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    $all = New-Object System.Text.StringBuilder
    try { [void]$p.Start() } catch { Write-ZLog ("Başlatılamadı: " + $_.Exception.Message) 'ERR'; return [pscustomobject]@{ ExitCode = -1; Output = '' } }
    $deadline = (Get-Date).AddMinutes($TimeoutMin)
    $lastPct = ''
    while (-not $p.StandardOutput.EndOfStream) {
        $l = $p.StandardOutput.ReadLine()
        if ($null -eq $l) { continue }
        $l = ($l -replace "`0", '').Trim()
        if ($l -eq '') { continue }
        [void]$all.AppendLine($l)
        $m = [regex]::Match($l, '(\d{1,3})(?:[\.,]\d)?\s*%')
        if ($m.Success) {
            $pct = ConvertTo-ZInt $m.Groups[1].Value
            if ($pct -le 100) { Set-ZProgress $pct }
            $key = $m.Groups[1].Value
            if ($key -eq $lastPct) { continue }
            $lastPct = $key
        }
        Write-ZLog $l
        if ((Get-Date) -gt $deadline) { try { $p.Kill() } catch {}; Write-ZLog 'Zaman aşımı, işlem durduruldu.' 'ERR'; break }
    }
    $err = $p.StandardError.ReadToEnd()
    if ($err) { $err = ($err -replace "`0", '').Trim(); if ($err) { Write-ZLog $err 'WARN'; [void]$all.AppendLine($err) } }
    $p.WaitForExit()
    Write-ZLog ("Çıkış kodu: {0}" -f $p.ExitCode)
    [pscustomobject]@{ ExitCode = $p.ExitCode; Output = $all.ToString() }
}

function ConvertTo-ZNum {
    # Kültürden bağımsız güvenli sayı dönüşümü (Int32 hatalarını önler)
    param($Value, [double]$Default = 0)
    if ($null -eq $Value) { return $Default }
    if ($Value -is [array]) { if ($Value.Count -eq 0) { return $Default }; $Value = $Value[0] }
    if ($Value -is [System.Management.Automation.PSObject]) { $Value = $Value.BaseObject }
    if ($Value -is [bool]) { return [double][int]$Value }
    if ($Value -is [ValueType]) { try { return [double]$Value } catch { return $Default } }
    $t = ("$Value" -replace '[^\d\-\.,]', '')
    if ($t -match ',' -and $t -notmatch '\.') { $t = $t.Replace(',', '.') } else { $t = $t.Replace(',', '') }
    $d = 0.0
    if ([double]::TryParse($t, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$d)) { return $d }
    return $Default
}
function ConvertTo-ZInt { param($Value, [int]$Default = 0)
    $d = ConvertTo-ZNum $Value ([double]$Default)
    if ($d -gt [int]::MaxValue) { return [int]::MaxValue }; if ($d -lt [int]::MinValue) { return [int]::MinValue }
    [int][math]::Round($d)
}

function Test-ZAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Format-ZSize {
    param([double]$Bytes)
    if ($Bytes -ge 1TB) { return ('{0:N2} TB' -f ($Bytes / 1TB)) }
    if ($Bytes -ge 1GB) { return ('{0:N2} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N1} MB' -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ('{0:N0} KB' -f ($Bytes / 1KB)) }
    return ('{0:N0} B' -f $Bytes)
}

# ---------------------------------------------------------------------
#  BULGU NESNESİ
# ---------------------------------------------------------------------
function New-ZFinding {
    param(
        [ValidateSet('KRİTİK', 'UYARI', 'BİLGİ', 'İYİ')][string]$Severity,
        [string]$Category, [string]$Title, [string]$Detail = '', [string]$Advice = '',
        [string]$FixId = '', [string]$FixData = '', [string]$FixLabel = ''
    )
    if (-not $FixLabel -and $FixId) { $FixLabel = 'ONAR' }
    [pscustomobject]@{
        Severity = $Severity; Category = $Category; Title = $Title; Detail = $Detail; Advice = $Advice
        FixId = $FixId; FixData = $FixData; FixLabel = $FixLabel
    }
}

# ---------------------------------------------------------------------
#  SÖZLÜKLER
# ---------------------------------------------------------------------
$Global:ZBugChecks = @{
    0x0A  = @('IRQL_NOT_LESS_OR_EQUAL', 'Genellikle hatalı sürücü veya bozuk RAM. Son yüklenen sürücüleri güncelleyin, RAM testi yapın.')
    0x1A  = @('MEMORY_MANAGEMENT', 'RAM arızası veya XMP/EXPO kararsızlığı çok olası. Bellek tanılama çalıştırın, XMP kapatıp deneyin.')
    0x1E  = @('KMODE_EXCEPTION_NOT_HANDLED', 'Çekirdek modu sürücü hatası. Sürücüleri ve BIOSʼu güncelleyin.')
    0x24  = @('NTFS_FILE_SYSTEM', 'Disk dosya sistemi bozulması. CHKDSK çalıştırın, disk sağlığını kontrol edin.')
    0x3B  = @('SYSTEM_SERVICE_EXCEPTION', 'Sürücü (sıklıkla ekran kartı) veya sistem dosyası hatası. GPU sürücüsünü temiz kurun, SFC çalıştırın.')
    0x50  = @('PAGE_FAULT_IN_NONPAGED_AREA', 'Bozuk RAM, sürücü veya antivirüs. Bellek testi ve SFC önerilir.')
    0x7A  = @('KERNEL_DATA_INPAGE_ERROR', 'Diskten veri okunamadı: disk/kablo arızası olası. SMART ve CHKDSK kontrolü yapın.')
    0x7E  = @('SYSTEM_THREAD_EXCEPTION_NOT_HANDLED', 'Sürücü hatası. Son kurulan sürücüyü geri alın veya güncelleyin.')
    0x7F  = @('UNEXPECTED_KERNEL_MODE_TRAP', 'Donanım (RAM/CPU) veya aşırı hız aşırtma kararsızlığı.')
    0x9F  = @('DRIVER_POWER_STATE_FAILURE', 'Uyku/uyanma sırasında sürücü takıldı. Güç ayarlarını ve sürücüleri güncelleyin.')
    0xC2  = @('BAD_POOL_CALLER', 'Hatalı sürücü bellek kullanımı.')
    0xC5  = @('DRIVER_CORRUPTED_EXPOOL', 'Bozuk sürücü. Son yüklenen sürücüleri kaldırın.')
    0xD1  = @('DRIVER_IRQL_NOT_LESS_OR_EQUAL', 'Ağ/ses/ekran kartı sürücüsü kaynaklı olabilir. Sürücüleri güncelleyin.')
    0xEF  = @('CRITICAL_PROCESS_DIED', 'Kritik sistem işlemi çöktü. SFC + DISM onarımı yapın, disk sağlığını kontrol edin.')
    0xF4  = @('CRITICAL_OBJECT_TERMINATION', 'Disk bağlantısı/SSD arızası olası.')
    0xFC  = @('ATTEMPTED_EXECUTE_OF_NOEXECUTE_MEMORY', 'Sürücü veya RAM hatası.')
    0x101 = @('CLOCK_WATCHDOG_TIMEOUT', 'İşlemci yanıt vermedi: CPU hız aşırtma, voltaj veya BIOS sorunu.')
    0x116 = @('VIDEO_TDR_FAILURE', 'Ekran kartı sürücüsü yanıt vermedi. GPU sürücüsünü temiz kurun, GPU sıcaklığı/güç kablosunu kontrol edin.')
    0x117 = @('VIDEO_TDR_TIMEOUT_DETECTED', 'Ekran kartı zaman aşımı. Sürücü ve GPU donanımını kontrol edin.')
    0x119 = @('VIDEO_SCHEDULER_INTERNAL_ERROR', 'Ekran kartı sürücüsü/donanım hatası.')
    0x124 = @('WHEA_UNCORRECTABLE_ERROR', 'DONANIM HATASI: CPU, RAM, anakart veya güç kaynağı. Hız aşırtmayı kapatın, sıcaklık ve PSUʼyu kontrol edin.')
    0x133 = @('DPC_WATCHDOG_VIOLATION', 'Sürücü veya SSD yazılımı (firmware) sorunu. SSD firmware ve chipset sürücüsünü güncelleyin.')
    0x139 = @('KERNEL_SECURITY_CHECK_FAILURE', 'Bozuk sürücü veya sistem dosyası. SFC/DISM ve sürücü güncellemesi.')
    0x13A = @('KERNEL_MODE_HEAP_CORRUPTION', 'Sürücü bellek bozulması.')
    0x154 = @('UNEXPECTED_STORE_EXCEPTION', 'Disk/SSD sorunu veya antivirüs. Disk sağlığını kontrol edin.')
    0x1000007E = @('SYSTEM_THREAD_EXCEPTION_NOT_HANDLED_M', 'Sürücü hatası.')
    0x1000008E = @('KERNEL_MODE_EXCEPTION_NOT_HANDLED_M', 'Sürücü veya RAM hatası.')
    0x100000EA = @('THREAD_STUCK_IN_DEVICE_DRIVER_M', 'Ekran kartı sürücüsü takıldı.')
}

$Global:ZDeviceErrors = @{
    1 = 'Aygıt doğru yapılandırılmamış'; 3 = 'Sürücü bozuk olabilir veya bellek yetersiz'
    10 = 'Aygıt başlatılamıyor'; 12 = 'Yeterli boş kaynak bulunamadı'; 14 = 'Yeniden başlatma gerekiyor'
    18 = 'Sürücüler yeniden yüklenmeli'; 19 = 'Kayıt defteri yapılandırma bilgisi bozuk'
    21 = 'Aygıt kaldırılıyor'; 22 = 'Aygıt devre dışı bırakılmış'; 24 = 'Aygıt yok / çalışmıyor'
    28 = 'Sürücü yüklü değil'; 29 = 'Aygıt üretici yazılımı tarafından devre dışı'; 31 = 'Sürücü yüklenemedi'
    32 = 'Sürücü hizmeti devre dışı'; 33 = 'Kaynak belirlenemedi'; 37 = 'Sürücü başlatılamadı'
    39 = 'Sürücü bozuk veya eksik'; 40 = 'Kayıt defteri hizmet anahtarı bozuk'; 41 = 'Donanım algılanamadı'
    43 = 'Aygıt sorun bildirdiği için durduruldu (donanım/sürücü arızası)'; 45 = 'Aygıt bağlı değil'
    48 = 'Sürücü uyumsuzluk nedeniyle engellendi'; 52 = 'Sürücünün dijital imzası doğrulanamadı'
}

$Global:ZModuleHints = @{
    'nvwgf2um' = 'NVIDIA ekran kartı sürücüsü'; 'nvlddmkm' = 'NVIDIA ekran kartı sürücüsü'; 'nvoglv' = 'NVIDIA OpenGL sürücüsü'
    'atidxx' = 'AMD ekran kartı sürücüsü'; 'amdxx' = 'AMD ekran kartı sürücüsü'; 'atiumd' = 'AMD ekran kartı sürücüsü'; 'amdvlk' = 'AMD Vulkan sürücüsü'
    'igd10' = 'Intel grafik sürücüsü'; 'igdumd' = 'Intel grafik sürücüsü'; 'd3d11' = 'DirectX 11'; 'd3d12' = 'DirectX 12'; 'dxgi' = 'DirectX grafik altyapısı'
    'ntdll' = 'Windows çekirdek kitaplığı (genel çökme)'; 'kernelbase' = 'Windows çekirdek kitaplığı (genel çökme)'; 'ucrtbase' = 'C çalışma zamanı kitaplığı'
    'vcruntime' = 'Visual C++ çalışma zamanı'; 'msvcp' = 'Visual C++ çalışma zamanı'; 'clr' = '.NET çalışma zamanı'; 'coreclr' = '.NET çalışma zamanı'
    'xinput' = 'Oyun kumandası kitaplığı'; 'audioses' = 'Windows ses altyapısı'
}

# ---------------------------------------------------------------------
#  SİSTEM BİLGİSİ
# ---------------------------------------------------------------------
function Get-ZGpuVram {
    $list = @{}
    try {
        $base = 'HKLM:\SYSTEM\ControlSet001\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'
        Get-ChildItem $base -ErrorAction Stop | Where-Object { $_.PSChildName -match '^\d{4}$' } | ForEach-Object {
            $p = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
            if ($p -and $p.DriverDesc) {
                $v = $p.'HardwareInformation.qwMemorySize'
                if ($v) { if ($v -is [byte[]]) { $v = [BitConverter]::ToUInt64(($v + (New-Object byte[] 8))[0..7], 0) }; $list[$p.DriverDesc] = ConvertTo-ZNum $v }
            }
        }
    } catch {}
    $list
}

function Get-ZSystemInfo {
    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $bb = Get-CimInstance Win32_BaseBoard
    $bios = Get-CimInstance Win32_BIOS
    $gpus = @(Get-CimInstance Win32_VideoController)
    $ram = @(Get-CimInstance Win32_PhysicalMemory)
    $vram = Get-ZGpuVram
    $gpuText = ($gpus | ForEach-Object {
            $vr = $null; if ($vram.ContainsKey($_.Name)) { $vr = $vram[$_.Name] } elseif ($_.AdapterRAM) { $vr = ConvertTo-ZNum $_.AdapterRAM }
            if ($vr) { '{0} ({1})' -f $_.Name, (Format-ZSize $vr) } else { $_.Name }
        }) -join ' | '
    $ramTotal = ($ram | Measure-Object Capacity -Sum).Sum
    $ramSpeed = ($ram | Select-Object -First 1)
    $spd = ''
    if ($ramSpeed) {
        $cfg = $ramSpeed.ConfiguredClockSpeed; if (-not $cfg) { $cfg = $ramSpeed.Speed }
        $spd = '{0} MT/s' -f $cfg
    }
    $sysDisk = $null
    try {
        $part = Get-Partition -DriveLetter ($env:SystemDrive.TrimEnd(':')) -ErrorAction Stop
        $pd = Get-PhysicalDisk | Where-Object { $_.DeviceId -eq "$($part.DiskNumber)" } | Select-Object -First 1
        if ($pd) { $sysDisk = '{0} ({1}, {2}, {3})' -f $pd.FriendlyName, $pd.MediaType, $pd.BusType, (Format-ZSize $pd.Size) }
    } catch {}
    $uptime = (Get-Date) - $os.LastBootUpTime
    [pscustomobject][ordered]@{
        Bilgisayar   = $env:COMPUTERNAME
        Isletim      = '{0} ({1}, Build {2})' -f $os.Caption, $os.OSArchitecture, $os.BuildNumber
        Islemci      = '{0} — {1} çekirdek / {2} iş parçacığı' -f $cpu.Name.Trim(), $cpu.NumberOfCores, $cpu.NumberOfLogicalProcessors
        EkranKarti   = $gpuText
        Bellek       = '{0} — {1} modül, {2}' -f (Format-ZSize $ramTotal), $ram.Count, $spd
        Anakart      = '{0} {1}' -f $bb.Manufacturer, $bb.Product
        BIOS         = '{0} ({1})' -f $bios.SMBIOSBIOSVersion, $(if ($bios.ReleaseDate) { $bios.ReleaseDate.ToString('dd.MM.yyyy') } else { '?' })
        SistemDiski  = $sysDisk
        KurulumTarihi= $os.InstallDate.ToString('dd.MM.yyyy')
        CalismaSuresi= '{0} gün {1} saat {2} dk' -f $uptime.Days, $uptime.Hours, $uptime.Minutes
        CpuName      = $cpu.Name.Trim()
        CpuCores     = $cpu.NumberOfCores
        CpuThreads   = $cpu.NumberOfLogicalProcessors
        CpuMhz       = $cpu.MaxClockSpeed
        GpuNames     = @($gpus | ForEach-Object { $_.Name })
        RamBytes     = $ramTotal
        RamModules   = $ram.Count
        OsBuild      = [int]$os.BuildNumber
        OsCaption    = $os.Caption
        IsLaptop     = [bool](Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue)
    }
}

# ---------------------------------------------------------------------
#  DONANIM TANILAMA
# ---------------------------------------------------------------------
function Get-ZDiskHealth {
    $rows = @()
    try {
        foreach ($d in @(Get-PhysicalDisk -ErrorAction Stop)) {
            $rc = $null
            try { $rc = $d | Get-StorageReliabilityCounter -ErrorAction Stop } catch {}
            $rows += [pscustomobject]@{
                Disk = $d.FriendlyName; Tur = "$($d.MediaType)"; Baglanti = "$($d.BusType)"; Boyut = Format-ZSize $d.Size
                Saglik = "$($d.HealthStatus)"; Durum = ($d.OperationalStatus -join ',')
                Sicaklik = $(if ($rc -and $rc.Temperature) { "$($rc.Temperature) °C" } else { '-' })
                MaxSicaklik = $(if ($rc -and $rc.TemperatureMax) { "$($rc.TemperatureMax) °C" } else { '-' })
                Asinma = $(if ($rc -and $null -ne $rc.Wear) { "%$($rc.Wear)" } else { '-' })
                OkumaHata = $(if ($rc) { "$($rc.ReadErrorsUncorrected)" } else { '-' })
                YazmaHata = $(if ($rc) { "$($rc.WriteErrorsUncorrected)" } else { '-' })
                CalismaSaati = $(if ($rc -and $rc.PowerOnHours) { "$($rc.PowerOnHours) sa" } else { '-' })
                _Temp = $(if ($rc) { ConvertTo-ZInt $rc.Temperature } else { 0 })
                _Wear = $(if ($rc -and $null -ne $rc.Wear) { ConvertTo-ZInt $rc.Wear } else { -1 })
                _RErr = $(if ($rc -and $rc.ReadErrorsUncorrected) { ConvertTo-ZNum $rc.ReadErrorsUncorrected } else { 0 })
                _WErr = $(if ($rc -and $rc.WriteErrorsUncorrected) { ConvertTo-ZNum $rc.WriteErrorsUncorrected } else { 0 })
                _Media = "$($d.MediaType)"; _Bus = "$($d.BusType)"; _Health = "$($d.HealthStatus)"
            }
        }
    } catch {}
    $rows
}

function Get-ZRamModules {
    @(Get-CimInstance Win32_PhysicalMemory | ForEach-Object {
            [pscustomobject]@{
                Yuva = $_.DeviceLocator; Banka = $_.BankLabel; Kapasite = Format-ZSize $_.Capacity
                Uretici = ("$($_.Manufacturer)").Trim(); ParcaNo = ("$($_.PartNumber)").Trim()
                NominalHiz = "$($_.Speed) MT/s"; CalisanHiz = "$($_.ConfiguredClockSpeed) MT/s"
                _Cap = ConvertTo-ZNum $_.Capacity; _Speed = ConvertTo-ZInt $_.Speed; _Cfg = ConvertTo-ZInt $_.ConfiguredClockSpeed; _Part = ("$($_.PartNumber)").Trim()
            }
        })
}

function Get-ZCpuTemperature {
    try {
        $t = Get-CimInstance -Namespace root/wmi -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction Stop |
            ForEach-Object { [math]::Round(($_.CurrentTemperature / 10) - 273.15, 1) } |
            Where-Object { $_ -gt 5 -and $_ -lt 125 } | Measure-Object -Maximum
        if ($t.Count -gt 0) { return $t.Maximum }
    } catch {}
    return $null
}

function Test-ZHardware {
    $f = @()
    Write-ZLog 'Diskler ve SMART sağlık verisi okunuyor...'
    foreach ($d in (Get-ZDiskHealth)) {
        if ($d._Health -match 'Unhealthy') {
            $f += New-ZFinding 'KRİTİK' 'Donanım' ("Disk arızalı: " + $d.Disk) 'Windows bu diski SAĞLIKSIZ olarak bildiriyor.' 'Verilerinizi HEMEN yedekleyin ve diski değiştirin.'
        } elseif ($d._Health -match 'Warning') {
            $f += New-ZFinding 'UYARI' 'Donanım' ("Disk sağlık uyarısı: " + $d.Disk) 'SMART uyarısı alındı.' 'Yedek alın, disk sağlığını yakından takip edin.'
        }
        if ($d._RErr -gt 0 -or $d._WErr -gt 0) {
            $f += New-ZFinding 'KRİTİK' 'Donanım' ("Diskte düzeltilemeyen hatalar: " + $d.Disk) ("Okuma: {0}, Yazma: {1}" -f $d._RErr, $d._WErr) 'Disk fiziksel arıza belirtisi gösteriyor. Yedek alın, CHKDSK çalıştırın.' 'CHKDSK_SCHEDULE'
        }
        if ($d._Wear -ge 90) {
            $f += New-ZFinding 'KRİTİK' 'Donanım' ("SSD ömrü bitmek üzere: " + $d.Disk) ("Aşınma: %{0}" -f $d._Wear) 'SSDʼyi kısa süre içinde değiştirin.'
        } elseif ($d._Wear -ge 70) {
            $f += New-ZFinding 'UYARI' 'Donanım' ("SSD aşınması yüksek: " + $d.Disk) ("Aşınma: %{0}" -f $d._Wear) 'Düzenli yedek alın; değişim planlayın.'
        }
        $lim = 60; if ($d._Bus -eq 'NVMe') { $lim = 72 }
        if ($d._Temp -ge $lim) {
            $f += New-ZFinding 'UYARI' 'Donanım' ("Disk sıcaklığı yüksek: " + $d.Disk) ("{0} °C" -f $d._Temp) 'Kasa hava akışını iyileştirin, NVMe için soğutucu kullanın.'
        }
        if ($d._Media -eq 'HDD') {
            $f += New-ZFinding 'BİLGİ' 'Donanım' ("Mekanik disk (HDD): " + $d.Disk) 'HDDʼler SSDʼye göre çok yavaştır.' 'Windows ve oyunları SSD üzerine taşıyın.'
        }
    }
    try {
        $pf = Get-CimInstance -Namespace root/wmi -ClassName MSStorageDriver_FailurePredictStatus -ErrorAction Stop | Where-Object { $_.PredictFailure }
        foreach ($x in $pf) { $f += New-ZFinding 'KRİTİK' 'Donanım' 'SMART arıza tahmini aktif' $x.InstanceName 'Disk yakında arızalanabilir; verileri yedekleyin.' }
    } catch {}

    Write-ZLog 'Aygıt Yöneticisi sorunlu aygıtları taranıyor...'
    foreach ($dev in @(Get-CimInstance Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -and $_.ConfigManagerErrorCode -ne 0 })) {
        $code = ConvertTo-ZInt $dev.ConfigManagerErrorCode
        $desc = $Global:ZDeviceErrors[$code]; if (-not $desc) { $desc = 'Bilinmeyen aygıt hatası' }
        $sev = 'UYARI'; if ($code -in 22, 45) { $sev = 'BİLGİ' }; if ($code -in 43, 10, 39, 31) { $sev = 'KRİTİK' }
        $name = $dev.Name; if (-not $name) { $name = $dev.DeviceID }
        $f += New-ZFinding $sev 'Sürücü' ("Sorunlu aygıt: " + $name) ("Kod {0}: {1}" -f $code, $desc) 'Sürücüyü güncelleyin / yeniden yükleyin. Aygıtları yeniden tarayabilirsiniz.' 'DEVICE_RESCAN' '' 'YENİDEN TARA'
    }

    Write-ZLog 'Bellek (RAM) modülleri analiz ediliyor...'
    $mods = Get-ZRamModules
    $total = ($mods | Measure-Object _Cap -Sum).Sum
    if ($total -gt 0 -and $total -lt 8GB) {
        $f += New-ZFinding 'UYARI' 'Donanım' 'RAM miktarı düşük' (Format-ZSize $total) 'Günümüz için en az 16 GB RAM önerilir.'
    } elseif ($total -gt 0 -and $total -lt 16GB) {
        $f += New-ZFinding 'BİLGİ' 'Donanım' 'RAM oyunlar için sınırda' (Format-ZSize $total) 'Modern oyunlar için 16–32 GB önerilir.'
    }
    if ($mods.Count -eq 1) {
        $f += New-ZFinding 'UYARI' 'Donanım' 'Tek kanal RAM (single channel)' 'Sistemde tek bellek modülü var.' 'Aynı model ikinci modül ekleyerek çift kanala geçin; FPS %10–30 artabilir.'
    }
    if ($mods.Count -ge 2) {
        $caps = @($mods | Select-Object -ExpandProperty _Cap -Unique)
        $parts = @($mods | Where-Object { $_._Part } | Select-Object -ExpandProperty _Part -Unique)
        if ($caps.Count -gt 1 -or $parts.Count -gt 1) {
            $f += New-ZFinding 'BİLGİ' 'Donanım' 'Farklı RAM modülleri karışık takılı' 'Kapasite veya model farkı var.' 'Kararsızlık/mavi ekran yaşıyorsanız aynı kit modüller kullanın.'
        }
    }
    $m0 = $mods | Where-Object { $_._Speed -gt 0 -and $_._Cfg -gt 0 } | Select-Object -First 1
    if ($m0 -and $m0._Cfg -lt ($m0._Speed - 100)) {
        $f += New-ZFinding 'UYARI' 'Donanım' 'RAM nominal hızının altında çalışıyor' ("Nominal {0} → Çalışan {1} MT/s" -f $m0._Speed, $m0._Cfg) 'BIOSʼtan XMP / EXPO profilini etkinleştirin.'
    }

    Write-ZLog 'İşlemci ve ekran kartı kontrol ediliyor...'
    $t = Get-ZCpuTemperature
    if ($t) {
        if ($t -ge 90) { $f += New-ZFinding 'KRİTİK' 'Donanım' 'Sistem sıcaklığı çok yüksek' ("{0} °C (ACPI)" -f $t) 'Soğutucu/termal macun, fanlar ve toz kontrolü yapın.' }
        elseif ($t -ge 80) { $f += New-ZFinding 'UYARI' 'Donanım' 'Sistem sıcaklığı yüksek' ("{0} °C (ACPI)" -f $t) 'Kasa içi temizlik ve fan eğrisini kontrol edin.' }
    }
    foreach ($g in @(Get-CimInstance Win32_VideoController)) {
        if ($g.Name -match 'Microsoft Basic Display|Microsoft Temel Görüntü') {
            $f += New-ZFinding 'KRİTİK' 'Sürücü' 'Ekran kartı sürücüsü yüklü değil' $g.Name 'Ekran kartı üreticisinin sitesinden sürücüyü kurun.' 'GPU_DRIVER' $g.Name 'SÜRÜCÜ SAYFASI'
            continue
        }
        if ($g.Status -and $g.Status -ne 'OK') { $f += New-ZFinding 'UYARI' 'Donanım' ("Ekran kartı durumu: " + $g.Status) $g.Name 'Sürücüyü yeniden kurun, güç kablolarını kontrol edin.' }
    }


    if (Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue) {
        Write-ZLog 'Pil sağlığı ölçülüyor...'
        $xml = Join-Path $env:TEMP 'zetx-battery.xml'
        try {
            & powercfg /batteryreport /xml /output "$xml" 2>&1 | Out-Null
            if (Test-Path $xml) {
                [xml]$bx = Get-Content $xml -Raw
                $b = $bx.BatteryReport.Batteries.Battery | Select-Object -First 1
                $design = ConvertTo-ZNum $b.DesignCapacity; $full = ConvertTo-ZNum $b.FullChargeCapacity
                if ($design -gt 0) {
                    $health = ConvertTo-ZInt ($full / $design * 100)
                    $sev = 'İYİ'; if ($health -lt 60) { $sev = 'KRİTİK' } elseif ($health -lt 80) { $sev = 'UYARI' }
                    $f += New-ZFinding $sev 'Donanım' ("Pil sağlığı: %{0}" -f $health) ("Tasarım {0:N0} mWh → Şu an {1:N0} mWh, Döngü: {2}" -f $design, $full, $b.CycleCount) 'Pil %60ʼın altındaysa değişim önerilir.' 'BATTERY_REPORT' '' 'PİL RAPORU'
                }
                Remove-Item $xml -Force -ErrorAction SilentlyContinue
            }
        } catch {}
    }

    try {
        $md = Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-MemoryDiagnostics-Results' } -MaxEvents 1 -ErrorAction Stop
        if ($md) {
            $sev = 'BİLGİ'; if ($md.Id -eq 1202 -or $md.Message -match 'donanım sorun|hardware problem|hata algıla|errors? (were )?detected') { $sev = 'KRİTİK' }
            if ($md.Message -match 'hata algılanmadı|no errors') { $sev = 'İYİ' }
            $f += New-ZFinding $sev 'Donanım' 'Son Windows Bellek Tanılama sonucu' (($md.TimeCreated.ToString('dd.MM.yyyy') + ' — ' + ($md.Message -replace '\s+', ' '))) 'RAM hatası bulunduysa modülleri tek tek test edin.'
        }
    } catch {}
    $f
}

# ---------------------------------------------------------------------
#  SİSTEM ARIZALARI (OLAY GÜNLÜKLERİ)
# ---------------------------------------------------------------------
function Get-ZEvents {
    param([hashtable]$Filter, [int]$Max = 500)
    try { @(Get-WinEvent -FilterHashtable $Filter -MaxEvents $Max -ErrorAction Stop) } catch { @() }
}

function Get-ZCrashHistory {
    param([int]$Days = 30)
    $start = (Get-Date).AddDays(-$Days)
    $rows = @()
    foreach ($e in (Get-ZEvents @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-WER-SystemErrorReporting'; Id = 1001; StartTime = $start } 100)) {
        $code = $null
        $m = [regex]::Match(($e.Properties | ForEach-Object { "$($_.Value)" }) -join ' ', '0x[0-9a-fA-F]{8}')
        if ($m.Success) { try { $code = [Convert]::ToInt64($m.Value, 16) } catch { $code = $null } }
        $rows += [pscustomobject]@{ Tarih = $e.TimeCreated; Tur = 'MAVİ EKRAN'; Kod = $code; Aciklama = '' }
    }
    foreach ($e in (Get-ZEvents @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-Kernel-Power'; Id = 41; StartTime = $start } 100)) {
        $bc = 0; try { $bc = [int64](ConvertTo-ZNum $e.Properties[0].Value) } catch {}
        $dup = $rows | Where-Object { [math]::Abs(($_.Tarih - $e.TimeCreated).TotalMinutes) -lt 10 }
        if (-not $dup) { $rows += [pscustomobject]@{ Tarih = $e.TimeCreated; Tur = $(if ($bc -ne 0) { 'MAVİ EKRAN' } else { 'ANİ KAPANMA' }); Kod = $(if ($bc -ne 0) { $bc } else { $null }); Aciklama = '' } }
    }
    foreach ($r in $rows) {
        if ($r.Kod) {
            $info = $null; if ([int64]$r.Kod -le [int]::MaxValue) { $info = $Global:ZBugChecks[[int]$r.Kod] }
            if ($info) { $r.Aciklama = '{0} — {1}' -f $info[0], $info[1] } else { $r.Aciklama = ('Durdurma kodu 0x{0:X}' -f [int64]$r.Kod) }
        } elseif ($r.Tur -eq 'ANİ KAPANMA') { $r.Aciklama = 'Elektrik kesintisi, güç kaynağı (PSU), aşırı ısınma veya güç tuşu ile zorla kapatma.' }
    }
    $rows | Sort-Object Tarih -Descending
}

function Test-ZSystemErrors {
    param([int]$Days = 30)
    $f = @()
    $start = (Get-Date).AddDays(-$Days)
    Write-ZLog ("Son {0} günün olay günlükleri inceleniyor..." -f $Days)

    $crashes = @(Get-ZCrashHistory -Days $Days)
    $bsod = @($crashes | Where-Object { $_.Tur -eq 'MAVİ EKRAN' })
    $sudden = @($crashes | Where-Object { $_.Tur -eq 'ANİ KAPANMA' })
    if ($bsod.Count -gt 0) {
        $grp = $bsod | Group-Object Aciklama | Sort-Object Count -Descending | Select-Object -First 3
        $det = ($grp | ForEach-Object { '{0}× {1}' -f $_.Count, $_.Name }) -join ' | '
        $sev = 'UYARI'; if ($bsod.Count -ge 3) { $sev = 'KRİTİK' }
        $f += New-ZFinding $sev 'Sistem' ("{0} mavi ekran (BSOD) kaydı" -f $bsod.Count) $det 'Sistem Arızaları sekmesindeki çözüm önerilerini uygulayın; SFC + DISM ve bellek testi önerilir.' 'SFC' '' 'SFC ÇALIŞTIR'
    }
    if ($sudden.Count -gt 0) {
        $sev = 'BİLGİ'; if ($sudden.Count -ge 3) { $sev = 'UYARI' }
        $f += New-ZFinding $sev 'Sistem' ("{0} beklenmedik kapanma" -f $sudden.Count) 'Sistem düzgün kapatılmadan yeniden başladı.' 'Güç kaynağını (PSU), prizi/UPSʼi, sıcaklıkları kontrol edin.'
    }

    $whea = Get-ZEvents @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-WHEA-Logger'; StartTime = $start } 300
    if ($whea.Count -gt 0) {
        $fatal = @($whea | Where-Object { $_.Id -in 1, 18, 20, 46 }).Count
        $corr = $whea.Count - $fatal
        $sev = 'UYARI'; if ($fatal -gt 0 -or $corr -gt 50) { $sev = 'KRİTİK' }
        $f += New-ZFinding $sev 'Donanım' ("WHEA donanım hatası: {0} ölümcül, {1} düzeltilmiş" -f $fatal, $corr) 'İşlemci, RAM, PCIe veya anakart seviyesinde donanım hatası raporlandı.' 'Hız aşırtma/XMPʼyi kapatıp test edin, BIOS güncelleyin, sıcaklık ve güç kaynağını kontrol edin.'
    }

    $tdr = Get-ZEvents @{ LogName = 'System'; ProviderName = 'Display'; Id = 4101; StartTime = $start } 200
    if ($tdr.Count -gt 0) {
        $f += New-ZFinding $(if ($tdr.Count -ge 3) { 'UYARI' } else { 'BİLGİ' }) 'Sürücü' ("Ekran kartı sürücüsü {0} kez yanıt vermeyi durdurdu" -f $tdr.Count) 'Görüntü sürücüsü kurtarıldı (TDR, olay 4101).' 'GPU sürücüsünü DDU ile temiz kurun; GPU hız aşırtmasını kaldırın, sıcaklığı kontrol edin.' 'GPU_DRIVER' '' 'SÜRÜCÜ SAYFASI'
    }

    $diskEv = @()
    $diskEv += Get-ZEvents @{ LogName = 'System'; ProviderName = 'disk'; Id = 7, 11, 51, 153; StartTime = $start } 300
    $diskEv += Get-ZEvents @{ LogName = 'System'; ProviderName = 'Ntfs', 'Microsoft-Windows-Ntfs'; Id = 55, 98, 137, 140; StartTime = $start } 300
    if ($diskEv.Count -gt 0) {
        $bad = @($diskEv | Where-Object { $_.ProviderName -eq 'disk' -and $_.Id -in 7, 11, 51 }).Count
        $sev = 'UYARI'; if ($bad -gt 0) { $sev = 'KRİTİK' }
        $f += New-ZFinding $sev 'Disk' ("{0} disk / dosya sistemi hata kaydı" -f $diskEv.Count) ("Bozuk sektör / G-Ç hatası: {0}" -f $bad) 'Disk kablosunu kontrol edin, CHKDSK çalıştırın, SMART sağlığını izleyin, yedek alın.' 'CHKDSK_SCAN' '' 'CHKDSK TARA'
    }

    $app = Get-ZEvents @{ LogName = 'Application'; ProviderName = 'Application Error'; Id = 1000; StartTime = $start } 500
    if ($app.Count -gt 0) {
        $items = $app | ForEach-Object {
            $mod = ''; try { $mod = "$($_.Properties[3].Value)" } catch {}
            [pscustomobject]@{ App = "$($_.Properties[0].Value)"; Mod = $mod }
        }
        foreach ($g in ($items | Group-Object App | Sort-Object Count -Descending | Select-Object -First 5)) {
            $mods = ($g.Group | Group-Object Mod | Sort-Object Count -Descending | Select-Object -First 1).Name
            $hint = ''
            foreach ($k in $Global:ZModuleHints.Keys) { if ($mods -and $mods.ToLower().Contains($k)) { $hint = $Global:ZModuleHints[$k]; break } }
            $adv = 'Programı güncelleyin veya onarın.'
            if ($hint -match 'ekran kartı|grafik|DirectX') { $adv = 'Hata ekran kartı sürücüsünden kaynaklanıyor olabilir: sürücüyü temiz kurun.' }
            elseif ($hint -match 'Visual C\+\+|C çalışma') { $adv = 'Visual C++ Yeniden Dağıtılabilir paketlerini yeniden kurun.' }
            elseif ($hint -match '\.NET') { $adv = '.NET çalışma zamanını onarın/güncelleyin.' }
            $sev = 'BİLGİ'; if ($g.Count -ge 5) { $sev = 'UYARI' }
            $f += New-ZFinding $sev 'Uygulama' ("{0} — {1} kez çöktü" -f $g.Name, $g.Count) ("Hatalı modül: {0} {1}" -f $mods, $(if ($hint) { "($hint)" } else { '' })) $adv
        }
    }

    $svc = Get-ZEvents @{ LogName = 'System'; ProviderName = 'Service Control Manager'; Id = 7031, 7034; StartTime = $start } 300
    if ($svc.Count -gt 0) {
        foreach ($g in ($svc | ForEach-Object { "$($_.Properties[0].Value)" } | Group-Object | Sort-Object Count -Descending | Select-Object -First 3)) {
            $f += New-ZFinding $(if ($g.Count -ge 5) { 'UYARI' } else { 'BİLGİ' }) 'Hizmet' ("Hizmet beklenmedik şekilde sonlandı: {0}" -f $g.Name) ("{0} kez" -f $g.Count) 'Hizmete ait programı güncelleyin; sistem dosyası onarımı yapın.'
        }
    }

    $wu = Get-ZEvents @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-WindowsUpdateClient'; Id = 20; StartTime = $start } 100
    if ($wu.Count -gt 0) {
        $f += New-ZFinding $(if ($wu.Count -ge 3) { 'UYARI' } else { 'BİLGİ' }) 'Güncelleme' ("{0} Windows Update kurulum hatası" -f $wu.Count) (($wu | Select-Object -First 1).Message -replace '\s+', ' ') 'Windows Update bileşenlerini sıfırlayın.' 'WU_RESET' '' 'WU SIFIRLA'
    }

    $mdDir = Join-Path $env:SystemRoot 'Minidump'
    if (Test-Path $mdDir) {
        $dumps = @(Get-ChildItem $mdDir -Filter *.dmp -ErrorAction SilentlyContinue)
        if ($dumps.Count -gt 0) {
            $f += New-ZFinding 'BİLGİ' 'Sistem' ("{0} çökme döküm dosyası (minidump)" -f $dumps.Count) ("Son: {0}" -f ($dumps | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime.ToString('dd.MM.yyyy HH:mm')) 'Çökme analizi için WinDbg kullanılabilir; Temizlik sekmesinden silinebilir.'
        }
    }
    $f
}

# ---------------------------------------------------------------------
#  WINDOWS DURUMU (güvenlik, güncelleme, disk alanı, hizmetler...)
# ---------------------------------------------------------------------
function Test-ZWindowsState {
    $f = @()
    Write-ZLog 'Windows durumu kontrol ediliyor...'
    $os = Get-CimInstance Win32_OperatingSystem
    if ($os.Caption -match 'Windows 10') {
        $f += New-ZFinding 'UYARI' 'Windows' 'Windows 10 desteği sona erdi' 'Microsoft, Windows 10 için standart desteği 14 Ekim 2025ʼte sonlandırdı.' 'Güvenlik için Windows 11ʼe yükseltin veya Genişletilmiş Güvenlik Güncellemeleri (ESU) programına katılın.'
    }
    try {
        $lic = Get-CimInstance SoftwareLicensingProduct -Filter "PartialProductKey IS NOT NULL AND ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f'" -ErrorAction Stop | Select-Object -First 1
        if ($lic -and $lic.LicenseStatus -ne 1) { $f += New-ZFinding 'UYARI' 'Windows' 'Windows etkinleştirilmemiş' ("Durum kodu: {0}" -f $lic.LicenseStatus) 'Ayarlar > Etkinleştirme bölümünden Windowsʼu etkinleştirin.' }
    } catch {}

    foreach ($ld in @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3')) {
        if (-not $ld.Size) { continue }
        $pct = [math]::Round($ld.FreeSpace / $ld.Size * 100)
        if ($pct -lt 10) { $f += New-ZFinding 'KRİTİK' 'Disk' ("{0} sürücüsünde yer çok az" -f $ld.DeviceID) ("Boş: {0} (%{1})" -f (Format-ZSize $ld.FreeSpace), $pct) 'Temizlik yapın; Windows en az %15 boş alan ister.' 'TEMP_CLEAN' '' 'TEMİZLE' }
        elseif ($pct -lt 20) { $f += New-ZFinding 'UYARI' 'Disk' ("{0} sürücüsünde yer azalıyor" -f $ld.DeviceID) ("Boş: {0} (%{1})" -f (Format-ZSize $ld.FreeSpace), $pct) 'Gereksiz dosyaları temizleyin.' 'TEMP_CLEAN' '' 'TEMİZLE' }
    }

    $reboot = $false
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') { $reboot = $true }
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') { $reboot = $true }
    if ($reboot) { $f += New-ZFinding 'UYARI' 'Windows' 'Yeniden başlatma bekleniyor' 'Güncelleme veya kurulum yeniden başlatmayı bekliyor.' 'Bilgisayarı yeniden başlatın; bekleyen işlem onarımları engelleyebilir.' }

    $up = (Get-Date) - $os.LastBootUpTime
    if ($up.TotalDays -gt 7) { $f += New-ZFinding 'BİLGİ' 'Windows' ("Sistem {0} gündür yeniden başlatılmadı" -f [int]$up.TotalDays) '' 'Ara sıra yeniden başlatmak bellek sızıntılarını ve yavaşlamayı giderir.' }

    try {
        $hf = Get-HotFix -ErrorAction Stop | Where-Object { $_.InstalledOn } | Sort-Object InstalledOn -Descending | Select-Object -First 1
        if ($hf -and ((Get-Date) - $hf.InstalledOn).Days -gt 60) { $f += New-ZFinding 'UYARI' 'Güncelleme' 'Windows uzun süredir güncellenmemiş' ("Son güncelleme: {0} ({1})" -f $hf.InstalledOn.ToString('dd.MM.yyyy'), $hf.HotFixID) 'Windows Updateʼi çalıştırın.' 'OPEN_WU' '' 'AÇ' }
    } catch {}

    $avOk = $false
    try {
        $avs = @(Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntivirusProduct -ErrorAction Stop)
        foreach ($a in $avs) { $st = ConvertTo-ZInt $a.productState; if ((($st -shr 12) -band 0xF) -in 1, 3) { $avOk = $true } }
    } catch { $avOk = $true }
    try {
        $mp = Get-MpComputerStatus -ErrorAction Stop
        if ($mp.AntivirusEnabled -and -not $mp.RealTimeProtectionEnabled -and -not $avOk) {
            $f += New-ZFinding 'KRİTİK' 'Güvenlik' 'Gerçek zamanlı koruma kapalı' 'Microsoft Defender gerçek zamanlı koruması devre dışı.' 'Windows Güvenliğiʼnden gerçek zamanlı korumayı açın.' 'OPEN_DEFENDER' '' 'AÇ'
        }
        if ($mp.AntivirusEnabled -and $mp.AntivirusSignatureAge -gt 7) {
            $f += New-ZFinding 'UYARI' 'Güvenlik' 'Virüs tanımları güncel değil' ("{0} gün eski" -f $mp.AntivirusSignatureAge) 'Tanımları güncelleyin.' 'DEFENDER_UPDATE' '' 'GÜNCELLE'
        }
        if ($mp.AntivirusEnabled -and $mp.QuickScanAge -gt 14) {
            $f += New-ZFinding 'BİLGİ' 'Güvenlik' 'Uzun süredir virüs taraması yapılmamış' ("Son hızlı tarama: {0} gün önce" -f $mp.QuickScanAge) 'Hızlı tarama başlatın.' 'DEFENDER_SCAN' '' 'TARA'
        }
    } catch {}
    if (-not $avOk) { $f += New-ZFinding 'KRİTİK' 'Güvenlik' 'Etkin antivirüs bulunamadı' '' 'Microsoft Defenderʼı veya bir antivirüs programını etkinleştirin.' 'OPEN_DEFENDER' '' 'AÇ' }

    try {
        foreach ($fp in @(Get-NetFirewallProfile -ErrorAction Stop | Where-Object { -not $_.Enabled })) {
            $f += New-ZFinding 'UYARI' 'Güvenlik' ("Güvenlik duvarı kapalı: {0} profili" -f $fp.Name) '' 'Güvenlik duvarını açın.' 'FIREWALL_ON' $fp.Name 'AÇ'
        }
    } catch {}

    $critical = @{ 'Winmgmt' = 'WMI'; 'EventLog' = 'Olay Günlüğü'; 'Dhcp' = 'DHCP İstemcisi'; 'Dnscache' = 'DNS İstemcisi'; 'RpcSs' = 'RPC'; 'CryptSvc' = 'Şifreleme Hizmetleri'; 'Audiosrv' = 'Windows Ses'; 'AudioEndpointBuilder' = 'Ses Uç Noktası'; 'mpssvc' = 'Güvenlik Duvarı'; 'LanmanWorkstation' = 'İş İstasyonu'; 'Themes' = 'Temalar' }
    foreach ($k in $critical.Keys) {
        $s = Get-Service -Name $k -ErrorAction SilentlyContinue
        if ($s -and ($s.Status -ne 'Running' -or "$($s.StartType)" -eq 'Disabled')) {
            $f += New-ZFinding 'UYARI' 'Hizmet' ("Önemli hizmet çalışmıyor: {0} ({1})" -f $critical[$k], $k) ("Durum: {0}, Başlangıç: {1}" -f $s.Status, $s.StartType) 'Hizmeti otomatik başlatmaya alıp çalıştırın.' 'SERVICE_FIX' $k 'BAŞLAT'
        }
    }
    foreach ($k in @('wuauserv', 'BITS')) {
        $s = Get-Service -Name $k -ErrorAction SilentlyContinue
        if ($s -and "$($s.StartType)" -eq 'Disabled') { $f += New-ZFinding 'UYARI' 'Güncelleme' ("Güncelleme hizmeti devre dışı: {0}" -f $k) '' 'Güvenlik güncellemeleri için hizmeti el ile başlatmaya alın.' 'SERVICE_MANUAL' $k 'ETKİNLEŞTİR' }
    }

    try {
        $cs = Get-CimInstance Win32_ComputerSystem
        $pfu = @(Get-CimInstance Win32_PageFileUsage -ErrorAction SilentlyContinue)
        if (-not $cs.AutomaticManagedPagefile -and $pfu.Count -eq 0) {
            $f += New-ZFinding 'UYARI' 'Windows' 'Sanal bellek (sayfa dosyası) kapalı' 'Pagefile yok.' 'Oyun çökmeleri ve "yetersiz bellek" hatalarına yol açar. Otomatik yönetime alın.' 'PAGEFILE_AUTO' '' 'OTOMATİK YAP'
        }
    } catch {}

    try {
        $scheme = (& powercfg /getactivescheme) -join ' '
        if ($scheme -match 'a1841308-3541-4fab-bc81-f71556f20b4a') {
            $f += New-ZFinding 'UYARI' 'Performans' 'Güç planı: Güç Tasarrufu' 'İşlemci hızı kısıtlanıyor.' 'Yüksek Performans planına geçin.' 'POWER_HIGH' '' 'YÜKSEK PERF.'
        } elseif ($scheme -match '381b4222-f694-41f0-9685-ff5bb260df2e' -and -not (Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue)) {
            $f += New-ZFinding 'BİLGİ' 'Performans' 'Güç planı: Dengeli' 'Masaüstü bilgisayarda Yüksek Performans daha tutarlı saat hızı sağlar.' 'Yüksek Performans planına geçebilirsiniz.' 'POWER_HIGH' '' 'YÜKSEK PERF.'
        }
    } catch {}

    $tempSize = 0
    foreach ($p in @($env:TEMP, (Join-Path $env:SystemRoot 'Temp'))) {
        try { $tempSize += (Get-ChildItem $p -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum } catch {}
    }
    if ($tempSize -gt 2GB) { $f += New-ZFinding 'BİLGİ' 'Temizlik' ('Geçici dosyalar: ' + (Format-ZSize $tempSize)) '' 'Temizlik sekmesinden silin.' 'TEMP_CLEAN' '' 'TEMİZLE' }

    $startup = @(Get-ZStartupItems | Where-Object { $_.Durum -eq 'Etkin' })
    if ($startup.Count -gt 12) { $f += New-ZFinding 'UYARI' 'Performans' ("Başlangıçta {0} program açılıyor" -f $startup.Count) '' 'Açılışı hızlandırmak için gereksizleri Temizlik > Başlangıç bölümünden kapatın.' }
    elseif ($startup.Count -gt 8) { $f += New-ZFinding 'BİLGİ' 'Performans' ("Başlangıçta {0} program açılıyor" -f $startup.Count) '' 'Gereksiz başlangıç programlarını kapatabilirsiniz.' }

    try {
        $wmi = (& winmgmt /verifyrepository) -join ' '
        if ($wmi -match 'inconsistent|tutarsız|tutarlı değil') { $f += New-ZFinding 'KRİTİK' 'Windows' 'WMI deposu bozuk' $wmi 'WMI deposunu onarın.' 'WMI_REPAIR' '' 'ONAR' }
    } catch {}
    $f
}

# ---------------------------------------------------------------------
#  KAYIT DEFTERİ
# ---------------------------------------------------------------------
function Get-ZExePath {
    param([string]$Command)
    if (-not $Command) { return $null }
    $c = [Environment]::ExpandEnvironmentVariables($Command.Trim())
    if ($c.StartsWith('"')) {
        $end = $c.IndexOf('"', 1); if ($end -gt 1) { return $c.Substring(1, $end - 1) }
    }
    $m = [regex]::Match($c, '^(.+?\.(exe|bat|cmd|com|vbs|ps1|lnk|scr|dll))(\s|,|$)', 'IgnoreCase')
    if ($m.Success) { return $m.Groups[1].Value.Trim() }
    return ($c -split '\s')[0]
}

function Test-ZPathExists {
    param([string]$Path)
    if (-not $Path) { return $true }
    if ($Path -notmatch '^[a-zA-Z]:\\') { return $true }   # göreli/sistem komutu: varsay
    if (Test-Path -LiteralPath $Path) { return $true }
    if ($Path -match '\\System32\\' -and (Test-Path -LiteralPath ($Path -replace '\\System32\\', '\Sysnative\'))) { return $true }
    return $false
}

function Get-ZRegistryIssues {
    $issues = New-Object System.Collections.ArrayList
    Write-ZLog 'Kayıt defteri: başlangıç girdileri taranıyor...'
    $runKeys = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run', 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce'
    )
    foreach ($k in $runKeys) {
        if (-not (Test-Path $k)) { continue }
        $item = Get-Item $k
        foreach ($n in $item.GetValueNames()) {
            if (-not $n) { continue }
            $v = "$($item.GetValue($n))"; $exe = Get-ZExePath $v
            if (-not (Test-ZPathExists $exe)) {
                [void]$issues.Add([pscustomobject]@{ Sec = $true; Kategori = 'Bozuk başlangıç girdisi'; Anahtar = $k; Deger = $n; Bilgi = $v; Tip = 'Value' })
            }
        }
    }

    Write-ZLog 'Kayıt defteri: yetim kaldırma (uninstall) kayıtları taranıyor...'
    $unKeys = @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall')
    foreach ($k in $unKeys) {
        if (-not (Test-Path $k)) { continue }
        foreach ($sub in Get-ChildItem $k -ErrorAction SilentlyContinue) {
            $p = Get-ItemProperty $sub.PSPath -ErrorAction SilentlyContinue
            if (-not $p -or -not $p.DisplayName -or $p.SystemComponent -eq 1) { continue }
            $us = "$($p.UninstallString)"
            if (-not $us -or $us -match 'msiexec') { continue }
            $exe = Get-ZExePath $us
            $loc = "$($p.InstallLocation)"
            $locMissing = ($loc -and $loc -match '^[a-zA-Z]:\\' -and -not (Test-Path -LiteralPath $loc))
            if (-not (Test-ZPathExists $exe) -and ($locMissing -or -not $loc)) {
                [void]$issues.Add([pscustomobject]@{ Sec = $true; Kategori = 'Yetim program kaydı'; Anahtar = ($sub.PSPath -replace '^Microsoft\.PowerShell\.Core\\Registry::', '' -replace '^HKEY_LOCAL_MACHINE', 'HKLM:' -replace '^HKEY_CURRENT_USER', 'HKCU:'); Deger = '(anahtar)'; Bilgi = "$($p.DisplayName) — $exe"; Tip = 'Key' })
            }
        }
    }

    Write-ZLog 'Kayıt defteri: App Paths ve paylaşılan DLL kayıtları taranıyor...'
    $ap = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths'
    if (Test-Path $ap) {
        foreach ($sub in Get-ChildItem $ap -ErrorAction SilentlyContinue) {
            $v = "$($sub.GetValue(''))"; if (-not $v) { continue }
            $exe = Get-ZExePath $v
            if (-not (Test-ZPathExists $exe)) {
                [void]$issues.Add([pscustomobject]@{ Sec = $true; Kategori = 'Geçersiz uygulama yolu'; Anahtar = ($ap + '\' + $sub.PSChildName); Deger = '(anahtar)'; Bilgi = $v; Tip = 'Key' })
            }
        }
    }
    $sd = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\SharedDLLs'
    if (Test-Path $sd) {
        $item = Get-Item $sd
        foreach ($n in $item.GetValueNames()) {
            if ($n -match '^[a-zA-Z]:\\' -and -not (Test-Path -LiteralPath $n)) {
                [void]$issues.Add([pscustomobject]@{ Sec = $true; Kategori = 'Eksik paylaşılan DLL'; Anahtar = $sd; Deger = $n; Bilgi = $n; Tip = 'Value' })
            }
        }
    }

    Write-ZLog 'Kayıt defteri: MUI önbelleği taranıyor...'
    $mui = 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache'
    if (Test-Path $mui) {
        $item = Get-Item $mui
        foreach ($n in $item.GetValueNames()) {
            $path = $n -replace '\.(FriendlyAppName|ApplicationCompany)$', ''
            if ($path -match '^[a-zA-Z]:\\' -and -not (Test-Path -LiteralPath $path)) {
                [void]$issues.Add([pscustomobject]@{ Sec = $true; Kategori = 'Eski uygulama önbelleği (MUI)'; Anahtar = $mui; Deger = $n; Bilgi = $path; Tip = 'Value' })
            }
        }
    }

    Write-ZLog 'Kayıt defteri: başlangıç klasörü kısayolları taranıyor...'
    try {
        $sh = New-Object -ComObject WScript.Shell
        foreach ($dir in @([Environment]::GetFolderPath('Startup'), [Environment]::GetFolderPath('CommonStartup'))) {
            foreach ($lnk in @(Get-ChildItem $dir -Filter *.lnk -ErrorAction SilentlyContinue)) {
                $t = $sh.CreateShortcut($lnk.FullName).TargetPath
                if ($t -and -not (Test-ZPathExists $t)) {
                    [void]$issues.Add([pscustomobject]@{ Sec = $true; Kategori = 'Bozuk başlangıç kısayolu'; Anahtar = $lnk.FullName; Deger = '(dosya)'; Bilgi = $t; Tip = 'File' })
                }
            }
        }
    } catch {}
    Write-ZLog ("Kayıt defteri taraması bitti: {0} sorun." -f $issues.Count) 'OK'
    $issues.ToArray()
}

function Convert-ZRegPath { param([string]$Path)
    $Path -replace '^HKCU:\\', 'HKCU\' -replace '^HKLM:\\', 'HKLM\' -replace '^HKCU:', 'HKCU' -replace '^HKLM:', 'HKLM'
}

function Backup-ZRegKey {
    param([string]$Key, [string]$Tag = 'yedek')
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $safe = ($Tag -replace '[^\w\-]', '_')
    $file = Join-Path $Global:ZBackupDir ("{0}_{1}_{2}.reg" -f $stamp, $safe, ([guid]::NewGuid().ToString('N').Substring(0, 6)))
    & reg.exe export (Convert-ZRegPath $Key) "$file" /y 2>&1 | Out-Null
    if (Test-Path $file) { return $file } else { return $null }
}

function Remove-ZRegistryIssues {
    param([object[]]$Items)
    $done = 0; $fail = 0; $backed = @{}
    foreach ($it in $Items) {
        try {
            if ($it.Tip -eq 'File') {
                $dst = Join-Path $Global:ZBackupDir ('kisayol_' + (Split-Path $it.Anahtar -Leaf))
                Copy-Item -LiteralPath $it.Anahtar -Destination $dst -Force -ErrorAction SilentlyContinue
                Remove-Item -LiteralPath $it.Anahtar -Force -ErrorAction Stop
            } else {
                if (-not $backed.ContainsKey($it.Anahtar)) {
                    $b = Backup-ZRegKey $it.Anahtar ($it.Kategori)
                    if (-not $b) { throw 'Yedek alınamadı, silme iptal.' }
                    $backed[$it.Anahtar] = $b
                }
                if ($it.Tip -eq 'Key') { Remove-Item -LiteralPath $it.Anahtar -Recurse -Force -ErrorAction Stop }
                else { Remove-ItemProperty -LiteralPath $it.Anahtar -Name $it.Deger -Force -ErrorAction Stop }
            }
            $done++; Write-ZLog ("Temizlendi: {0} → {1}" -f $it.Kategori, $it.Bilgi) 'OK'
        } catch { $fail++; Write-ZLog ("Temizlenemedi: {0} ({1})" -f $it.Bilgi, $_.Exception.Message) 'ERR' }
    }
    Write-ZLog ("Kayıt defteri temizliği: {0} başarılı, {1} hata. Yedekler: {2}" -f $done, $fail, $Global:ZBackupDir) 'OK'
    [pscustomobject]@{ Done = $done; Fail = $fail }
}

function Test-ZSecurityTamper {
    # Kötü amaçlı yazılımların sık değiştirdiği kayıt defteri noktaları
    $f = @()
    Write-ZLog 'Sistem ele geçirme (hijack) noktaları kontrol ediliyor...'
    $wl = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    try {
        $p = Get-ItemProperty $wl -ErrorAction Stop
        if ("$($p.Shell)".Trim().ToLower() -notin @('explorer.exe', 'explorer')) {
            $f += New-ZFinding 'KRİTİK' 'Güvenlik' 'Winlogon Shell değiştirilmiş' ("Shell = {0}" -f $p.Shell) 'Değer explorer.exe olmalı. Kötü amaçlı yazılım belirtisi olabilir.' 'WINLOGON_SHELL' '' 'DÜZELT'
        }
        $ui = "$($p.Userinit)".Trim().TrimEnd(',').ToLower()
        if ($ui -notmatch '^[a-z]:\\windows\\system32\\userinit\.exe$') {
            $f += New-ZFinding 'KRİTİK' 'Güvenlik' 'Winlogon Userinit değiştirilmiş' ("Userinit = {0}" -f $p.Userinit) 'Değer C:\Windows\system32\userinit.exe, olmalı.' 'WINLOGON_USERINIT' '' 'DÜZELT'
        }
    } catch {}
    $ifeo = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options'
    foreach ($sub in @(Get-ChildItem $ifeo -ErrorAction SilentlyContinue)) {
        $dbg = $sub.GetValue('Debugger')
        if ($dbg) {
            $sev = 'UYARI'; if ($sub.PSChildName -match '^(taskmgr|regedit|cmd|explorer|msconfig|mmc|sethc|utilman|osk)\.exe$' -and "$dbg" -notmatch 'procexp|systeminformer|processhacker') { $sev = 'KRİTİK' }
            $f += New-ZFinding $sev 'Güvenlik' ("Program yönlendirmesi (IFEO): {0}" -f $sub.PSChildName) ("Debugger = {0}" -f $dbg) 'Siz eklemediyseniz kaldırın (Process Explorer gibi araçlar meşru olabilir).' 'REG_DEL_VALUE' (($ifeo + '\' + $sub.PSChildName) + '|Debugger') 'KALDIR'
        }
    }
    $pol = @(
        @{ K = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System'; V = 'DisableTaskMgr'; T = 'Görev Yöneticisi engellenmiş' },
        @{ K = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\System'; V = 'DisableRegistryTools'; T = 'Kayıt Defteri Düzenleyicisi engellenmiş' },
        @{ K = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'; V = 'DisableTaskMgr'; T = 'Görev Yöneticisi engellenmiş (tüm kullanıcılar)' },
        @{ K = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'; V = 'DisableRegistryTools'; T = 'Kayıt Defteri engellenmiş (tüm kullanıcılar)' },
        @{ K = 'HKCU:\Software\Policies\Microsoft\Windows\System'; V = 'DisableCMD'; T = 'Komut İstemi engellenmiş' },
        @{ K = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer'; V = 'NoRun'; T = 'Çalıştır penceresi engellenmiş' },
        @{ K = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer'; V = 'NoControlPanel'; T = 'Denetim Masası engellenmiş' },
        @{ K = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer'; V = 'NoFolderOptions'; T = 'Klasör Seçenekleri engellenmiş' }
    )
    foreach ($x in $pol) {
        try { $v = (Get-ItemProperty $x.K -Name $x.V -ErrorAction Stop).($x.V); if ($v -and (ConvertTo-ZInt $v) -ne 0) {
                $f += New-ZFinding 'UYARI' 'Güvenlik' $x.T ("{0}\{1} = {2}" -f $x.K, $x.V, $v) 'Kurumsal bir ilke değilse kaldırın; virüs taraması yapın.' 'REG_DEL_VALUE' ($x.K + '|' + $x.V) 'KALDIR' } } catch {}
    }
    try {
        $w = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows' -ErrorAction Stop
        if ($w.LoadAppInit_DLLs -eq 1 -and "$($w.AppInit_DLLs)".Trim()) {
            $f += New-ZFinding 'UYARI' 'Güvenlik' 'AppInit_DLLs etkin' ("{0}" -f $w.AppInit_DLLs) 'Her programa DLL enjekte edilir. Tanımıyorsanız kaldırın.' 'APPINIT_OFF' '' 'KAPAT'
        }
    } catch {}
    $hosts = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
    try {
        $lines = @(Get-Content $hosts -ErrorAction Stop | Where-Object { $_ -match '^\s*\d' -and $_ -notmatch '^\s*(127\.0\.0\.1|::1)\s+localhost\s*$' })
        if ($lines.Count -gt 0) {
            $sev = 'BİLGİ'
            if ($lines -match 'google|microsoft|windowsupdate|facebook|instagram|bank|steam|epicgames|youtube') { $sev = 'UYARI' }
            $f += New-ZFinding $sev 'Güvenlik' ("HOSTS dosyasında {0} özel kayıt" -f $lines.Count) (($lines | Select-Object -First 3) -join ' ; ') 'Siz eklemediyseniz HOSTS dosyasını varsayılana döndürün (yedek alınır).' 'HOSTS_RESET' '' 'SIFIRLA'
        }
    } catch {}
    try {
        $is = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction Stop
        if ($is.ProxyEnable -eq 1) { $f += New-ZFinding 'BİLGİ' 'Ağ' 'Proxy sunucusu etkin' ("{0}" -f $is.ProxyServer) 'Siz ayarlamadıysanız kapatın (internet yavaşlığına/yönlendirmeye neden olabilir).' 'PROXY_OFF' '' 'KAPAT' }
    } catch {}
    $f
}

# ---------------------------------------------------------------------
#  BAŞLANGIÇ PROGRAMLARI
# ---------------------------------------------------------------------
function Get-ZStartupItems {
    $rows = @()
    $sets = @(
        @{ Run = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; App = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Kap = 'Kullanıcı' },
        @{ Run = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'; App = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'; Kap = 'Tüm kullanıcılar' },
        @{ Run = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; App = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32'; Kap = 'Tüm kullanıcılar (32 bit)' }
    )
    foreach ($s in $sets) {
        if (-not (Test-Path $s.Run)) { continue }
        $item = Get-Item $s.Run
        $appr = $null; if (Test-Path $s.App) { $appr = Get-Item $s.App }
        foreach ($n in $item.GetValueNames()) {
            if (-not $n) { continue }
            $state = 'Etkin'
            if ($appr) { $b = $appr.GetValue($n); if ($b -is [byte[]] -and $b.Length -gt 0 -and ($b[0] -band 1)) { $state = 'Devre dışı' } }
            $rows += [pscustomobject]@{ Ad = $n; Komut = "$($item.GetValue($n))"; Kapsam = $s.Kap; Durum = $state; _Approved = $s.App }
        }
    }
    foreach ($pair in @(@{ D = [Environment]::GetFolderPath('Startup'); A = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder'; K = 'Başlangıç klasörü' },
            @{ D = [Environment]::GetFolderPath('CommonStartup'); A = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder'; K = 'Ortak başlangıç klasörü' })) {
        $appr = $null; if (Test-Path $pair.A) { $appr = Get-Item $pair.A }
        foreach ($fi in @(Get-ChildItem $pair.D -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'desktop.ini' })) {
            $state = 'Etkin'
            if ($appr) { $b = $appr.GetValue($fi.Name); if ($b -is [byte[]] -and $b.Length -gt 0 -and ($b[0] -band 1)) { $state = 'Devre dışı' } }
            $rows += [pscustomobject]@{ Ad = $fi.Name; Komut = $fi.FullName; Kapsam = $pair.K; Durum = $state; _Approved = $pair.A }
        }
    }
    $rows
}

function Set-ZStartupItem {
    param([string]$Name, [string]$ApprovedKey, [bool]$Enable)
    if (-not (Test-Path $ApprovedKey)) { New-Item -Path $ApprovedKey -Force | Out-Null }
    $bytes = New-Object byte[] 12
    if ($Enable) { $bytes[0] = 2 } else {
        $bytes[0] = 3
        $ft = [BitConverter]::GetBytes((Get-Date).ToFileTimeUtc()); [Array]::Copy($ft, 0, $bytes, 4, 8)
    }
    Set-ItemProperty -Path $ApprovedKey -Name $Name -Value $bytes -Type Binary
    Write-ZLog ("Başlangıç: {0} → {1}" -f $Name, $(if ($Enable) { 'Etkin' } else { 'Devre dışı' })) 'OK'
}

# ---------------------------------------------------------------------
#  DARBOĞAZ ANALİZİ
# ---------------------------------------------------------------------
$Global:ZGpuTiers = @(
    @('RTX\s*5090', 100), @('RTX\s*4090', 92), @('RTX\s*5080', 86), @('RTX\s*4080\s*SUPER', 82), @('RTX\s*4080', 80),
    @('RTX\s*4070\s*Ti\s*SUPER', 74), @('RTX\s*4070\s*SUPER', 66), @('RX\s*7600\s*XT', 38), @('RX\s*6700\s*XT', 42), @('RX\s*6600\s*XT', 33), @('Arc\s*B570', 36), @('RX\s*7900\s*XTX', 80),
    @('RTX\s*5070\s*Ti', 76), @('RX\s*9070\s*XT', 76), @('RX\s*7900\s*XT', 72), @('RTX\s*4070\s*Ti', 70), @('RX\s*9070', 68),
    @('RTX\s*5070', 66), @('RX\s*7900\s*GRE', 64), @('RTX\s*3090\s*Ti', 64), @('RTX\s*3090', 61), @('RTX\s*4070', 60),
    @('RX\s*6950', 60), @('RTX\s*3080\s*Ti', 60), @('RX\s*7800', 58), @('RTX\s*3080', 56), @('RX\s*6900', 56), @('RX\s*6800\s*XT', 54),
    @('RTX\s*5060\s*Ti', 52), @('RX\s*9060\s*XT', 50), @('RX\s*7700', 50), @('RX\s*6800', 49), @('RTX\s*4060\s*Ti', 47), @('RTX\s*3070\s*Ti', 48),
    @('RTX\s*2080\s*Ti', 45), @('RTX\s*3070', 45), @('RTX\s*5060', 44), @('RX\s*6750', 42), @('RX\s*6700', 40), @('Arc\s*B580', 40), @('RTX\s*4060', 39),
    @('RTX\s*3060\s*Ti', 39), @('RTX\s*2080', 37), @('RX\s*7600', 36), @('Arc\s*A770', 34), @('RTX\s*2070', 32), @('RX\s*6650', 33), @('RX\s*6600', 30),
    @('Arc\s*A750', 30), @('RTX\s*3060', 31), @('RX\s*5700', 29), @('GTX\s*1080\s*Ti', 30), @('RTX\s*2060', 26), @('GTX\s*1080', 24), @('RTX\s*3050', 20),
    @('GTX\s*1660', 20), @('GTX\s*1070', 21), @('RX\s*5600', 24), @('RX\s*590', 15), @('RX\s*580', 14), @('GTX\s*1650', 13), @('GTX\s*1060', 15),
    @('RX\s*6500', 12), @('RX\s*570', 12), @('GTX\s*1050', 9), @('GTX\s*9[5-8]0', 10), @('Radeon\s*780M', 12), @('Radeon\s*680M', 10),
    @('Arc\(TM\)\s*Graphics|Intel\s*Arc\s*Graphics', 9), @('Iris|UHD|HD Graphics|Radeon\(TM\)\s*Graphics|Vega', 4)
)

function Get-ZGpuTier { param([string[]]$Names)
    $best = $null
    foreach ($n in @($Names)) {
        if (-not $n -or $n -match 'Virtual|Parsec|Remote|Meta|Basic Display|Temel Görüntü|Mirage|Indirect') { continue }
        $found = $false
        foreach ($t in $Global:ZGpuTiers) {
            if ($n -match $t[0]) {
                $sc = [int]$t[1]; if ($n -match 'Laptop|Mobile|Max-Q') { $sc = [int]($sc * 0.8) }
                if (-not $best -or $sc -gt $best.Score) { $best = [pscustomobject]@{ Name = $n; Score = $sc; Estimated = $false } }
                $found = $true; break
            }
        }
        if (-not $found) {
            # Veritabanında yok: ekran belleğine göre tahmin
            $vr = 0; try { $vv = Get-ZGpuVram; if ($vv.ContainsKey($n)) { $vr = $vv[$n] / 1GB } } catch {}
            $sc = 6; if ($vr -ge 2) { $sc = [int][math]::Min(45, [math]::Max(8, $vr * 4.5)) }
            if ($n -match 'Intel|UHD|Iris|Radeon\(TM\) Graphics|Vega') { $sc = [math]::Min($sc, 8) }
            if (-not $best -or $sc -gt $best.Score) { $best = [pscustomobject]@{ Name = $n; Score = $sc; Estimated = $true } }
        }
    }
    $best
}

function Get-ZCpuTier { param([string]$Name, [int]$Threads, [int]$Mhz)
    $n = $Name
    $m = [regex]::Match($n, 'Ryzen\s+(\d)\s+(?:PRO\s+)?(\d)(\d)\d\d\w*', 'IgnoreCase')
    if ($m.Success) {
        $series = [int]$m.Groups[1].Value; $gen = [int]$m.Groups[2].Value
        $base = @{ 1 = 20; 2 = 26; 3 = 40; 4 = 42; 5 = 58; 7 = 72; 8 = 70; 9 = 82 }[$gen]; if (-not $base) { $base = 45 }
        $mod = @{ 3 = -14; 5 = 0; 7 = 6; 9 = 10 }[$series]; if ($null -eq $mod) { $mod = 0 }
        $s = $base + $mod; if ($n -match 'X3D') { $s += 10 }; if ($n -match '\d{4}U\b|\d{4}H\b|HS\b') { $s -= 8 }
        return [math]::Min(100, $s)
    }
    $m = [regex]::Match($n, 'Core\(TM\)\s*Ultra\s*(\d)\s*(\d)\d\d', 'IgnoreCase')
    if (-not $m.Success) { $m = [regex]::Match($n, 'Core\s*Ultra\s*(\d)\s*(\d)\d\d', 'IgnoreCase') }
    if ($m.Success) {
        $series = [int]$m.Groups[1].Value; $gen = [int]$m.Groups[2].Value
        $base = 60; if ($gen -ge 2) { $base = 70 }
        $mod = @{ 5 = 0; 7 = 6; 9 = 10 }[$series]; if ($null -eq $mod) { $mod = 0 }
        $s = $base + $mod; if ($n -match '\d{3}[UVH]\b') { $s -= 10 }
        return [math]::Min(100, $s)
    }
    $m = [regex]::Match($n, 'i([3579])-(\d{4,5})', 'IgnoreCase')
    if ($m.Success) {
        $series = [int]$m.Groups[1].Value; $num = $m.Groups[2].Value
        $gen = [int]$num.Substring(0, $num.Length - 3)
        $base = @{ 2 = 8; 3 = 10; 4 = 14; 5 = 15; 6 = 20; 7 = 22; 8 = 28; 9 = 32; 10 = 38; 11 = 44; 12 = 58; 13 = 66; 14 = 68 }[$gen]; if (-not $base) { $base = 30 }
        $mod = @{ 3 = -14; 5 = 0; 7 = 6; 9 = 10 }[$series]
        $s = $base + $mod; if ($n -match '\d{4,5}(U|H|HQ|HK|HX|P)\b') { $s -= 8 }
        return [math]::Max(5, [math]::Min(100, $s))
    }
    return [math]::Max(5, [math]::Min(60, [int]($Threads * 2 + $Mhz / 150)))
}

function Get-ZStaticBottleneck {
    $si = Get-ZSystemInfo
    $cpu = Get-ZCpuTier $si.CpuName $si.CpuThreads $si.CpuMhz
    $gpuT = Get-ZGpuTier $si.GpuNames
    $gpu = 5; $gpuName = ($si.GpuNames -join ', '); if ($gpuT) { $gpu = $gpuT.Score; $gpuName = $gpuT.Name; if ($gpuT.Estimated) { $gpuName += ' (tahmini puan)' } }
    $notes = @()
    $verdict = ''; $pct = 0
    if (-not $gpuT) { $verdict = 'Ekran kartı veritabanında bulunamadı; canlı ölçüm yapın.' }
    else {
        $diff = $gpu - $cpu
        if ($diff -gt 15) { $pct = [math]::Min(60, [int](($diff - 10) * 1.2)); $verdict = ('İŞLEMCİ DARBOĞAZI riski — işlemci ekran kartını yaklaşık %{0} kısıtlayabilir (özellikle 1080pʼde).' -f $pct) }
        elseif ($diff -lt -25) { $pct = [math]::Min(60, [int](([math]::Abs($diff) - 20) * 1.0)); $verdict = ('Ekran kartı sınırlayıcı — işlemci güçlü, GPU yükseltmesi en büyük FPS artışını sağlar (~%{0} dengesizlik).' -f $pct) }
        else { $verdict = 'DENGELİ sistem — işlemci ve ekran kartı uyumlu.' }
    }
    if ($si.RamBytes -lt 16GB) { $notes += 'RAM 16 GBʼın altında: modern oyunlarda takılma (stutter) yapabilir.' }
    if ($si.RamModules -eq 1) { $notes += 'Tek kanal RAM: işlemci performansını ciddi düşürür (çift kanal önerilir).' }
    $mods = Get-ZRamModules | Where-Object { $_._Speed -gt 0 -and $_._Cfg -gt 0 } | Select-Object -First 1
    if ($mods -and $mods._Cfg -lt ($mods._Speed - 100)) { $notes += ('RAM {0} yerine {1} MT/s çalışıyor: XMP/EXPO açın.' -f $mods._Speed, $mods._Cfg) }
    if ($si.SistemDiski -match 'HDD') { $notes += 'Sistem diski HDD: yükleme süreleri ve açılış çok yavaş olur.' }
    [pscustomobject]@{ CpuScore = $cpu; GpuScore = $gpu; CpuName = $si.CpuName; GpuName = $gpuName; Verdict = $verdict; Percent = $pct; Notes = $notes }
}

function Read-ZGpuRaw {
    # Ham GPU motor sayaçları (dil bağımsız, Görev Yöneticisi ile aynı kaynak)
    $h = @{}
    $now = [DateTime]::UtcNow.Ticks
    foreach ($e in @(Get-CimInstance Win32_PerfRawData_GPUPerformanceCounters_GPUEngine -ErrorAction Stop)) {
        $n = "$($e.Name)"; if (-not $n) { continue }
        $ts = ConvertTo-ZNum $e.Timestamp_Sys100NS; if ($ts -le 0) { $ts = $now }
        $h[$n] = @((ConvertTo-ZNum $e.UtilizationPercentage), $ts)
    }
    $h
}

function Get-ZGpuUsage {
    # İki ham örnekten kullanım yüzdesi: Toplam (en yüklü motor) ve işlem başına
    param($Prev, $Cur)
    $eng = @{}; $byPid = @{}
    if (-not $Prev -or -not $Cur) { return [pscustomobject]@{ Total = 0; PerPid = $byPid } }
    foreach ($k in @($Cur.Keys)) {
        if (-not $Prev.ContainsKey($k)) { continue }
        $dt = [double]$Cur[$k][1] - [double]$Prev[$k][1]; if ($dt -le 0) { continue }
        $u = ([double]$Cur[$k][0] - [double]$Prev[$k][0]) / $dt * 100
        if ($u -lt 0 -or $u -gt 1000) { continue }
        $ek = $k -replace '^pid_\d+_', ''
        $eng[$ek] = [double]$eng[$ek] + $u
        $m = [regex]::Match($k, '^pid_(\d+)_')
        if ($m.Success -and $k -match 'engtype_3D') { $pp = [int]$m.Groups[1].Value; $byPid[$pp] = [double]$byPid[$pp] + $u }
    }
    $tot = 0; foreach ($v in $eng.Values) { if ($v -gt $tot) { $tot = $v } }
    [pscustomobject]@{ Total = [math]::Min(100, [math]::Round($tot)); PerPid = $byPid }
}

function Get-ZLiveSample {
    $cpuTotal = 0; $cpuMax = 0; $gpu = 0; $vram = 0; $disk = 0; $perf = 0
    try {
        $proc = @(Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -ErrorAction Stop)
        $cpuTotal = ConvertTo-ZInt (@($proc | Where-Object { $_.Name -eq '_Total' })[0].PercentProcessorTime)
        $cores = @($proc | Where-Object { $_.Name -ne '_Total' } | ForEach-Object { ConvertTo-ZInt $_.PercentProcessorTime })
        if ($cores.Count) { $cpuMax = ($cores | Measure-Object -Maximum).Maximum }
    } catch {}
    try {
        $cur = Read-ZGpuRaw
        if ($Global:ZGpuPrev) { $gpu = ConvertTo-ZInt (Get-ZGpuUsage $Global:ZGpuPrev $cur).Total }
        $Global:ZGpuPrev = $cur
    } catch {}
    try {
        if (-not $Global:ZVramTotal) { $vv = Get-ZGpuVram; if ($vv.Count) { $Global:ZVramTotal = ($vv.Values | Measure-Object -Maximum).Maximum } }
        $mem = @(Get-CimInstance Win32_PerfRawData_GPUPerformanceCounters_GPUAdapterMemory -ErrorAction Stop)
        $used = 0; foreach ($mm in $mem) { $x = ConvertTo-ZNum $mm.DedicatedUsage; if ($x -gt $used) { $used = $x } }
        if ($Global:ZVramTotal -and $used) { $vram = [math]::Min(100, (ConvertTo-ZInt ($used / $Global:ZVramTotal * 100))) }
    } catch {}
    try { $d = Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk -Filter "Name='_Total'" -ErrorAction Stop; $disk = [math]::Max(0, 100 - (ConvertTo-ZInt $d.PercentIdleTime)) } catch {}
    try { $pi = Get-CimInstance Win32_PerfFormattedData_Counters_ProcessorInformation -Filter "Name='_Total'" -ErrorAction Stop; $perf = ConvertTo-ZInt $pi.PercentProcessorPerformance } catch {}
    $os = Get-CimInstance Win32_OperatingSystem
    $ram = ConvertTo-ZInt (100 - ((ConvertTo-ZNum $os.FreePhysicalMemory) / [math]::Max(1, (ConvertTo-ZNum $os.TotalVisibleMemorySize)) * 100))
    [pscustomobject]@{ Time = Get-Date; Cpu = $cpuTotal; CpuMax = $cpuMax; Gpu = $gpu; Ram = $ram; Disk = $disk; Vram = $vram; Perf = $perf }
}

function Invoke-ZLiveBottleneck {
    param([int]$Seconds = 60)
    $v = Get-ZGpuVram; if ($v.Count) { $Global:ZVramTotal = ($v.Values | Measure-Object -Maximum).Maximum }
    try { $Global:ZGpuPrev = Read-ZGpuRaw } catch {}
    Write-ZLog ("Canlı darboğaz ölçümü başladı ({0} sn). Oyunu şimdi açın / oynamaya devam edin." -f $Seconds)
    $samples = @()
    $end = (Get-Date).AddSeconds($Seconds)
    $i = 0
    while ((Get-Date) -lt $end) {
        if ($Global:Sync -and $Global:Sync.Cancel) { Write-ZLog 'Ölçüm iptal edildi.' 'WARN'; break }
        $s = Get-ZLiveSample; $samples += $s; $i++
        if ($Global:Sync -and $Global:Sync.Samples) { $Global:Sync.Samples.Enqueue($s) }
        Set-ZProgress ([int](100 - (($end - (Get-Date)).TotalSeconds / $Seconds * 100)))
        Start-Sleep -Milliseconds 700
    }
    if ($samples.Count -lt 3) { return $null }
    $avg = { param($p) [math]::Round(($samples | Measure-Object $p -Average).Average) }
    $r = [ordered]@{ Cpu = (& $avg 'Cpu'); CpuMax = (& $avg 'CpuMax'); Gpu = (& $avg 'Gpu'); Ram = (& $avg 'Ram'); Disk = (& $avg 'Disk'); Vram = (& $avg 'Vram'); Perf = (& $avg 'Perf'); Verdict = ''; Advice = ''; Type = '' }
    if ($r.Ram -ge 90) { $r.Type = 'RAM'; $r.Verdict = ('BELLEK (RAM) DARBOĞAZI — RAM kullanımı ortalama %{0}' -f $r.Ram); $r.Advice = 'Arka plan programlarını kapatın, RAM kapasitesini artırın (32 GB).' }
    elseif ($r.Vram -ge 95) { $r.Type = 'VRAM'; $r.Verdict = ('EKRAN BELLEĞİ (VRAM) DOLU — %{0}' -f $r.Vram); $r.Advice = 'Doku kalitesini bir kademe düşürün; ray tracing/çözünürlüğü azaltın.' }
    elseif ($r.Gpu -ge 90) { $r.Type = 'GPU'; $r.Verdict = ('EKRAN KARTI TAM YÜKTE (%{0}) — sistem dengeli, sınır GPUʼda.' -f $r.Gpu); $r.Advice = 'Oyunlarda ideal durum budur. Daha fazla FPS için grafik ayarlarını düşürün veya DLSS/FSR açın.' }
    elseif ($r.CpuMax -ge 85 -and $r.Gpu -lt 80) { $r.Type = 'CPU'; $r.Verdict = ('İŞLEMCİ DARBOĞAZI — GPU yalnızca %{0} kullanılıyor, işlemci çekirdeği %{1}ʼde.' -f $r.Gpu, $r.CpuMax); $r.Advice = ('Ekran kartı yaklaşık %{0} boşta bekliyor. Arka plan uygulamalarını kapatın, XMP/EXPO açın, çözünürlüğü/grafikleri artırmak FPS kaybettirmez; işlemci yükseltmesi düşünülebilir.' -f (100 - $r.Gpu)) }
    elseif ($r.Disk -ge 85) { $r.Type = 'DISK'; $r.Verdict = ('DİSK DARBOĞAZI — disk %{0} meşgul' -f $r.Disk); $r.Advice = 'Oyunu SSD/NVMeʼye taşıyın, arka plan indirme/antivirüs taramalarını durdurun.' }
    elseif ($r.Gpu -lt 60 -and $r.CpuMax -lt 70) { $r.Type = 'LIMIT'; $r.Verdict = 'Belirgin darboğaz yok — FPS kilidi (V-Sync/FPS limiti) aktif olabilir veya ölçüm sırasında oyun açık değildi.'; $r.Advice = 'Ölçümü oyun içindeyken tekrarlayın; FPS limitini kontrol edin.' }
    else { $r.Type = 'OK'; $r.Verdict = 'Dengeli kullanım — ciddi bir darboğaz görülmedi.'; $r.Advice = 'Sistem kaynakları dengeli kullanılıyor.' }
    if ($r.Perf -gt 0 -and $r.Perf -lt 75 -and $r.Cpu -gt 50) { $r.Advice += (' İşlemci performansı yük altında %{0}ʼe düştü: ısıl/güç kısıtlaması (throttling) olabilir.' -f $r.Perf) }
    Write-ZLog ('Sonuç: ' + $r.Verdict) 'OK'
    [pscustomobject]$r
}

# ---------------------------------------------------------------------
#  AĞ TESTİ
# ---------------------------------------------------------------------
function Test-ZPingTarget { param([string]$Target, [int]$Count = 20)
    $p = New-Object System.Net.NetworkInformation.Ping
    $times = @(); $lost = 0
    for ($i = 0; $i -lt $Count; $i++) {
        try { $r = $p.Send($Target, 1500); if ($r.Status -eq 'Success') { $times += ConvertTo-ZInt $r.RoundtripTime } else { $lost++ } } catch { $lost++ }
        Start-Sleep -Milliseconds 120
    }
    $avg = 0; $jit = 0
    if ($times.Count) {
        $avg = [math]::Round(($times | Measure-Object -Average).Average, 1)
        if ($times.Count -gt 1) { $d = 0; for ($i = 1; $i -lt $times.Count; $i++) { $d += [math]::Abs($times[$i] - $times[$i - 1]) }; $jit = [math]::Round($d / ($times.Count - 1), 1) }
    }
    [pscustomobject]@{ Hedef = $Target; Ortalama = $avg; Jitter = $jit; Kayip = [math]::Round($lost / $Count * 100); Min = $(if ($times) { ($times | Measure-Object -Minimum).Minimum } else { 0 }); Max = $(if ($times) { ($times | Measure-Object -Maximum).Maximum } else { 0 }) }
}

function Test-ZNetwork {
    $f = @(); $rows = @()
    Write-ZLog 'Ağ bağdaştırıcıları inceleniyor...'
    $gw = $null
    try {
        $cfg = Get-NetIPConfiguration -ErrorAction Stop | Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' } | Select-Object -First 1
        if ($cfg) { $gw = $cfg.IPv4DefaultGateway.NextHop }
        foreach ($a in @(Get-NetAdapter -Physical -ErrorAction Stop | Where-Object Status -eq 'Up')) {
            $isWifi = ($a.MediaType -match '802\.11' -or $a.PhysicalMediaType -match '802\.11|Wireless' -or $a.InterfaceDescription -match 'Wi-?Fi|Wireless')
            if (-not $isWifi -and $a.LinkSpeed -match '^100 Mbps') {
                $f += New-ZFinding 'UYARI' 'Ağ' ("Kablolu bağlantı 100 Mbpsʼte: {0}" -f $a.Name) $a.InterfaceDescription 'Kablo (CAT5e/CAT6) veya modem portu arızalı olabilir; gigabit bekleniyorsa kabloyu değiştirin.'
            }
            try {
                $st = Get-NetAdapterStatistics -Name $a.Name -ErrorAction Stop
                if (($st.ReceivedPacketErrors + $st.OutboundPacketErrors) -gt 100) {
                    $f += New-ZFinding 'UYARI' 'Ağ' ("Ağ kartında paket hataları: {0}" -f $a.Name) ("Alma: {0}, Gönderme: {1}" -f $st.ReceivedPacketErrors, $st.OutboundPacketErrors) 'Kablo/port arızası veya sürücü sorunu. Ağ sürücüsünü güncelleyin.'
                }
            } catch {}
            if ($isWifi) {
                $w = (& netsh wlan show interfaces) -join "`n"
                $mm = [regex]::Match($w, '(?:Sinyal|Signal)\s*:\s*(\d+)\s*%')
                if ($mm.Success) {
                    $sig = ConvertTo-ZInt $mm.Groups[1].Value
                    if ($sig -lt 50) { $f += New-ZFinding 'UYARI' 'Ağ' ("Wi-Fi sinyali zayıf: %{0}" -f $sig) '' 'Modeme yaklaşın, 5 GHz kullanın veya kablolu bağlantıya geçin (oyunlar için önerilir).' }
                    else { $f += New-ZFinding 'BİLGİ' 'Ağ' ("Wi-Fi sinyali: %{0}" -f $sig) '' 'Oyunlarda en düşük gecikme için kablolu bağlantı önerilir.' }
                }
            }
        }
    } catch {}
    $targets = @(); if ($gw) { $targets += $gw }; $targets += '1.1.1.1', '8.8.8.8'
    $i = 0
    foreach ($t in $targets) {
        $i++; Set-ZProgress ([int]($i / ($targets.Count + 1) * 100)) ("Ping: " + $t)
        Write-ZLog ("Ping testi: {0}" -f $t)
        $r = Test-ZPingTarget $t 20; $rows += $r
        Write-ZLog ("{0} → ort. {1} ms, jitter {2} ms, kayıp %{3}" -f $t, $r.Ortalama, $r.Jitter, $r.Kayip)
    }
    $gwRow = $rows | Where-Object { $_.Hedef -eq $gw } | Select-Object -First 1
    $inet = $rows | Where-Object { $_.Hedef -ne $gw }
    if ($gwRow -and $gwRow.Kayip -gt 0) { $f += New-ZFinding 'UYARI' 'Ağ' ("Modeme giden pakette kayıp: %{0}" -f $gwRow.Kayip) '' 'Ev içi ağ sorunu: Wi-Fi paraziti, kablo veya modem. Modemi yeniden başlatın.' }
    if ($gwRow -and $gwRow.Ortalama -gt 15) { $f += New-ZFinding 'UYARI' 'Ağ' ("Modem gecikmesi yüksek: {0} ms" -f $gwRow.Ortalama) '' 'Yerel ağda gecikme var (normali 1–5 ms). Wi-Fi yerine kablo deneyin.' }
    $loss = ($inet | Measure-Object Kayip -Maximum).Maximum
    $avg = ($inet | Where-Object { $_.Ortalama -gt 0 } | Measure-Object Ortalama -Minimum).Minimum
    $jit = ($inet | Measure-Object Jitter -Maximum).Maximum
    if ($loss -ge 100) { $f += New-ZFinding 'KRİTİK' 'Ağ' 'İnternete erişilemiyor' '' 'Ağ ayarlarını sıfırlayın, modemi yeniden başlatın.' 'NET_RESET' '' 'AĞI SIFIRLA' }
    elseif ($loss -ge 3) { $f += New-ZFinding 'UYARI' 'Ağ' ("İnternette paket kaybı: %{0}" -f $loss) '' 'Oyunlarda ışınlanma/kopma yapar. Modemi yeniden başlatın, sorun sürerse servis sağlayıcınıza bildirin.' }
    if ($avg -gt 80) { $f += New-ZFinding 'UYARI' 'Ağ' ("Yüksek ping: {0} ms" -f $avg) '' 'İnternet hattında gecikme yüksek.' }
    if ($jit -gt 20) { $f += New-ZFinding 'UYARI' 'Ağ' ("Dalgalı bağlantı (jitter {0} ms)" -f $jit) '' 'Arka plan indirmelerini durdurun, kablolu bağlantı kullanın.' }
    try {
        & ipconfig /flushdns | Out-Null
        $sw = [Diagnostics.Stopwatch]::StartNew(); [void][Net.Dns]::GetHostAddresses('www.youtube.com'); $sw.Stop()
        $dnsMs = $sw.ElapsedMilliseconds
        Write-ZLog ("DNS çözümleme süresi: {0} ms" -f $dnsMs)
        if ($dnsMs -gt 150) { $f += New-ZFinding 'UYARI' 'Ağ' ("DNS yavaş: {0} ms" -f $dnsMs) '' 'Daha hızlı bir DNS (Cloudflare 1.1.1.1) kullanabilirsiniz.' 'DNS_CLOUDFLARE' '' 'DNS DEĞİŞTİR' }
        $rows += [pscustomobject]@{ Hedef = 'DNS (youtube.com)'; Ortalama = $dnsMs; Jitter = 0; Kayip = 0; Min = $dnsMs; Max = $dnsMs }
    } catch { $f += New-ZFinding 'KRİTİK' 'Ağ' 'DNS çözümleme başarısız' $_.Exception.Message 'DNS önbelleğini temizleyin ve ağı sıfırlayın.' 'NET_RESET' '' 'AĞI SIFIRLA' }
    Set-ZProgress 100
    [pscustomobject]@{ Findings = $f; Rows = $rows }
}

# ---------------------------------------------------------------------
#  TEMİZLİK
# ---------------------------------------------------------------------
$Global:ZCleanTargets = [ordered]@{
    'Kullanıcı geçici dosyaları'           = @{ Paths = @('%TEMP%') }
    'Windows geçici dosyaları'             = @{ Paths = @('%SystemRoot%\Temp') }
    'Windows Update indirme önbelleği'     = @{ Paths = @('%SystemRoot%\SoftwareDistribution\Download'); Service = 'wuauserv' }
    'Hata raporları (WER)'                 = @{ Paths = @('%ProgramData%\Microsoft\Windows\WER\ReportArchive', '%ProgramData%\Microsoft\Windows\WER\ReportQueue', '%LOCALAPPDATA%\CrashDumps') }
    'Çökme dökümleri (Minidump)'           = @{ Paths = @('%SystemRoot%\Minidump'); Files = @('%SystemRoot%\MEMORY.DMP') }
    'DirectX gölgelendirici önbelleği'     = @{ Paths = @('%LOCALAPPDATA%\D3DSCache') }
    'NVIDIA / AMD gölgelendirici önbelleği'= @{ Paths = @('%LOCALAPPDATA%\NVIDIA\DXCache', '%LOCALAPPDATA%\NVIDIA\GLCache', '%LOCALAPPDATA%\AMD\DxCache', '%LOCALAPPDATA%\AMD\DxcCache', '%LOCALAPPDATA%\AMD\GLCache') }
    'Küçük resim önbelleği'                = @{ Pattern = '%LOCALAPPDATA%\Microsoft\Windows\Explorer\thumbcache_*.db' }
    'Teslim iyileştirme önbelleği'         = @{ Paths = @('%SystemRoot%\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache') }
    'Geri Dönüşüm Kutusu'                  = @{ Recycle = $true }
}

function Get-ZCleanSize { param([string]$Name)
    $t = $Global:ZCleanTargets[$Name]; $sum = 0
    foreach ($p in @($t.Paths)) { if (-not $p) { continue }; $x = [Environment]::ExpandEnvironmentVariables($p); if (Test-Path $x) { $sum += (Get-ChildItem $x -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum } }
    foreach ($p in @($t.Files)) { if (-not $p) { continue }; $x = [Environment]::ExpandEnvironmentVariables($p); if (Test-Path $x) { $sum += (Get-Item $x -Force).Length } }
    if ($t.Pattern) { $sum += (Get-ChildItem ([Environment]::ExpandEnvironmentVariables($t.Pattern)) -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum }
    if ($t.Recycle) {
        try { foreach ($dr in Get-PSDrive -PSProvider FileSystem) { $rp = Join-Path $dr.Root '$Recycle.Bin'; if (Test-Path $rp) { $sum += (Get-ChildItem $rp -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum } } } catch {}
    }
    [double]$sum
}

function Invoke-ZClean { param([string[]]$Names)
    $total = 0; $i = 0
    foreach ($n in $Names) {
        $i++; Set-ZProgress ([int]($i / $Names.Count * 100)) $n
        $t = $Global:ZCleanTargets[$n]; if (-not $t) { continue }
        $before = Get-ZCleanSize $n
        if ($t.Service) { Stop-Service $t.Service -Force -ErrorAction SilentlyContinue }
        foreach ($p in @($t.Paths)) { if (-not $p) { continue }; $x = [Environment]::ExpandEnvironmentVariables($p); if (Test-Path $x) { Get-ChildItem $x -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue } }
        foreach ($p in @($t.Files)) { if (-not $p) { continue }; $x = [Environment]::ExpandEnvironmentVariables($p); Remove-Item $x -Force -ErrorAction SilentlyContinue }
        if ($t.Pattern) { Get-ChildItem ([Environment]::ExpandEnvironmentVariables($t.Pattern)) -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue }
        if ($t.Recycle) { try { Clear-RecycleBin -Force -ErrorAction Stop } catch {} }
        if ($t.Service) { Start-Service $t.Service -ErrorAction SilentlyContinue }
        $after = Get-ZCleanSize $n
        $freed = [math]::Max([double]0, [double]$before - [double]$after); $total += $freed
        Write-ZLog ("{0}: {1} temizlendi" -f $n, (Format-ZSize $freed)) 'OK'
    }
    Write-ZLog ("TOPLAM KAZANILAN ALAN: {0}" -f (Format-ZSize $total)) 'OK'
    $total
}

# ---------------------------------------------------------------------
#  ONARIM KATALOĞU
# ---------------------------------------------------------------------
function New-ZRestorePoint {
    Write-ZLog 'Sistem geri yükleme noktası oluşturuluyor...'
    try {
        Enable-ComputerRestore -Drive ($env:SystemDrive + '\') -ErrorAction SilentlyContinue
        $k = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'
        Set-ItemProperty -Path $k -Name 'SystemRestorePointCreationFrequency' -Value 0 -Type DWord -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description ('ZETX Onarım Öncesi ' + (Get-Date -Format 'dd.MM.yyyy HH:mm')) -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Write-ZLog 'Geri yükleme noktası oluşturuldu.' 'OK'; return $true
    } catch { Write-ZLog ('Geri yükleme noktası oluşturulamadı: ' + $_.Exception.Message) 'WARN'; return $false }
}

function Get-ZFixTitle { param([string]$FixId)
    @{
        SFC = 'Sistem Dosyası Denetleyicisi (SFC /scannow)'; DISM_CHECK = 'DISM Hızlı Sağlık Kontrolü'; DISM_SCAN = 'DISM Derin Tarama'
        DISM_RESTORE = 'DISM Görüntü Onarımı (RestoreHealth)'; DISM_CLEANUP = 'Bileşen Deposu Temizliği'; CHKDSK_SCAN = 'CHKDSK Çevrimiçi Tarama'
        CHKDSK_SCHEDULE = 'CHKDSK /F /R (yeniden başlatmada)'; WU_RESET = 'Windows Update Sıfırlama'; WMI_REPAIR = 'WMI Deposu Onarımı'
        NET_RESET = 'Ağ Sıfırlama (Winsock/IP/DNS)'; DNS_FLUSH = 'DNS Önbelleği Temizleme'; ICON_CACHE = 'Simge Önbelleğini Yeniden Oluştur'
        STORE_RESET = 'Microsoft Store Önbelleği Sıfırlama'; TEMP_CLEAN = 'Geçici Dosya Temizliği'; POWER_HIGH = 'Yüksek Performans Güç Planı'
        POWER_ULTIMATE = 'Nihai Performans Güç Planı'; MEMDIAG = 'Windows Bellek Tanılama'; DEVICE_RESCAN = 'Donanım Değişikliklerini Tara'
        RESTORE_POINT = 'Geri Yükleme Noktası Oluştur'; WU_DRIVERS = 'İsteğe Bağlı Sürücü Güncellemeleri'; OPEN_URL = 'Bağlantıyı Aç'; FULL_REPAIR = 'TAM ONARIM (DISM + SFC + CHKDSK)'; SPOOLER_RESET = 'Yazdırma Biriktiricisi Sıfırlama'
        AUDIO_RESET = 'Ses Hizmetlerini Yeniden Başlat'; EXPLORER_RESTART = 'Windows Gezgini Yeniden Başlat'; TIME_SYNC = 'Saat Eşitleme'
        VCREDIST = 'Visual C++ Paketleri Bilgisi'; DEFENDER_UPDATE = 'Defender Tanım Güncellemesi'; DEFENDER_SCAN = 'Defender Hızlı Tarama'
    }[$FixId]
}

function Invoke-ZFix {
    param([string]$FixId, [string]$Data = '')
    $title = Get-ZFixTitle $FixId; if (-not $title) { $title = $FixId }
    Write-ZLog ("═══ {0} başlatılıyor ═══" -f $title)
    Set-ZProgress 0 $title
    $ok = $true
    switch ($FixId) {
        'SFC' { $r = Invoke-ZProcess "$env:SystemRoot\System32\sfc.exe" '/scannow' -Unicode
            if ($r.Output -match 'bozuk dosya bulundu ve başarıyla onarıldı|found corrupt files and successfully repaired') { Write-ZLog 'SFC bozuk dosyaları ONARDI.' 'OK' }
            elseif ($r.Output -match 'bozuk dosyalar buldu ancak|found corrupt files but was unable') { Write-ZLog 'SFC bazı dosyaları onaramadı → DISM RestoreHealth çalıştırıp SFCʼyi tekrarlayın.' 'WARN'; $ok = $false }
            elseif ($r.Output -match 'bütünlük ihlali bulmadı|did not find any integrity violations') { Write-ZLog 'Sistem dosyalarında sorun yok.' 'OK' } }
        'DISM_CHECK'   { [void](Invoke-ZProcess 'dism.exe' '/Online /Cleanup-Image /CheckHealth') }
        'DISM_SCAN'    { [void](Invoke-ZProcess 'dism.exe' '/Online /Cleanup-Image /ScanHealth') }
        'DISM_RESTORE' { $r = Invoke-ZProcess 'dism.exe' '/Online /Cleanup-Image /RestoreHealth'; if ($r.ExitCode -ne 0) { $ok = $false; Write-ZLog 'DISM başarısız. İnternet bağlantısını ve Windows Update hizmetini kontrol edin.' 'WARN' } }
        'DISM_CLEANUP' { [void](Invoke-ZProcess 'dism.exe' '/Online /Cleanup-Image /StartComponentCleanup') }
        'CHKDSK_SCAN'  { $drv = $env:SystemDrive; if ($Data) { $drv = $Data }; $r = Invoke-ZProcess 'chkdsk.exe' ("$drv /scan"); if ($r.ExitCode -ne 0) { Write-ZLog 'Dosya sistemi hataları bulundu → "CHKDSK /F /R" planlayın.' 'WARN'; $ok = $false } }
        'CHKDSK_SCHEDULE' { $drv = $env:SystemDrive; if ($Data) { $drv = $Data }
            $yes = 'Y'; if ((Get-UICulture).Name -like 'tr*') { $yes = 'E' }
            [void](Invoke-ZProcess 'cmd.exe' ("/c echo {0}| chkdsk {1} /f /r" -f $yes, $drv))
            Write-ZLog ("{0} sürücüsü bir sonraki yeniden başlatmada taranacak (uzun sürebilir)." -f $drv) 'OK' }
        'FULL_REPAIR' {
            New-ZRestorePoint | Out-Null
            Write-ZLog '1/4 DISM CheckHealth'; [void](Invoke-ZProcess 'dism.exe' '/Online /Cleanup-Image /CheckHealth')
            Write-ZLog '2/4 DISM RestoreHealth'; [void](Invoke-ZProcess 'dism.exe' '/Online /Cleanup-Image /RestoreHealth')
            Write-ZLog '3/4 SFC /scannow'; [void](Invoke-ZProcess "$env:SystemRoot\System32\sfc.exe" '/scannow' -Unicode)
            Write-ZLog '4/4 CHKDSK çevrimiçi tarama'; [void](Invoke-ZProcess 'chkdsk.exe' ("$env:SystemDrive /scan"))
            Write-ZLog 'Tam onarım tamamlandı. Bilgisayarı yeniden başlatmanız önerilir.' 'OK' }
        'WU_RESET' {
            foreach ($s in 'wuauserv', 'bits', 'cryptsvc', 'msiserver', 'usosvc') { Write-ZLog "Durduruluyor: $s"; Stop-Service $s -Force -ErrorAction SilentlyContinue }
            $stamp = Get-Date -Format 'yyyyMMddHHmmss'
            foreach ($p in @("$env:SystemRoot\SoftwareDistribution", "$env:SystemRoot\System32\catroot2")) {
                if (Test-Path $p) { try { Rename-Item $p ("{0}.zetx{1}" -f (Split-Path $p -Leaf), $stamp) -ErrorAction Stop; Write-ZLog "Yeniden adlandırıldı: $p" 'OK' } catch { Write-ZLog ("Yeniden adlandırılamadı: $p " + $_.Exception.Message) 'WARN' } }
            }
            & netsh winhttp reset proxy | Out-Null
            foreach ($s in 'cryptsvc', 'bits', 'wuauserv', 'msiserver', 'usosvc') { Start-Service $s -ErrorAction SilentlyContinue; Write-ZLog "Başlatıldı: $s" }
            Write-ZLog 'Windows Update bileşenleri sıfırlandı. Güncellemeleri yeniden deneyin.' 'OK' }
        'WMI_REPAIR' { $r = Invoke-ZProcess 'winmgmt.exe' '/verifyrepository'; if ($r.Output -match 'inconsistent|tutarsız|tutarlı değil') { [void](Invoke-ZProcess 'winmgmt.exe' '/salvagerepository') } else { Write-ZLog 'WMI deposu tutarlı.' 'OK' } }
        'NET_RESET' {
            [void](Invoke-ZProcess 'ipconfig.exe' '/flushdns'); [void](Invoke-ZProcess 'ipconfig.exe' '/release'); [void](Invoke-ZProcess 'ipconfig.exe' '/renew')
            [void](Invoke-ZProcess 'netsh.exe' 'winsock reset'); [void](Invoke-ZProcess 'netsh.exe' 'int ip reset')
            Write-ZLog 'Ağ sıfırlandı. Değişikliklerin tamamlanması için bilgisayarı yeniden başlatın.' 'OK' }
        'DNS_FLUSH' { [void](Invoke-ZProcess 'ipconfig.exe' '/flushdns') }
        'DNS_CLOUDFLARE' {
            foreach ($a in @(Get-NetAdapter -Physical | Where-Object Status -eq 'Up')) { Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ServerAddresses ('1.1.1.1', '1.0.0.1'); Write-ZLog ("{0}: DNS 1.1.1.1 / 1.0.0.1 yapıldı" -f $a.Name) 'OK' }
            & ipconfig /flushdns | Out-Null }
        'DNS_AUTO' { foreach ($a in @(Get-NetAdapter -Physical | Where-Object Status -eq 'Up')) { Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ResetServerAddresses; Write-ZLog ("{0}: DNS otomatiğe alındı" -f $a.Name) 'OK' } }
        'ICON_CACHE' {
            Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue; Start-Sleep 1
            Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Windows\Explorer" -Filter 'iconcache*' -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
            Remove-Item "$env:LOCALAPPDATA\IconCache.db" -Force -ErrorAction SilentlyContinue
            Start-Process explorer.exe; Write-ZLog 'Simge önbelleği yeniden oluşturuldu.' 'OK' }
        'STORE_RESET' { Start-Process 'wsreset.exe'; Write-ZLog 'Store önbelleği sıfırlanıyor (Store penceresi açılacak).' 'OK' }
        'TEMP_CLEAN' { [void](Invoke-ZClean @('Kullanıcı geçici dosyaları', 'Windows geçici dosyaları', 'Hata raporları (WER)', 'Windows Update indirme önbelleği')) }
        'POWER_HIGH' { & powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>&1 | Out-Null; if ($LASTEXITCODE -ne 0) { & powercfg -duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c | Out-Null; & powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c }; Write-ZLog 'Güç planı: Yüksek Performans' 'OK' }
        'POWER_ULTIMATE' { $o = (& powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61) -join ' '; $m = [regex]::Match($o, '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')
            if ($m.Success) { & powercfg -setactive $m.Value; Write-ZLog 'Güç planı: Nihai Performans' 'OK' } else { Write-ZLog 'Nihai Performans planı oluşturulamadı.' 'WARN'; $ok = $false } }
        'MEMDIAG' { Start-Process "$env:SystemRoot\System32\mdsched.exe"; Write-ZLog 'Bellek Tanılama penceresi açıldı. "Şimdi yeniden başlat" seçeneğini kullanın.' 'OK' }
        'DEVICE_RESCAN' { [void](Invoke-ZProcess 'pnputil.exe' '/scan-devices') }
        'RESTORE_POINT' { $ok = New-ZRestorePoint }
        'SPOOLER_RESET' { Stop-Service Spooler -Force -ErrorAction SilentlyContinue; Get-ChildItem "$env:SystemRoot\System32\spool\PRINTERS" -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue; Start-Service Spooler -ErrorAction SilentlyContinue; Write-ZLog 'Yazdırma kuyruğu temizlendi.' 'OK' }
        'AUDIO_RESET' { foreach ($s in 'Audiosrv', 'AudioEndpointBuilder') { Restart-Service $s -Force -ErrorAction SilentlyContinue }; Write-ZLog 'Ses hizmetleri yeniden başlatıldı.' 'OK' }
        'EXPLORER_RESTART' { Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue; Start-Sleep 1; Start-Process explorer.exe; Write-ZLog 'Gezgin yeniden başlatıldı.' 'OK' }
        'TIME_SYNC' { Start-Service w32time -ErrorAction SilentlyContinue; [void](Invoke-ZProcess 'w32tm.exe' '/resync /force') }
        'DEFENDER_UPDATE' { try { Update-MpSignature -ErrorAction Stop; Write-ZLog 'Virüs tanımları güncellendi.' 'OK' } catch { Write-ZLog $_.Exception.Message 'ERR'; $ok = $false } }
        'DEFENDER_SCAN' { try { Write-ZLog 'Hızlı tarama sürüyor...'; Start-MpScan -ScanType QuickScan -ErrorAction Stop; Write-ZLog 'Hızlı tarama tamamlandı.' 'OK' } catch { Write-ZLog $_.Exception.Message 'ERR'; $ok = $false } }
        'OPEN_DEFENDER' { Start-Process 'windowsdefender:'; Write-ZLog 'Windows Güvenliği açıldı.' }
        'OPEN_WU' { Start-Process 'ms-settings:windowsupdate'; Write-ZLog 'Windows Update açıldı.' }
        'FIREWALL_ON' { $n = 'Domain', 'Private', 'Public'; if ($Data) { $n = $Data }; Set-NetFirewallProfile -Profile $n -Enabled True; Write-ZLog 'Güvenlik duvarı açıldı.' 'OK' }
        'SERVICE_FIX' { try { Set-Service -Name $Data -StartupType Automatic -ErrorAction Stop; Start-Service -Name $Data -ErrorAction Stop; Write-ZLog "Hizmet çalışıyor: $Data" 'OK' } catch { Write-ZLog $_.Exception.Message 'ERR'; $ok = $false } }
        'SERVICE_MANUAL' { try { Set-Service -Name $Data -StartupType Manual -ErrorAction Stop; Write-ZLog "Hizmet el ile başlatmaya alındı: $Data" 'OK' } catch { Write-ZLog $_.Exception.Message 'ERR'; $ok = $false } }
        'PAGEFILE_AUTO' { try { Get-CimInstance Win32_ComputerSystem | Set-CimInstance -Property @{ AutomaticManagedPagefile = $true } -ErrorAction Stop; Write-ZLog 'Sanal bellek otomatik yönetime alındı (yeniden başlatın).' 'OK' } catch { Write-ZLog $_.Exception.Message 'ERR'; $ok = $false } }
        'WINLOGON_SHELL' { $k = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'; [void](Backup-ZRegKey $k 'winlogon'); Set-ItemProperty $k -Name Shell -Value 'explorer.exe'; Write-ZLog 'Shell = explorer.exe yapıldı. Virüs taraması önerilir.' 'OK' }
        'WINLOGON_USERINIT' { $k = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'; [void](Backup-ZRegKey $k 'winlogon'); Set-ItemProperty $k -Name Userinit -Value ("$env:SystemRoot\system32\userinit.exe,"); Write-ZLog 'Userinit varsayılana döndürüldü.' 'OK' }
        'REG_DEL_VALUE' { $pp = $Data.Split('|'); [void](Backup-ZRegKey $pp[0] 'deger'); try { Remove-ItemProperty -Path $pp[0] -Name $pp[1] -Force -ErrorAction Stop; Write-ZLog ("Kaldırıldı: {0}\{1}" -f $pp[0], $pp[1]) 'OK' } catch { Write-ZLog $_.Exception.Message 'ERR'; $ok = $false } }
        'APPINIT_OFF' { $k = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows'; [void](Backup-ZRegKey $k 'appinit'); Set-ItemProperty $k -Name LoadAppInit_DLLs -Value 0 -Type DWord; Write-ZLog 'AppInit_DLLs kapatıldı.' 'OK' }
        'PROXY_OFF' { Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -Name ProxyEnable -Value 0 -Type DWord; Write-ZLog 'Proxy kapatıldı.' 'OK' }
        'HOSTS_RESET' { $h = "$env:SystemRoot\System32\drivers\etc\hosts"; Copy-Item $h (Join-Path $Global:ZBackupDir ('hosts_' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.bak')) -Force
            $def = "# Copyright (c) 1993-2009 Microsoft Corp.`r`n#`r`n# ZETX PC ARIZA TAKİP ONARIM tarafından varsayılana döndürüldü.`r`n#`r`n# 127.0.0.1       localhost`r`n# ::1             localhost`r`n"
            [IO.File]::WriteAllText($h, $def, (New-Object Text.ASCIIEncoding)); & ipconfig /flushdns | Out-Null; Write-ZLog 'HOSTS dosyası varsayılana döndürüldü (yedek alındı).' 'OK' }
        'BATTERY_REPORT' { $out = Join-Path $Global:ZReportDir ('pil-raporu-' + (Get-Date -Format 'yyyyMMdd-HHmm') + '.html'); & powercfg /batteryreport /output "$out" | Out-Null; if (Test-Path $out) { Start-Process $out; Write-ZLog "Pil raporu: $out" 'OK' } }
        'GPU_DRIVER' { $n = $Data; if (-not $n) { $n = (Get-CimInstance Win32_VideoController | Select-Object -First 1).Name }
            $url = 'https://www.intel.com.tr/content/www/tr/tr/support/detect.html'
            if ($n -match 'NVIDIA|GeForce|RTX|GTX') { $url = 'https://www.nvidia.com/tr-tr/drivers/' } elseif ($n -match 'AMD|Radeon') { $url = 'https://www.amd.com/en/support/download/drivers.html' }
            Start-Process $url; Write-ZLog "Sürücü sayfası açıldı: $url" }
        'OPEN_DEVMGR' { Start-Process 'devmgmt.msc' }
        'OPEN_EVENTVWR' { Start-Process 'eventvwr.msc' }
        'OPEN_RELIABILITY' { Start-Process 'perfmon.exe' '/rel' }
        'OPEN_URL' { if ($Data) { Start-Process $Data; Write-ZLog ('Açıldı: ' + $Data) } }
        'WU_DRIVERS' { Start-Process 'ms-settings:windowsupdate-optionalupdates'; Write-ZLog 'İsteğe bağlı güncellemeler (sürücüler) açıldı.' }
        default { Write-ZLog ("Bilinmeyen onarım: {0}" -f $FixId) 'ERR'; $ok = $false }
    }
    Set-ZProgress 100 'Tamamlandı'
    Write-ZLog ("═══ {0} {1} ═══" -f $title, $(if ($ok) { 'TAMAMLANDI' } else { 'SORUNLU BİTTİ' })) $(if ($ok) { 'OK' } else { 'WARN' })
    $ok
}

# ---------------------------------------------------------------------
#  PUANLAMA
# ---------------------------------------------------------------------
function Get-ZWinSat {
    try {
        $w = Get-CimInstance Win32_WinSAT -ErrorAction Stop | Select-Object -First 1
        if ($w -and $w.WinSPRLevel -gt 0) { return [pscustomobject]@{ Cpu = $w.CPUScore; Ram = $w.MemoryScore; Graphics = $w.GraphicsScore; D3D = $w.D3DScore; Disk = $w.DiskScore; Base = $w.WinSPRLevel; State = $w.WinSATAssessmentState } }
    } catch {}
    $null
}

function Invoke-ZWinSat {
    Write-ZLog 'Windows Sistem Değerlendirme Aracı (WinSAT) çalışıyor... 1–3 dakika sürebilir. Bu sırada bilgisayarı kullanmayın.'
    if (Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue) { Write-ZLog 'Dizüstü bilgisayarda şarj kablosu takılı olmalıdır.' 'WARN' }
    [void](Invoke-ZProcess "$env:SystemRoot\System32\winsat.exe" 'formal -restart clean')
    Get-ZWinSat
}

function Get-ZScores {
    param([object[]]$Findings, $WinSat, $Static)
    $crit = @($Findings | Where-Object Severity -eq 'KRİTİK').Count
    $warn = @($Findings | Where-Object Severity -eq 'UYARI').Count
    $info = @($Findings | Where-Object Severity -eq 'BİLGİ').Count
    $health = [math]::Max(0, 100 - ($crit * 14) - ($warn * 5) - ([math]::Min(10, $info)))
    $perf = $null
    if ($WinSat) { $perf = [int]((($WinSat.Cpu + $WinSat.Ram + $WinSat.Graphics + $WinSat.D3D + $WinSat.Disk) / 5) / 9.9 * 100) }
    elseif ($Static) { $perf = [int](($Static.CpuScore + [math]::Max($Static.GpuScore, 5)) / 2 + 15); if ($perf -gt 100) { $perf = 100 } }
    if ($null -eq $perf) { $perf = 50 }
    $overall = [int][math]::Round($health * 0.6 + $perf * 0.4)
    $grade = 'D'; if ($overall -ge 90) { $grade = 'S' } elseif ($overall -ge 80) { $grade = 'A' } elseif ($overall -ge 65) { $grade = 'B' } elseif ($overall -ge 50) { $grade = 'C' }
    [pscustomobject]@{ Health = $health; Performance = $perf; Overall = $overall; Grade = $grade; Critical = $crit; Warning = $warn; Info = $info }
}

# ---------------------------------------------------------------------
#  TAM TARAMA + TAKİP GEÇMİŞİ
# ---------------------------------------------------------------------
function Invoke-ZStage {
    # Bir tarama adımı hata verse bile tarama devam eder
    param([string]$Name, [scriptblock]$Block)
    try { @(& $Block) }
    catch {
        $ln = ''; try { $ln = $_.InvocationInfo.ScriptLineNumber } catch {}
        Write-ZLog ("{0} adımında hata: {1} (satır {2})" -f $Name, $_.Exception.Message, $ln) 'ERR'
        @()
    }
}

function Invoke-ZFullScan {
    $all = @()
    Set-ZProgress 5 'Donanım taranıyor'; $all += Invoke-ZStage 'Donanım' { Test-ZHardware }
    Set-ZProgress 30 'Sistem arızaları'; $all += Invoke-ZStage 'Sistem arızaları' { Test-ZSystemErrors 30 }
    Set-ZProgress 50 'Windows durumu'; $all += Invoke-ZStage 'Windows durumu' { Test-ZWindowsState }
    Set-ZProgress 62 'Geri yükleme noktası'; $all += Invoke-ZStage 'Geri yükleme' { Test-ZRestore }
    Set-ZProgress 65 'Sürücü ve BIOS (Windows Update)'; $all += Invoke-ZStage 'Sürücü/BIOS' { Test-ZDriversBios }
    Set-ZProgress 75 'Güvenlik / kayıt defteri'; $all += Invoke-ZStage 'Güvenlik' { Test-ZSecurityTamper }
    Set-ZProgress 85 'Kayıt defteri sorunları'
    $reg = @(Invoke-ZStage 'Kayıt defteri' { Get-ZRegistryIssues })
    if ($reg.Count -gt 0) {
        $sev = 'BİLGİ'; if ($reg.Count -gt 40) { $sev = 'UYARI' }
        $all += New-ZFinding $sev 'Kayıt Defteri' ("{0} geçersiz kayıt defteri girdisi" -f $reg.Count) (($reg | Group-Object Kategori | ForEach-Object { '{0}: {1}' -f $_.Name, $_.Count }) -join ' | ') 'Kayıt Defteri bölümünden yedek alarak temizleyin.'
    }
    Set-ZProgress 92 'Darboğaz analizi'
    $static = $null
    try { $static = Get-ZStaticBottleneck } catch { Write-ZLog ('Darboğaz analizi hatası: ' + $_.Exception.Message) 'ERR' }
    if (-not $static) { $static = [pscustomobject]@{ CpuScore = 40; GpuScore = 30; CpuName = '?'; GpuName = '?'; Verdict = 'Darboğaz analizi yapılamadı.'; Percent = 0; Notes = @() } }
    if ($static.Percent -ge 15) { $all += New-ZFinding 'BİLGİ' 'Darboğaz' $static.Verdict ("CPU puanı {0} / GPU puanı {1}" -f $static.CpuScore, $static.GpuScore) 'Darboğaz bölümünden oyun içi canlı ölçüm yapın.' }
    $order = @{ 'KRİTİK' = 0; 'UYARI' = 1; 'BİLGİ' = 2; 'İYİ' = 3 }
    $all = @($all | Where-Object { $_ -and $_.Severity } | Sort-Object { $order[$_.Severity] }, Category)
    $ws = $null; try { $ws = Get-ZWinSat } catch {}
    $scores = Get-ZScores $all $ws $static
    Save-ZHistory $scores $all
    Set-ZProgress 100 'Tarama tamamlandı'
    Write-ZLog ("TARAMA BİTTİ → Kritik: {0}, Uyarı: {1}, Bilgi: {2} | Sağlık: {3}/100 | ZETX Puanı: {4} ({5})" -f $scores.Critical, $scores.Warning, $scores.Info, $scores.Health, $scores.Overall, $scores.Grade) 'OK'
    [pscustomobject]@{ Findings = $all; Scores = $scores; Static = $static; Registry = $reg }
}

function Save-ZHistory { param($Scores, $Findings)
    $o = [ordered]@{ Tarih = (Get-Date).ToString('yyyy-MM-dd HH:mm'); Saglik = $Scores.Health; Performans = $Scores.Performance; Puan = $Scores.Overall; Derece = $Scores.Grade
        Kritik = $Scores.Critical; Uyari = $Scores.Warning; Bilgi = $Scores.Info; Sorunlar = @($Findings | Where-Object { $_.Severity -in 'KRİTİK', 'UYARI' } | ForEach-Object { $_.Title }) }
    try { Add-Content -Path $Global:ZHistory -Value ((New-Object PSObject -Property $o) | ConvertTo-Json -Compress -Depth 3) -Encoding UTF8 } catch {}
}

function Get-ZHistory {
    if (-not (Test-Path $Global:ZHistory)) { return @() }
    @(Get-Content $Global:ZHistory -Encoding UTF8 | Where-Object { $_.Trim() } | ForEach-Object { try { $_ | ConvertFrom-Json } catch {} })
}

function Compare-ZHistory {
    $h = @(Get-ZHistory)
    if ($h.Count -lt 2) { return $null }
    $prev = $h[$h.Count - 2]; $cur = $h[$h.Count - 1]
    $new = @($cur.Sorunlar | Where-Object { $_ -notin $prev.Sorunlar })
    $fixed = @($prev.Sorunlar | Where-Object { $_ -notin $cur.Sorunlar })
    [pscustomobject]@{ Previous = $prev; Current = $cur; New = $new; Fixed = $fixed; Delta = ($cur.Puan - $prev.Puan) }
}

# ---------------------------------------------------------------------
#  HTML RAPOR
# ---------------------------------------------------------------------
function Export-ZReport {
    param($Scan, $SysInfo, $Lic)
    $enc = { param($s) [Net.WebUtility]::HtmlEncode("$s") }
    $sb = New-Object Text.StringBuilder
    $file = Join-Path $Global:ZReportDir ('ZETX-Rapor-' + $env:COMPUTERNAME + '-' + (Get-Date -Format 'yyyyMMdd-HHmm') + '.html')
    [void]$sb.Append(@"
<!doctype html><html lang="tr"><head><meta charset="utf-8"><title>ZETX PC Arıza Raporu</title>
<style>
body{background:#0b0f14;color:#dfe7ee;font-family:Segoe UI,Arial,sans-serif;margin:0;padding:28px}
h1{color:#00e5ff;letter-spacing:2px;margin:0}h2{color:#00e5ff;border-bottom:1px solid #1f2a36;padding-bottom:6px;margin-top:30px}
.sub{color:#7f8c99;margin-top:4px}.cards{display:flex;gap:14px;flex-wrap:wrap;margin-top:18px}
.card{background:#121a23;border:1px solid #1f2a36;border-radius:10px;padding:14px 18px;min-width:150px}
.card b{display:block;font-size:30px;color:#00e5ff}.card span{color:#7f8c99;font-size:12px;text-transform:uppercase}
table{width:100%;border-collapse:collapse;margin-top:10px;font-size:14px}td,th{padding:8px 10px;border-bottom:1px solid #1f2a36;text-align:left;vertical-align:top}
th{color:#7f8c99;font-weight:600;font-size:12px;text-transform:uppercase}
.KRİTİK{color:#ff4d5e;font-weight:700}.UYARI{color:#ffb020;font-weight:700}.BİLGİ{color:#4db8ff}.İYİ{color:#2ee59d}
.foot{margin-top:40px;color:#7f8c99;font-size:12px;border-top:1px solid #1f2a36;padding-top:12px}
</style></head><body>
<h1>ZETX PC ARIZA TAKİP ONARIM</h1><div class="sub">Bilgisayar Sağlık Raporu — $(& $enc $env:COMPUTERNAME) — $((Get-Date).ToString('dd.MM.yyyy HH:mm'))</div>
"@)
    if ($Scan -and $Scan.Scores) {
        $s = $Scan.Scores
        [void]$sb.Append("<div class='cards'><div class='card'><span>ZETX Puanı</span><b>$($s.Overall) ($($s.Grade))</b></div><div class='card'><span>Sağlık</span><b>$($s.Health)</b></div><div class='card'><span>Performans</span><b>$($s.Performance)</b></div><div class='card'><span>Kritik</span><b style='color:#ff4d5e'>$($s.Critical)</b></div><div class='card'><span>Uyarı</span><b style='color:#ffb020'>$($s.Warning)</b></div><div class='card'><span>Bilgi</span><b style='color:#4db8ff'>$($s.Info)</b></div></div>")
    }
    if ($SysInfo) {
        [void]$sb.Append('<h2>Sistem Bilgisi</h2><table>')
        foreach ($p in 'Bilgisayar', 'Isletim', 'Islemci', 'EkranKarti', 'Bellek', 'Anakart', 'BIOS', 'SistemDiski', 'KurulumTarihi', 'CalismaSuresi') {
            [void]$sb.Append("<tr><th style='width:180px'>$p</th><td>$(& $enc $SysInfo.$p)</td></tr>")
        }
        [void]$sb.Append('</table>')
    }
    if ($Scan -and $Scan.Static) {
        [void]$sb.Append("<h2>Darboğaz Analizi</h2><p>İşlemci puanı: <b>$($Scan.Static.CpuScore)</b> — Ekran kartı puanı: <b>$($Scan.Static.GpuScore)</b><br>$(& $enc $Scan.Static.Verdict)</p>")
        if ($Scan.Static.Notes) { [void]$sb.Append('<ul>' + (($Scan.Static.Notes | ForEach-Object { "<li>$(& $enc $_)</li>" }) -join '') + '</ul>') }
    }
    if ($Scan -and $Scan.Findings) {
        [void]$sb.Append('<h2>Bulgular ve Öneriler</h2><table><tr><th>Önem</th><th>Kategori</th><th>Sorun</th><th>Ayrıntı</th><th>Öneri</th></tr>')
        foreach ($x in $Scan.Findings) { [void]$sb.Append("<tr><td class='$($x.Severity)'>$($x.Severity)</td><td>$(& $enc $x.Category)</td><td>$(& $enc $x.Title)</td><td>$(& $enc $x.Detail)</td><td>$(& $enc $x.Advice)</td></tr>") }
        [void]$sb.Append('</table>')
    }
    $disks = Get-ZDiskHealth
    if ($disks) {
        [void]$sb.Append('<h2>Disk Sağlığı</h2><table><tr><th>Disk</th><th>Tür</th><th>Sağlık</th><th>Sıcaklık</th><th>Aşınma</th><th>Okuma/Yazma Hatası</th><th>Çalışma</th></tr>')
        foreach ($d in $disks) { [void]$sb.Append("<tr><td>$(& $enc $d.Disk)</td><td>$($d.Tur) / $($d.Baglanti)</td><td>$($d.Saglik)</td><td>$($d.Sicaklik)</td><td>$($d.Asinma)</td><td>$($d.OkumaHata) / $($d.YazmaHata)</td><td>$($d.CalismaSaati)</td></tr>") }
        [void]$sb.Append('</table>')
    }
    $lictext = ' — Ücretsiz Sürüm'
    [void]$sb.Append("<div class='foot'>$($Global:ZETX.AppName) v$($Global:ZETX.Version)$lictext<br>Geliştirici: $($Global:ZETX.Owner) ($($Global:ZETX.Brand) / $($Global:ZETX.Channel)) — $($Global:ZETX.Email) — Discord: $($Global:ZETX.Discord)</div></body></html>")
    [IO.File]::WriteAllText($file, $sb.ToString(), (New-Object Text.UTF8Encoding($true)))
    $file
}


# ---------------------------------------------------------------------
#  SÜRÜCÜ VE BIOS ENVANTERİ
# ---------------------------------------------------------------------
function Get-ZVendorDriverUrl { param([string]$Maker, [string]$Device)
    $m = "$Maker $Device"
    if ($m -match 'NVIDIA') { return 'https://www.nvidia.com/tr-tr/drivers/' }
    if ($m -match 'AMD|Advanced Micro|ATI |Radeon') { return 'https://www.amd.com/en/support/download/drivers.html' }
    if ($m -match 'Intel') { return 'https://www.intel.com/content/www/us/en/support/detect.html' }
    if ($m -match 'Realtek') { return 'https://www.realtek.com/Download/List?cate_id=593' }
    if ($m -match 'Killer|Qualcomm') { return 'https://www.intel.com/content/www/us/en/download/19779/intel-killer-performance-suite.html' }
    if ($m -match 'MediaTek') { return 'https://www.mediatek.com/products/connectivity-and-networking' }
    'https://www.google.com/search?q=' + [uri]::EscapeDataString("$Device driver download")
}

function Get-ZBoardSupportUrl { param([string]$Maker, [string]$Product)
    $q = [uri]::EscapeDataString($Product)
    if ($Maker -match 'ASUS') { return "https://www.asus.com/tr/searchresult?searchType=support&searchKey=$q" }
    if ($Maker -match 'Micro-Star|MSI') { return "https://www.msi.com/search/$q" }
    if ($Maker -match 'Gigabyte') { return "https://www.gigabyte.com/Search?kw=$q" }
    if ($Maker -match 'ASRock') { return "https://www.asrock.com/support/index.tr.asp?cat=BIOS" }
    if ($Maker -match 'Dell') { return 'https://www.dell.com/support/home/tr-tr' }
    if ($Maker -match 'HP|Hewlett') { return 'https://support.hp.com/tr-tr/drivers' }
    if ($Maker -match 'Lenovo') { return 'https://pcsupport.lenovo.com/tr/tr' }
    if ($Maker -match 'Acer') { return 'https://www.acer.com/tr-tr/support/drivers-and-manuals' }
    if ($Maker -match 'Monster') { return 'https://www.monsternotebook.com.tr/destek/' }
    if ($Maker -match 'Casper') { return 'https://www.casper.com.tr/destek' }
    'https://www.google.com/search?q=' + [uri]::EscapeDataString("$Maker $Product BIOS")
}

function Get-ZBiosInfo {
    $bios = Get-CimInstance Win32_BIOS; $bb = Get-CimInstance Win32_BaseBoard; $cs = Get-CimInstance Win32_ComputerSystem
    $sb = 'Bilinmiyor'; try { if (Confirm-SecureBootUEFI -ErrorAction Stop) { $sb = 'Açık' } else { $sb = 'Kapalı' } } catch { $sb = 'Desteklenmiyor / Legacy BIOS' }
    $tpm = 'Bilinmiyor'; try { $t = Get-Tpm -ErrorAction Stop; if ($t.TpmPresent) { $tpm = $(if ($t.TpmReady) { 'Var ve hazır' } else { 'Var (hazır değil)' }) } else { $tpm = 'Yok / kapalı' } } catch {}
    $tpmVer = ''; try { $tv = Get-CimInstance -Namespace root/cimv2/Security/MicrosoftTpm -ClassName Win32_Tpm -ErrorAction Stop; if ($tv) { $tpmVer = (("$($tv.SpecVersion)") -split ',')[0] } } catch {}
    $age = $null; if ($bios.ReleaseDate) { $age = ((Get-Date) - $bios.ReleaseDate).Days }
    [pscustomobject]@{
        Uretici = "$($bb.Manufacturer)".Trim(); Model = "$($bb.Product)".Trim(); Sistem = ("{0} {1}" -f $cs.Manufacturer, $cs.Model).Trim()
        BiosUretici = "$($bios.Manufacturer)".Trim(); BiosSurum = "$($bios.SMBIOSBIOSVersion)".Trim()
        BiosTarih = $(if ($bios.ReleaseDate) { $bios.ReleaseDate.ToString('dd.MM.yyyy') } else { '?' }); BiosYas = $age
        SMBIOS = ("{0}.{1}" -f $bios.SMBIOSMajorVersion, $bios.SMBIOSMinorVersion)
        SecureBoot = $sb; TPM = ($tpm + $(if ($tpmVer) { " (TPM $tpmVer)" } else { '' }))
        Url = Get-ZBoardSupportUrl "$($bb.Manufacturer)" "$($bb.Product)"
    }
}

$Global:ZDrvCache = Join-Path $Global:ZDataDir 'surucu-guncellemeleri.json'

function Find-ZDriverUpdates {
    # Windows Update kataloğunda bu bilgisayar için bekleyen GERÇEK sürücü güncellemeleri (12 saat önbellekli)
    param([switch]$Force)
    if (-not $Force -and (Test-Path $Global:ZDrvCache)) {
        try {
            $c = [IO.File]::ReadAllText($Global:ZDrvCache, [Text.Encoding]::UTF8) | ConvertFrom-Json
            if ($c.Zaman -and ((Get-Date) - [datetime]::ParseExact("$($c.Zaman)", 'yyyy-MM-dd HH:mm', $null)).TotalHours -lt 12) {
                Write-ZLog ("Windows Update sürücü bilgisi önbellekten alındı ({0})." -f $c.Zaman)
                return @($c.Liste | Where-Object { $_ })
            }
        } catch {}
    }
    Write-ZLog 'Windows Update sürücü kataloğu sorgulanıyor (30 sn – 2 dk sürebilir)...'
    $out = @()
    try {
        $ses = New-Object -ComObject Microsoft.Update.Session
        $sr = $ses.CreateUpdateSearcher()
        $res = $sr.Search("IsInstalled=0 and Type='Driver' and IsHidden=0")
        foreach ($u in $res.Updates) {
            $dt = ''; try { $dt = ([datetime]$u.DriverVerDate).ToString('yyyy-MM-dd') } catch {}
            $out += [pscustomobject]@{ Baslik = "$($u.Title)"; Uretici = "$($u.DriverManufacturer)"; Sinif = "$($u.DriverClass)"; Model = "$($u.DriverModel)"; HWID = "$($u.DriverHardwareID)"; Tarih = $dt }
        }
        Write-ZLog ("Windows Updateʼte bu bilgisayar için {0} sürücü güncellemesi var." -f $out.Count) 'OK'
        try { [IO.File]::WriteAllText($Global:ZDrvCache, ([pscustomobject]@{ Zaman = (Get-Date).ToString('yyyy-MM-dd HH:mm'); Liste = @($out) } | ConvertTo-Json -Depth 4), (New-Object Text.UTF8Encoding($false))) } catch {}
    } catch { Write-ZLog ('Windows Update sorgulanamadı: ' + $_.Exception.Message) 'ERR'; return $null }
    $out
}

function Get-ZGpuVendorFromHwid { param([string[]]$Ids)
    $j = ($Ids -join ' ').ToUpper()
    if ($j -match 'VEN_10DE') { return 'NVIDIA' }; if ($j -match 'VEN_1002') { return 'AMD' }; if ($j -match 'VEN_8086') { return 'Intel' }
    ''
}

function Get-ZDriverInventory {
    # Durum yalnızca GERÇEK bilgiye göre verilir:
    #  - Windows Updateʼte o aygıt için yeni sürücü varsa  -> 'Güncelleme var'
    #  - NVIDIA/AMD ekran kartı sürücüsü 90+ gün eskiyse   -> 'Yeni sürüm yayınlanmış' (bu üreticiler ~ayda bir sürücü çıkarır)
    #  - Ekran kartında Microsoft temel sürücüsü varsa      -> 'Sürücü yok'
    #  - Aksi halde 'Güncel' (tarihi eski olsa bile üretici yeni sürüm yayınlamamış olabilir; indirilebilir sürüm yoksa uyarı gösterilmez)
    param($Updates = $null)
    Write-ZLog 'Yüklü sürücüler okunuyor (10–20 sn sürebilir)...'
    $hw = @{}
    try { foreach ($pe in @(Get-CimInstance Win32_PnPEntity -ErrorAction Stop)) { if ($pe.DeviceID) { $hw["$($pe.DeviceID)".ToUpper()] = @($pe.HardwareID) } } } catch {}
    $upd = @($Updates | Where-Object { $_ -and $_.HWID })
    $rows = @()
    $all = @(Get-CimInstance Win32_PnPSignedDriver -ErrorAction SilentlyContinue | Where-Object { $_.DeviceName -and $_.DriverVersion })
    foreach ($d in $all) {
        $cls = "$($d.DeviceClass)".ToUpper(); $name = "$($d.DeviceName)"; $kat = $null
        switch ($cls) {
            'DISPLAY' { if ($name -notmatch 'Virtual|Parsec|Remote|Meta|Mirage|Indirect') { $kat = 'Ekran Kartı' } }
            'NET' { if ($name -notmatch 'WAN Miniport|Kernel Debug|Wi-Fi Direct|Virtual|Bluetooth Device \(Personal|Teredo|isatap|VPN|TAP-|Hyper-V') { $kat = 'Ağ' } }
            'MEDIA' { if ($name -notmatch 'Microsoft Streaming|Virtual Audio|Steam Streaming|Oculus') { $kat = 'Ses' } }
            'HDC' { $kat = 'Depolama' }
            'SCSIADAPTER' { $kat = 'Depolama' }
            'BLUETOOTH' { if ($name -match 'Adapter|Radio|Wireless|Intel|Realtek|Qualcomm|MediaTek') { $kat = 'Bluetooth' } }
            'SYSTEM' { if ($name -match 'Chipset|SMBus|PSP|GPIO|Management Engine|Serial IO|Platform|Ryzen|Dynamic Tuning|Thermal') { $kat = 'Yonga Seti' } }
            'USB' { if ($name -match 'xHCI|eXtensible|Host Controller') { $kat = 'USB' } }
        }
        if (-not $kat) { continue }
        $date = $null; try { if ($d.DriverDate) { $date = [datetime]$d.DriverDate } } catch {}
        $age = $null; if ($date) { $age = [int]((Get-Date) - $date).TotalDays }
        $maker = "$($d.Manufacturer)"; if (-not $maker) { $maker = "$($d.DriverProviderName)" }
        $ids = @(); $k = "$($d.DeviceID)".ToUpper(); if ($hw.ContainsKey($k)) { $ids = @($hw[$k]) }; if ($d.HardWareID) { $ids += "$($d.HardWareID)" }
        $ids = @($ids | Where-Object { $_ } | ForEach-Object { "$_".ToUpper() })
        $state = 'Güncel'; $act = ''; $url = ''; $newVer = ''
        foreach ($u in $upd) {
            if ($ids -contains "$($u.HWID)".ToUpper()) {
                $ud = $null; try { $ud = [datetime]::ParseExact("$($u.Tarih)", 'yyyy-MM-dd', $null) } catch {}
                if (-not $date -or -not $ud -or $ud -gt $date) { $state = 'Güncelleme var'; $act = 'GÜNCELLE'; $url = 'WU'; $newVer = $u.Baslik; break }
            }
        }
        if ($kat -eq 'Ekran Kartı') {
            $vend = Get-ZGpuVendorFromHwid $ids
            if ("$($d.DriverProviderName)" -eq 'Microsoft' -or $name -match 'Basic Display|Temel Görüntü') { $state = 'Sürücü yok'; $act = 'İNDİR'; $url = Get-ZVendorDriverUrl $vend $name }
            elseif ($state -eq 'Güncel' -and $vend -in 'NVIDIA', 'AMD' -and $null -ne $age -and $age -ge 90) { $state = 'Yeni sürüm yayınlanmış'; $act = 'İNDİR'; $url = Get-ZVendorDriverUrl $vend $name }
        }
        $rows += [pscustomobject]@{ Kategori = $kat; Aygit = $name; Uretici = $maker; Surum = "$($d.DriverVersion)"; Tarih = $(if ($date) { $date.ToString('dd.MM.yyyy') } else { '?' }); Yas = $(if ($null -ne $age) { "$age gün" } else { '?' }); Durum = $state; Islem = $act; Url = $url; Yeni = $newVer; _Age = $(if ($null -ne $age) { $age } else { 0 }) }
    }
    $ord = @{ 'Ekran Kartı' = 0; 'Yonga Seti' = 1; 'Ağ' = 2; 'Ses' = 3; 'Depolama' = 4; 'USB' = 5; 'Bluetooth' = 6 }
    @($rows | Sort-Object { $ord[$_.Kategori] }, Aygit -Unique)
}

function Test-ZDriversBios {
    $f = @()
    try { $b = Get-ZBiosInfo; if ($b.SecureBoot -eq 'Kapalı') { $f += New-ZFinding 'BİLGİ' 'BIOS' 'Secure Boot kapalı' '' 'Bazı oyunların hile koruması (ör. Battlefield 6, Valorant) Secure Boot ister. BIOSʼtan açabilirsiniz.' } } catch {}
    try {
        $upd = Find-ZDriverUpdates
        foreach ($d in @(Get-ZDriverInventory $upd | Where-Object { $_.Islem })) {
            switch ($d.Durum) {
                'Güncelleme var' { $f += New-ZFinding 'UYARI' 'Sürücü' ("{0} için sürücü güncellemesi var: {1}" -f $d.Kategori, $d.Aygit) ("Yüklü: {0} ({1})  →  Windows Update: {2}" -f $d.Surum, $d.Tarih, $d.Yeni) 'Ayarlar > Windows Update > İsteğe bağlı güncellemeler bölümünden kurun.' 'WU_DRIVERS' '' 'GÜNCELLE' }
                'Yeni sürüm yayınlanmış' { $f += New-ZFinding 'BİLGİ' 'Sürücü' ("Ekran kartı için daha yeni sürücü yayınlanmış: {0}" -f $d.Aygit) ("Yüklü: {0} ({1}, {2})" -f $d.Surum, $d.Tarih, $d.Yas) 'Üretici her ay yeni sürücü yayınlar; yeni oyunlarda performans ve kararlılık için güncelleyin.' 'OPEN_URL' $d.Url 'İNDİR' }
                'Sürücü yok' { $f += New-ZFinding 'KRİTİK' 'Sürücü' ("Ekran kartı sürücüsü yüklü değil: {0}" -f $d.Aygit) '' 'Ekran kartı üreticisinin sitesinden sürücüyü kurun.' 'OPEN_URL' $d.Url 'İNDİR' }
            }
        }
    } catch {}
    $f
}

# ---------------------------------------------------------------------
#  SİSTEM GERİ YÜKLEME NOKTASI DURUMU
# ---------------------------------------------------------------------
function Get-ZRestoreInfo {
    $r = [ordered]@{ Enabled = $true; Count = 0; Last = $null; Days = $null; Need = $false; Text = '' }
    try { $p = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' -ErrorAction Stop; if ((ConvertTo-ZInt $p.DisableSR) -eq 1) { $r.Enabled = $false } } catch {}
    try {
        $cl = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SPP\Clients' -ErrorAction Stop
        $v = $cl.'{09F7EDC5-294E-4180-AF6A-FB0E6A0E9513}'
        if (-not $v -or -not ("$v" -match [regex]::Escape($env:SystemDrive))) { $r.Enabled = $false }
    } catch { }
    try {
        $pts = @(Get-ComputerRestorePoint -ErrorAction Stop)
        $r.Count = $pts.Count
        if ($pts.Count) {
            $last = $pts | Sort-Object { ConvertTo-ZNum $_.SequenceNumber } | Select-Object -Last 1
            $r.Last = [Management.ManagementDateTimeConverter]::ToDateTime("$($last.CreationTime)")
            $r.Days = [int]((Get-Date) - $r.Last).TotalDays
        }
    } catch {}
    if (-not $r.Enabled) { $r.Need = $true; $r.Text = 'Sistem koruması (geri yükleme) kapalı — bir sorun çıkarsa bilgisayarı eski haline döndüremezsiniz.' }
    elseif ($r.Count -eq 0) { $r.Need = $true; $r.Text = 'Hiç sistem geri yükleme noktası yok. Onarımlardan önce bir geri yükleme noktası oluşturmanız önerilir.' }
    elseif ($r.Days -gt 14) { $r.Need = $true; $r.Text = ('Son geri yükleme noktası {0} gün önce ({1}). Yeni bir geri yükleme noktası oluşturmanız önerilir.' -f $r.Days, $r.Last.ToString('dd.MM.yyyy')) }
    [pscustomobject]$r
}

function Test-ZRestore {
    $f = @()
    $ri = Get-ZRestoreInfo
    if (-not $ri.Enabled) { $f += New-ZFinding 'UYARI' 'Güvenlik' 'Sistem geri yükleme kapalı' 'Sistem koruması etkin değil.' 'Geri yükleme noktası oluşturulduğunda sistem koruması otomatik açılır.' 'RESTORE_POINT' '' 'OLUŞTUR' }
    elseif ($ri.Count -eq 0) { $f += New-ZFinding 'UYARI' 'Güvenlik' 'Hiç geri yükleme noktası yok' '' 'Onarım ve sürücü değişikliklerinden önce bir geri yükleme noktası oluşturun.' 'RESTORE_POINT' '' 'OLUŞTUR' }
    elseif ($ri.Days -gt 14) { $f += New-ZFinding 'BİLGİ' 'Güvenlik' ("Son geri yükleme noktası {0} gün önce" -f $ri.Days) $ri.Last.ToString('dd.MM.yyyy HH:mm') 'Güncel bir geri yükleme noktası oluşturmanız önerilir.' 'RESTORE_POINT' '' 'OLUŞTUR' }
    $f
}

# ---------------------------------------------------------------------
#  OYUN FPS TAHMİNİ
#  Taban değerler: 1080p / Yüksek ayar, GPU puanı 50 ve CPU puanı 60 için
# ---------------------------------------------------------------------
$Global:ZGames = @(
    @{ Ad = 'Battlefield 6'; Gpu = 115; Cpu = 160; Cap = 0 }, @{ Ad = 'Counter-Strike 2'; Gpu = 380; Cpu = 330; Cap = 0 },
    @{ Ad = 'Valorant'; Gpu = 650; Cpu = 450; Cap = 0 }, @{ Ad = 'Fortnite (DX12)'; Gpu = 150; Cpu = 220; Cap = 0 },
    @{ Ad = 'Call of Duty: Warzone'; Gpu = 130; Cpu = 190; Cap = 0 }, @{ Ad = 'PUBG: Battlegrounds'; Gpu = 175; Cpu = 190; Cap = 0 },
    @{ Ad = 'Apex Legends'; Gpu = 200; Cpu = 260; Cap = 300 }, @{ Ad = 'League of Legends'; Gpu = 600; Cpu = 400; Cap = 0 },
    @{ Ad = 'GTA V'; Gpu = 170; Cpu = 160; Cap = 0 }, @{ Ad = 'Red Dead Redemption 2'; Gpu = 85; Cpu = 150; Cap = 0 },
    @{ Ad = 'Cyberpunk 2077'; Gpu = 88; Cpu = 140; Cap = 0 }, @{ Ad = 'Elden Ring'; Gpu = 95; Cpu = 140; Cap = 60 },
    @{ Ad = 'Black Myth: Wukong'; Gpu = 62; Cpu = 130; Cap = 0 }, @{ Ad = 'Marvel Rivals'; Gpu = 105; Cpu = 160; Cap = 0 },
    @{ Ad = 'Rainbow Six Siege'; Gpu = 330; Cpu = 350; Cap = 0 }, @{ Ad = 'Rocket League'; Gpu = 400; Cpu = 420; Cap = 0 },
    @{ Ad = 'Forza Horizon 5'; Gpu = 125; Cpu = 190; Cap = 0 }, @{ Ad = 'EA SPORTS FC'; Gpu = 220; Cpu = 260; Cap = 0 },
    @{ Ad = 'Helldivers 2'; Gpu = 85; Cpu = 110; Cap = 0 }, @{ Ad = 'The Witcher 3 (Next-Gen)'; Gpu = 110; Cpu = 150; Cap = 0 },
    @{ Ad = 'Euro Truck Simulator 2'; Gpu = 160; Cpu = 140; Cap = 0 }, @{ Ad = 'Minecraft (Java)'; Gpu = 450; Cpu = 280; Cap = 0 }
)

$Global:ZGameFile = Join-Path $Global:ZDataDir 'ozel-oyunlar.json'
$Global:ZGameProfiles = [ordered]@{
    'Çok hafif (e-spor: CS2, Valorant, LoL)' = @{ Gpu = 500; Cpu = 400 }
    'Hafif (Fortnite, Apex, Rocket League)'  = @{ Gpu = 190; Cpu = 240 }
    'Orta (GTA V, Warzone, PUBG, FC)'         = @{ Gpu = 140; Cpu = 170 }
    'Ağır (Cyberpunk, RDR2, Battlefield)'     = @{ Gpu = 90; Cpu = 145 }
    'Çok ağır (Wukong, Alan Wake 2)'          = @{ Gpu = 60; Cpu = 120 }
}

function Get-ZCustomGames {
    if (-not (Test-Path $Global:ZGameFile)) { return @() }
    try { @([IO.File]::ReadAllText($Global:ZGameFile, [Text.Encoding]::UTF8) | ConvertFrom-Json) | Where-Object { $_ -and $_.Ad } } catch { @() }
}

function Save-ZCustomGames { param([object[]]$Games)
    $arr = @($Games | ForEach-Object { [pscustomobject]@{ Ad = "$($_.Ad)"; Gpu = [double](ConvertTo-ZNum $_.Gpu); Cpu = [double](ConvertTo-ZNum $_.Cpu); Cap = [int](ConvertTo-ZInt $_.Cap); Not = "$($_.Not)" } })
    $json = '[]'; if ($arr.Count -gt 0) { $json = ConvertTo-Json -InputObject $arr -Depth 3 }
    [IO.File]::WriteAllText($Global:ZGameFile, $json, (New-Object Text.UTF8Encoding($false)))
}

function Get-ZFpsFactors { param([string]$Resolution, [string]$Quality)
    $resF = @{ '1080p' = 1.0; '1440p' = 0.70; '4K' = 0.40 }[$Resolution]; if (-not $resF) { $resF = 1.0 }
    $qF = @{ 'Düşük' = 1.75; 'Orta' = 1.35; 'Yüksek' = 1.0; 'Ultra' = 0.82 }[$Quality]; if (-not $qF) { $qF = 1.0 }
    $qC = @{ 'Düşük' = 1.08; 'Orta' = 1.04; 'Yüksek' = 1.0; 'Ultra' = 0.96 }[$Quality]; if (-not $qC) { $qC = 1.0 }
    @{ Res = $resF; Q = $qF; QC = $qC }
}

function Get-ZRawFps { param([double]$GpuBase, [double]$CpuBase, [int]$CpuScore, [int]$GpuScore, [string]$Resolution, [string]$Quality, [double]$RamFactor = 1.0)
    $f = Get-ZFpsFactors $Resolution $Quality
    $gs = [math]::Max(3, $GpuScore); $cs = [math]::Max(5, $CpuScore)
    $g = $GpuBase * [math]::Pow($gs / 50.0, 0.95) * $f.Res * $f.Q
    $c = $CpuBase * [math]::Pow($cs / 60.0, 0.85) * $RamFactor * $f.QC
    [math]::Min($g, $c)
}

function New-ZCustomGame {
    # Kullanıcı oyunu: profil tabanı + (isteğe bağlı) kendi ölçtüğü FPS ile kalibrasyon
    param([string]$Name, [string]$GameProfile, [double]$MeasuredFps = 0, [string]$MeasuredRes = '1080p', [string]$MeasuredQuality = 'Yüksek', [int]$Cap = 0, [int]$CpuScore = 60, [int]$GpuScore = 50, [double]$RamFactor = 1.0)
    $pr = $Global:ZGameProfiles[$GameProfile]; if (-not $pr) { $pr = @{ Gpu = 120; Cpu = 160 } }
    $g = [double]$pr.Gpu; $c = [double]$pr.Cpu; $note = $GameProfile
    if ($MeasuredFps -gt 0) {
        $est = Get-ZRawFps $g $c $CpuScore $GpuScore $MeasuredRes $MeasuredQuality $RamFactor
        if ($est -gt 0) { $k = $MeasuredFps / $est; $g *= $k; $c *= $k; $note = ('Kalibre: {0} FPS @ {1} {2}' -f $MeasuredFps, $MeasuredRes, $MeasuredQuality) }
    }
    [pscustomobject]@{ Ad = $Name; Gpu = [math]::Round($g, 1); Cpu = [math]::Round($c, 1); Cap = $Cap; Not = $note }
}

function Get-ZFpsEstimate {
    param([int]$CpuScore, [int]$GpuScore, [string]$Resolution = '1080p', [string]$Quality = 'Yüksek', [double]$RamFactor = 1.0)
    $list = @()
    foreach ($g in $Global:ZGames) { $list += [pscustomobject]@{ Ad = $g.Ad; Gpu = $g.Gpu; Cpu = $g.Cpu; Cap = $g.Cap; Ozel = $false } }
    foreach ($g in @(Get-ZCustomGames)) { $list += [pscustomobject]@{ Ad = $g.Ad; Gpu = (ConvertTo-ZNum $g.Gpu 100); Cpu = (ConvertTo-ZNum $g.Cpu 150); Cap = (ConvertTo-ZInt $g.Cap); Ozel = $true } }
    $list | ForEach-Object { Get-ZFpsEstimateOne $_ $CpuScore $GpuScore $Resolution $Quality $RamFactor }
}

function Get-ZFpsEstimateOne {
    param($g, [int]$CpuScore, [int]$GpuScore, [string]$Resolution = '1080p', [string]$Quality = 'Yüksek', [double]$RamFactor = 1.0)
    $fc = Get-ZFpsFactors $Resolution $Quality
    $gs = [math]::Max(3, $GpuScore); $cs = [math]::Max(5, $CpuScore)
    & {
        $gpuFps = $g.Gpu * [math]::Pow($gs / 50.0, 0.95) * $fc.Res * $fc.Q
        $cpuFps = $g.Cpu * [math]::Pow($cs / 60.0, 0.85) * $RamFactor * $fc.QC
        $fps = [math]::Min($gpuFps, $cpuFps); $lim = $(if ($gpuFps -le $cpuFps) { 'Ekran kartı' } else { 'İşlemci' })
        if ($g.Cap -gt 0 -and $fps -gt $g.Cap) { $fps = $g.Cap; $lim = ('Oyun motoru ({0} FPS kilidi)' -f $g.Cap) }
        $fps = [int][math]::Round($fps)
        $rate = 'Zayıf'; if ($fps -ge 144) { $rate = 'Mükemmel' } elseif ($fps -ge 90) { $rate = 'Çok iyi' } elseif ($fps -ge 60) { $rate = 'Akıcı' } elseif ($fps -ge 40) { $rate = 'Oynanabilir' }
        if ($g.Cap -gt 0 -and $fps -eq $g.Cap -and $fps -lt 90) { $rate = 'Akıcı (kilitli)' }
        [pscustomobject]@{ Ozel = [bool]$g.Ozel; Oyun = $g.Ad; Fps = $fps; Aralik = ('{0}–{1}' -f [int]($fps * 0.85), [int]($fps * 1.12)); Sinirlayan = $lim; Degerlendirme = $rate }
    }
}

function Get-ZDisplayInfo {
    $w = 1920; $h = 1080; $hz = 60
    try {
        $v = Get-CimInstance Win32_VideoController | Where-Object { $_.CurrentHorizontalResolution } | Sort-Object CurrentHorizontalResolution -Descending | Select-Object -First 1
        if ($v) { $w = ConvertTo-ZInt $v.CurrentHorizontalResolution 1920; $h = ConvertTo-ZInt $v.CurrentVerticalResolution 1080; $hz = ConvertTo-ZInt $v.CurrentRefreshRate 60 }
    } catch {}
    $res = '1080p'; if ($w -ge 3200) { $res = '4K' } elseif ($w -ge 2400) { $res = '1440p' }
    [pscustomobject]@{ Width = $w; Height = $h; Hz = $hz; Class = $res }
}

# ---------------------------------------------------------------------
#  GERÇEK FPS ÖLÇÜMÜ (Intel PresentMon — açık kaynak, MIT lisanslı)
# ---------------------------------------------------------------------
$Global:ZPresentMonUrl = 'https://github.com/GameTechDev/PresentMon/releases/download/v2.6.0/PresentMon-2.6.0-x64.exe'
$Global:ZPresentMon = Join-Path $Global:ZDataDir 'Araclar\PresentMon.exe'
$Global:ZFpsLog = Join-Path $Global:ZDataDir 'fps-olcumleri.jsonl'

function Install-ZPresentMon {
    if ((Test-Path $Global:ZPresentMon) -and (Get-Item $Global:ZPresentMon).Length -gt 500KB) { return $true }
    $dir = Split-Path $Global:ZPresentMon; if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Write-ZLog 'FPS ölçüm motoru (Intel PresentMon) indiriliyor... (yalnızca ilk kullanımda)'
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $Global:ZPresentMonUrl -OutFile $Global:ZPresentMon -UseBasicParsing -ErrorAction Stop
        Unblock-File $Global:ZPresentMon -ErrorAction SilentlyContinue
        Write-ZLog 'PresentMon hazır.' 'OK'; return $true
    } catch { Write-ZLog ('PresentMon indirilemedi: ' + $_.Exception.Message + ' — İnternet bağlantısını kontrol edin.') 'ERR'; return $false }
}

function Get-ZGameCandidates {
    # Ekran kartını en çok kullanan pencereli işlemler (oyun adayları)
    $util = @{}
    try { $a = Read-ZGpuRaw; Start-Sleep -Milliseconds 600; $b = Read-ZGpuRaw; foreach ($kv in (Get-ZGpuUsage $a $b).PerPid.GetEnumerator()) { $util[[int]$kv.Key] = [int][math]::Round($kv.Value) } } catch {}
    $skip = 'dwm|explorer|ShellExperienceHost|SearchHost|StartMenuExperienceHost|TextInputHost|powershell|pwsh|ZETX|ApplicationFrameHost|SystemSettings|msedgewebview2'
    $list = @()
    foreach ($p in @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 -and $_.ProcessName -notmatch $skip })) {
        $u = 0; if ($util.ContainsKey($p.Id)) { $u = $util[$p.Id] }
        $title = "$($p.MainWindowTitle)"; if ($title.Length -gt 50) { $title = $title.Substring(0, 50) + '…' }
        $list += [pscustomobject]@{ Name = $p.ProcessName + '.exe'; Id = $p.Id; Gpu = $u; Text = ('{0}.exe — {1} (GPU %{2})' -f $p.ProcessName, $title, $u) }
    }
    @($list | Sort-Object Gpu -Descending)
}

function Measure-ZFps {
    param([string]$ProcessName, [int]$Seconds = 30, [string]$Label = 'ÖLÇÜM')
    if (-not (Install-ZPresentMon)) { return $null }
    $csv = Join-Path $env:TEMP ('zetx-fps-' + (Get-Date -Format 'yyyyMMddHHmmss') + '.csv')
    Write-ZLog ("{0} için {1} saniyelik FPS ölçümü başladı. Oyunda normal oynamaya devam edin." -f $ProcessName, $Seconds)
    $sets = @(
        ('--process_name "{0}" --output_file "{1}" --timed {2} --terminate_after_timed --stop_existing_session --session_name ZETX_FPS' -f $ProcessName, $csv, $Seconds),
        ('--process_name "{0}" --output_file "{1}" --timed {2} --terminate_after_timed' -f $ProcessName, $csv, $Seconds),
        ('-process_name "{0}" -output_file "{1}" -timed {2} -terminate_after_timed' -f $ProcessName, $csv, $Seconds)
    )
    foreach ($a in $sets) {
        if (Test-Path $csv) { Remove-Item $csv -Force -ErrorAction SilentlyContinue }
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $Global:ZPresentMon; $psi.Arguments = $a; $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
        $proc = $null; try { $proc = [Diagnostics.Process]::Start($psi) } catch { Write-ZLog ('PresentMon başlatılamadı: ' + $_.Exception.Message) 'ERR'; return $null }
        $t0 = Get-Date
        while (-not $proc.HasExited) {
            $el = ((Get-Date) - $t0).TotalSeconds
            if (($Global:Sync -and $Global:Sync.Cancel) -or $el -gt ($Seconds + 40)) { try { $proc.Kill() } catch {}; break }
            Set-ZProgress ([int][math]::Min(99, $el / [math]::Max(1, $Seconds) * 100)) ('FPS ölçülüyor: ' + $ProcessName)
            Start-Sleep -Milliseconds 500
        }
        if ((Test-Path $csv) -and (Get-Item $csv).Length -gt 200) { break }
    }
    if (-not (Test-Path $csv)) { Write-ZLog 'Ölçüm verisi alınamadı. Oyunun açık ve ekranda olduğundan emin olun.' 'ERR'; return $null }
    $rows = @(Import-Csv $csv)
    Remove-Item $csv -Force -ErrorAction SilentlyContinue
    if ($rows.Count -eq 0) { Write-ZLog 'Hiç kare yakalanmadı.' 'ERR'; return $null }
    $col = $null
    foreach ($c in 'MsBetweenPresents', 'FrameTime', 'msBetweenPresents', 'MsBetweenAppStart', 'MsBetweenDisplayChange') { if ($rows[0].PSObject.Properties.Name -contains $c) { $col = $c; break } }
    if (-not $col) { Write-ZLog 'PresentMon çıktısı tanınmadı.' 'ERR'; return $null }
    $ft = New-Object System.Collections.Generic.List[double]
    foreach ($r in $rows) { $v = 0.0; if ([double]::TryParse("$($r.$col)", [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$v) -and $v -gt 0.05 -and $v -lt 1000) { $ft.Add($v) } }
    if ($ft.Count -lt 30) { Write-ZLog 'Yeterli kare yakalanmadı (oyun simge durumunda olabilir).' 'ERR'; return $null }
    $arr = $ft.ToArray(); [Array]::Sort($arr)
    $avgMs = ($arr | Measure-Object -Average).Average
    $p99 = $arr[[int][math]::Min($arr.Length - 1, [math]::Floor($arr.Length * 0.99))]
    $p999 = $arr[[int][math]::Min($arr.Length - 1, [math]::Floor($arr.Length * 0.999))]
    $r = [pscustomobject][ordered]@{
        Tarih = (Get-Date).ToString('yyyy-MM-dd HH:mm'); Oyun = $ProcessName; Etiket = $Label; Sure = $Seconds; Kare = $arr.Length
        OrtFps = [math]::Round(1000 / $avgMs, 1); Low1 = [math]::Round(1000 / $p99, 1); Low01 = [math]::Round(1000 / $p999, 1); OrtMs = [math]::Round($avgMs, 2)
    }
    try { Add-Content -Path $Global:ZFpsLog -Value ($r | ConvertTo-Json -Compress) -Encoding UTF8 } catch {}
    Write-ZLog ("SONUÇ ({0}): Ortalama {1} FPS • %1 Low {2} • %0.1 Low {3} • {4} ms" -f $Label, $r.OrtFps, $r.Low1, $r.Low01, $r.OrtMs) 'OK'
    $r
}

function Get-ZFpsHistory {
    if (-not (Test-Path $Global:ZFpsLog)) { return @() }
    @(Get-Content $Global:ZFpsLog -Encoding UTF8 | Where-Object { $_.Trim() } | ForEach-Object { try { $_ | ConvertFrom-Json } catch {} })
}

function Compare-ZFps { param([string]$Game)
    $h = @(Get-ZFpsHistory | Where-Object { $_.Oyun -eq $Game })
    $b = @($h | Where-Object { $_.Etiket -eq 'ÖNCE' }) | Select-Object -Last 1
    $a = @($h | Where-Object { $_.Etiket -eq 'SONRA' }) | Select-Object -Last 1
    if (-not $b -or -not $a) { return $null }
    $d = [math]::Round(($a.OrtFps - $b.OrtFps) / [math]::Max(0.1, $b.OrtFps) * 100, 1)
    $d1 = [math]::Round(($a.Low1 - $b.Low1) / [math]::Max(0.1, $b.Low1) * 100, 1)
    [pscustomobject]@{ Before = $b; After = $a; DeltaAvg = $d; DeltaLow = $d1 }
}
