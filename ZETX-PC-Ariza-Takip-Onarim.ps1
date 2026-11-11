<#
    ZETX PC ARIZA TAKİP ONARIM
    Donanım arızaları, sistem arızaları, dosya bozuklukları, kayıt defteri,
    darboğaz analizi, sistem puanlama, ağ, temizlik, öneri ve otomatik onarım.

    Geliştirici : Volkan Sezer — ZETX / ZETXTV
    E-posta     : volkan.sezer@outlook.com.tr
    Discord     : https://discord.gg/nvqc84AHZf
    © Tüm hakları saklıdır. Ücretsiz yazılımdır.
#>
param([switch]$ArkaPlanTarama)

$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ---- Yönetici olarak yeniden başlat ----
$__id = [Security.Principal.WindowsIdentity]::GetCurrent()
$__isAdmin = (New-Object Security.Principal.WindowsPrincipal($__id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $__isAdmin) {
    $self = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    $extra = ''; if ($ArkaPlanTarama) { $extra = '-ArkaPlanTarama' }
    try {
        if ($self -match '\\(powershell|pwsh)(_ise)?\.exe$') {
            Start-Process -FilePath $self -Verb RunAs -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" {1}' -f $PSCommandPath, $extra)
        } else {
            Start-Process -FilePath $self -Verb RunAs -ArgumentList $extra
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show('ZETX PC ARIZA TAKİP ONARIM yönetici izni olmadan çalışamaz. Lütfen "Evet" seçeneğini onaylayın.', 'ZETX', 'OK', 'Warning') | Out-Null
    }
    exit
}

# ---- Tek kopya: görünmez kalmış eski kopyaları kapat, görünür olanı öne getir ----
if (-not $ArkaPlanTarama) {
    try {
        Add-Type -Namespace ZETXNative -Name Win -MemberDefinition @"
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
[DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
"@ -ErrorAction Stop
        $__others = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='pwsh.exe'" -ErrorAction Stop | Where-Object {
                $_.ProcessId -ne $PID -and "$($_.CommandLine)" -like '*ZETX-PC-Ariza-Takip-Onarim.ps1*' -and "$($_.CommandLine)" -notlike '*ArkaPlanTarama*' })
        foreach ($__o in $__others) {
            $__p = Get-Process -Id $__o.ProcessId -ErrorAction SilentlyContinue
            if (-not $__p) { continue }
            if ($__p.MainWindowHandle -ne [IntPtr]::Zero) {
                if ([ZETXNative.Win]::IsIconic($__p.MainWindowHandle)) { [void][ZETXNative.Win]::ShowWindow($__p.MainWindowHandle, 9) }
                [void][ZETXNative.Win]::SetForegroundWindow($__p.MainWindowHandle)
                exit
            }
            Stop-Process -Id $__o.ProcessId -Force -ErrorAction SilentlyContinue
        }
    } catch {}
}

# ---- Yüksek DPI desteği ----
try {
    Add-Type -Namespace ZETXNative -Name Dpi -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();' -ErrorAction Stop
    [void][ZETXNative.Dpi]::SetProcessDPIAware()
} catch {}
try {
    Add-Type -ReferencedAssemblies System.Windows.Forms, System.Drawing -ErrorAction Stop -TypeDefinition @"
using System; using System.Drawing; using System.Windows.Forms;
namespace ZETXUI {
    public class ZButton : Control, IButtonControl {
        public ZButton() {
            SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.SupportsTransparentBackColor, true);
            SetStyle(ControlStyles.StandardDoubleClick | ControlStyles.Selectable, false);
            BackColor = Color.Transparent; Cursor = Cursors.Hand;
        }
        private DialogResult _dr = DialogResult.None;
        public DialogResult DialogResult { get { return _dr; } set { _dr = value; } }
        public void NotifyDefault(bool value) { }
        public void PerformClick() { if (Enabled && Visible) { OnClick(EventArgs.Empty); } }
        protected override void OnEnabledChanged(EventArgs e) { base.OnEnabledChanged(e); Invalidate(); }
    }
}
"@
} catch {}
[System.Windows.Forms.Application]::EnableVisualStyles()
try { [System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false) } catch {}


$Script:LogoB64 = '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'
$Script:CoreCode = @'
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

'@

# =====================================================================
#  ÇEKİRDEĞİ YÜKLE
# =====================================================================
. ([scriptblock]::Create($Script:CoreCode))
$Global:Sync = [hashtable]::Synchronized(@{
        Log = New-Object 'System.Collections.Concurrent.ConcurrentQueue[string]'
        Samples = New-Object 'System.Collections.Concurrent.ConcurrentQueue[object]'
        Progress = 0; Status = ''; Cancel = $false
    })

function Write-ZErrorLog { param($Err, [string]$Where = '')
    try {
        $msg = '[{0}] {1} :: {2} :: {3}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Where, $Err.Exception.Message, ($Err.InvocationInfo.PositionMessage -replace '\s+', ' ')
        Add-Content -Path (Join-Path $Global:ZLogDir 'hata-kaydi.log') -Value $msg -Encoding UTF8
    } catch {}
}

# =====================================================================
#  ARKA PLAN (ZAMANLANMIŞ) TARAMA MODU
# =====================================================================
if ($ArkaPlanTarama) {
    $scan = Invoke-ZFullScan
    $cmp = Compare-ZHistory
    $ni = New-Object System.Windows.Forms.NotifyIcon
    $ni.Icon = [System.Drawing.SystemIcons]::Information; $ni.Visible = $true
    $ni.BalloonTipTitle = 'ZETX PC ARIZA TAKİP — Haftalık Tarama'
    $msg = 'ZETX Puanı: {0} ({1}) — Kritik: {2}, Uyarı: {3}' -f $scan.Scores.Overall, $scan.Scores.Grade, $scan.Scores.Critical, $scan.Scores.Warning
    if ($cmp -and $cmp.New.Count -gt 0) { $msg += "`nYeni sorun: " + (($cmp.New | Select-Object -First 2) -join ', ') }
    $ni.BalloonTipText = $msg
    if ($scan.Scores.Critical -gt 0) { $ni.BalloonTipIcon = 'Warning'; $ni.Icon = [System.Drawing.SystemIcons]::Warning } else { $ni.BalloonTipIcon = 'Info' }
    $ni.ShowBalloonTip(15000)
    $t0 = Get-Date
    while (((Get-Date) - $t0).TotalSeconds -lt 16) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 200 }
    $ni.Dispose()
    exit
}

# Yakalanmayan arayüz hatalarını kayda yaz, kullanıcıya hata penceresi açma
try {
    [System.Windows.Forms.Application]::SetUnhandledExceptionMode([System.Windows.Forms.UnhandledExceptionMode]::CatchException)
    [System.Windows.Forms.Application]::add_ThreadException({ param($s, $e) try { Add-Content -Path (Join-Path $Global:ZLogDir 'hata-kaydi.log') -Value ('[{0}] UI :: {1}' -f (Get-Date), $e.Exception.ToString()) -Encoding UTF8 } catch {} })
} catch {}

# =====================================================================
#  TEMA
# =====================================================================
function RGB([int]$r, [int]$g, [int]$b) { [System.Drawing.Color]::FromArgb($r, $g, $b) }
function ARGB([int]$a, $c) { [System.Drawing.Color]::FromArgb($a, $c.R, $c.G, $c.B) }
$ZC = @{
    Bg = (RGB 13 17 23); Side = (RGB 9 12 16); Surf = (RGB 19 25 33); Surf2 = (RGB 26 33 43); Border = (RGB 37 45 57); Hover = (RGB 30 39 51)
    Accent = (RGB 47 129 247); AccentHi = (RGB 88 157 255); AccentDim = (RGB 24 44 74); Cyan = (RGB 34 211 238)
    Text = (RGB 230 237 243); Text2 = (RGB 168 180 194); Muted = (RGB 110 124 140)
    Red = (RGB 248 81 73); Orange = (RGB 240 160 48); Green = (RGB 63 185 80); Blue = (RGB 88 166 255); Purple = (RGB 163 113 247)
    Console = (RGB 10 13 18); White = [System.Drawing.Color]::White
}
$Script:IconFont = 'Segoe MDL2 Assets'
try {
    $ifc = New-Object System.Drawing.Text.InstalledFontCollection
    if ($ifc.Families | Where-Object { $_.Name -eq 'Segoe Fluent Icons' }) { $Script:IconFont = 'Segoe Fluent Icons' }
} catch {}
$ZF = @{
    Logo = New-Object System.Drawing.Font('Bahnschrift', 20, [System.Drawing.FontStyle]::Bold)
    LogoSub = New-Object System.Drawing.Font('Segoe UI', 8.25)
    H1 = New-Object System.Drawing.Font('Segoe UI Semibold', 15)
    Sub = New-Object System.Drawing.Font('Segoe UI', 9.25)
    H3 = New-Object System.Drawing.Font('Segoe UI Semibold', 10)
    Body = New-Object System.Drawing.Font('Segoe UI', 9.25)
    Bold = New-Object System.Drawing.Font('Segoe UI Semibold', 9.25)
    Small = New-Object System.Drawing.Font('Segoe UI', 8.5)
    Tiny = New-Object System.Drawing.Font('Segoe UI Semibold', 7.75)
    Btn = New-Object System.Drawing.Font('Segoe UI Semibold', 9)
    Nav = New-Object System.Drawing.Font('Segoe UI', 9.5)
    NavB = New-Object System.Drawing.Font('Segoe UI Semibold', 9.5)
    Mono = New-Object System.Drawing.Font('Consolas', 9)
    Kpi = New-Object System.Drawing.Font('Bahnschrift', 22, [System.Drawing.FontStyle]::Bold)
    KpiS = New-Object System.Drawing.Font('Bahnschrift', 16, [System.Drawing.FontStyle]::Bold)
    Ring = New-Object System.Drawing.Font('Bahnschrift', 32, [System.Drawing.FontStyle]::Bold)
    Icon = New-Object System.Drawing.Font($Script:IconFont, 10.5)
    IconM = New-Object System.Drawing.Font($Script:IconFont, 12)
    IconL = New-Object System.Drawing.Font($Script:IconFont, 16)
}
function Ic([int]$code) { [string][char]$code }
$ZI = @{
    Home = Ic 0xE80F; Scan = Ic 0xE721; Repair = Ic 0xE90F; Warn = Ic 0xE7BA; Hw = Ic 0xE772; Reg = Ic 0xE8F1; Game = Ic 0xE7FC
    Star = Ic 0xE734; Net = Ic 0xE701; Clean = Ic 0xE74D; Hist = Ic 0xE81C; Key = Ic 0xE8D7; Bolt = Ic 0xE945; Driver = Ic 0xE950
    Play = Ic 0xE768; Stop = Ic 0xE71A; Refresh = Ic 0xE72C; Copy = Ic 0xE8C8; Mail = Ic 0xE715; Chat = Ic 0xE8BD; Doc = Ic 0xE8A5
    Folder = Ic 0xE8B7; Save = Ic 0xE74E; Shield = Ic 0xEA18; Check = Ic 0xE73E; Down = Ic 0xE896; Info = Ic 0xE946; Clock = Ic 0xE823
    Chart = Ic 0xE9D2; Diag = Ic 0xE9D9; Gauge = Ic 0xEC4A; Restore = Ic 0xE777; List = Ic 0xEA37; Settings = Ic 0xE713; Globe = Ic 0xE774
}
$UI = @{ Pages = @{}; Nav = @{}; NavMeta = @{} }
$Script:Jobs = New-Object System.Collections.ArrayList
$Script:LastScan = $null; $Script:AllFindings = @(); $Script:Filter = 'Tümü'
$Script:License = $null

# =====================================================================
#  TEMEL BİLEŞENLER
# =====================================================================
function Set-ZDB($ctl) { try { $ctl.GetType().GetProperty('DoubleBuffered', [Reflection.BindingFlags]'NonPublic,Instance').SetValue($ctl, $true, $null) } catch {} }

function Add-ZDock { param($Parent, [object[]]$Controls)
    for ($i = $Controls.Count - 1; $i -ge 0; $i--) { if ($Controls[$i]) { $Parent.Controls.Add($Controls[$i]) } }
    foreach ($c in @($Controls)) { if ($c -and "$($c.Dock)" -eq 'Fill') { $Parent.Controls.SetChildIndex($c, 0) } }
}

function New-ZPanel { param([string]$Dock = 'Top', [int]$Height = 0, $Back = $null, [int]$Pad = 0)
    $p = New-Object System.Windows.Forms.Panel; $p.Dock = $Dock
    if ($Height) { $p.Height = $Height }
    if ($Back) { $p.BackColor = $Back } else { $p.BackColor = $ZC.Bg }
    $p.Padding = New-Object System.Windows.Forms.Padding($Pad); $p
}
function New-ZSpacer { param([int]$H = 12, $Back = $null) New-ZPanel 'Top' $H $Back }

function New-ZLabel { param([string]$Text, $Font = $null, $Color = $null, [string]$Dock = 'Top', [int]$Height = 0, [string]$Align = 'MiddleLeft')
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $Text; if ($Font) { $l.Font = $Font } else { $l.Font = $ZF.Body }
    if ($Color) { $l.ForeColor = $Color } else { $l.ForeColor = $ZC.Text }
    $l.BackColor = [System.Drawing.Color]::Transparent; $l.Dock = $Dock; $l.TextAlign = $Align; $l.UseMnemonic = $false
    if ($Height) { $l.Height = $Height } elseif ($Dock -eq 'None') { $l.AutoSize = $true }
    $l
}

function Get-ZRoundPath { param([float]$X, [float]$Y, [float]$W, [float]$H, [float]$R)
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    if ($R -le 0 -or $W -le ($R * 2) -or $H -le ($R * 2)) { $p.AddRectangle((New-Object System.Drawing.RectangleF($X, $Y, [math]::Max(1, $W), [math]::Max(1, $H)))); return , $p }
    $d = $R * 2
    $p.AddArc($X, $Y, $d, $d, 180, 90); $p.AddArc($X + $W - $d, $Y, $d, $d, 270, 90)
    $p.AddArc($X + $W - $d, $Y + $H - $d, $d, $d, 0, 90); $p.AddArc($X, $Y + $H - $d, $d, $d, 90, 90)
    $p.CloseFigure(); , $p
}

$Script:HasZButton = $false
try { $Script:HasZButton = [bool]('ZETXUI.ZButton' -as [type]) } catch {}

function New-ZBtn {
    param([string]$Text, [string]$Icon = '', [string]$Style = 'secondary', [int]$Width = 0, [int]$Height = 34)
    if ($Script:HasZButton) { $b = New-Object ZETXUI.ZButton }
    else {
        $b = New-Object System.Windows.Forms.Button
        $b.FlatStyle = 'Flat'; $b.FlatAppearance.BorderSize = 0
        $b.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::Transparent; $b.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::Transparent
        $b.UseVisualStyleBackColor = $false
    }
    $b.BackColor = [System.Drawing.Color]::Transparent; $b.Text = ''; $b.TabStop = $false
    $b.Cursor = [System.Windows.Forms.Cursors]::Hand; $b.Height = $Height
    $b.Margin = New-Object System.Windows.Forms.Padding(0, 0, 8, 8)
    $b.Tag = @{ Text = $Text; Icon = $Icon; Style = $Style; Hover = $false; Down = $false; Active = $false }
    if (-not $Width) { $Width = [System.Windows.Forms.TextRenderer]::MeasureText($Text, $ZF.Btn).Width + 30; if ($Icon) { $Width += 22 } }
    $b.Width = $Width
    $b.Add_MouseEnter({ $this.Tag.Hover = $true; $this.Invalidate() })
    $b.Add_MouseLeave({ $this.Tag.Hover = $false; $this.Tag.Down = $false; $this.Invalidate() })
    $b.Add_MouseDown({ $this.Tag.Down = $true; $this.Invalidate() })
    $b.Add_MouseUp({ $this.Tag.Down = $false; $this.Invalidate() })
    $b.Add_EnabledChanged({ $this.Invalidate() })
    $b.Add_Paint({
            param($s, $e) try {
            $t = $s.Tag; $g = $e.Graphics; $g.SmoothingMode = 'AntiAlias'
            $bg = $ZC.Surf2; $fg = $ZC.Text; $bd = $ZC.Border
            switch ($t.Style) {
                'primary' { $bg = $ZC.Accent; $fg = $ZC.White; $bd = $null; if ($t.Hover) { $bg = $ZC.AccentHi } }
                'danger' { $bg = (RGB 196 52 48); $fg = $ZC.White; $bd = $null; if ($t.Hover) { $bg = (RGB 218 64 58) } }
                'success' { $bg = (RGB 35 134 54); $fg = $ZC.White; $bd = $null; if ($t.Hover) { $bg = (RGB 46 160 67) } }
                'purple' { $bg = (RGB 110 64 201); $fg = $ZC.White; $bd = $null; if ($t.Hover) { $bg = (RGB 131 84 224) } }
                'ghost' { $bg = $null; $fg = $ZC.Text2; $bd = $null; if ($t.Hover) { $bg = $ZC.Surf2; $fg = $ZC.Text } }
                'chip' { $bg = $ZC.Surf; $fg = $ZC.Text2; if ($t.Active) { $bg = $ZC.AccentDim; $fg = $ZC.White; $bd = $ZC.Accent } elseif ($t.Hover) { $bg = $ZC.Hover } }
                default { if ($t.Hover) { $bg = $ZC.Hover; $bd = (RGB 55 66 82) } }
            }
            if ($t.Down -and $bg) { $bg = [System.Windows.Forms.ControlPaint]::Dark($bg, 0.05) }
            if (-not $s.Enabled) { $fg = $ZC.Muted; if ($bg) { $bg = $ZC.Surf } }
            $path = Get-ZRoundPath 0.5 0.5 ($s.Width - 1.5) ($s.Height - 1.5) 6
            if ($bg) { $br = New-Object System.Drawing.SolidBrush($bg); $g.FillPath($br, $path); $br.Dispose() }
            if ($bd) { $pn = New-Object System.Drawing.Pen($bd, 1); $g.DrawPath($pn, $path); $pn.Dispose() }
            $path.Dispose()
            $tw = [System.Windows.Forms.TextRenderer]::MeasureText($t.Text, $ZF.Btn).Width
            $iw = 0; if ($t.Icon) { $iw = 22 }
            $x0 = [int](($s.Width - $tw - $iw) / 2)
            $flags = [System.Windows.Forms.TextFormatFlags]'VerticalCenter, Left, SingleLine, NoPadding'
            if ($t.Icon) { [System.Windows.Forms.TextRenderer]::DrawText($g, $t.Icon, $ZF.Icon, (New-Object System.Drawing.Rectangle($x0, 0, 20, $s.Height)), $fg, $flags) }
            [System.Windows.Forms.TextRenderer]::DrawText($g, $t.Text, $ZF.Btn, (New-Object System.Drawing.Rectangle(($x0 + $iw), 0, ($tw + 4), $s.Height)), $fg, $flags)
         } catch { } })
    $b
}
function Set-ZBtnText { param($B, [string]$Text) $B.Tag.Text = $Text; $B.Invalidate() }

function New-ZBar { param([object[]]$Items, $Back = $null)
    $fl = New-Object System.Windows.Forms.FlowLayoutPanel
    $fl.Dock = 'Top'; $fl.AutoSize = $true; $fl.WrapContents = $true
    if ($Back) { $fl.BackColor = $Back } else { $fl.BackColor = $ZC.Bg }
    $fl.Padding = New-Object System.Windows.Forms.Padding(0, 0, 0, 4)
    foreach ($i in $Items) { if ($i) { $fl.Controls.Add($i) } }
    $fl
}

function New-ZCombo { param([string[]]$Items, [int]$Index = 0, [int]$Width = 130)
    $c = New-Object System.Windows.Forms.ComboBox
    $c.DropDownStyle = 'DropDownList'; $c.FlatStyle = 'Flat'; $c.BackColor = $ZC.Surf2; $c.ForeColor = $ZC.Text; $c.Font = $ZF.Bold
    $c.Width = $Width; $c.Margin = New-Object System.Windows.Forms.Padding(0, 5, 8, 8)
    foreach ($i in $Items) { [void]$c.Items.Add($i) }
    if ($c.Items.Count -gt $Index) { $c.SelectedIndex = $Index }
    $c
}

function New-ZCheck { param([string]$Text, [bool]$Checked = $true)
    $k = New-Object System.Windows.Forms.CheckBox; $k.Text = $Text; $k.Checked = $Checked; $k.ForeColor = $ZC.Text2; $k.Font = $ZF.Small
    $k.AutoSize = $true; $k.Margin = New-Object System.Windows.Forms.Padding(4, 9, 8, 0); $k.FlatStyle = 'Flat'; $k
}

function New-ZCard {
    param([string]$Title = '', [string]$Icon = '', [string]$Dock = 'Top', [int]$Height = 0, [int]$Pad = 14)
    $p = New-Object System.Windows.Forms.Panel
    $p.BackColor = $ZC.Surf; $p.Dock = $Dock; if ($Height) { $p.Height = $Height }
    $top = $Pad; if ($Title) { $top = 48 }
    $p.Padding = New-Object System.Windows.Forms.Padding($Pad, $top, $Pad, $Pad)
    $p.Tag = @{ Title = $Title; Icon = $Icon; Right = ''; RightColor = $ZC.Muted }
    Set-ZDB $p
    $p.Add_Paint({
            param($s, $e) try {
            $g = $e.Graphics; $t = $s.Tag
            $pn = New-Object System.Drawing.Pen($ZC.Border, 1); $g.DrawRectangle($pn, 0, 0, $s.Width - 1, $s.Height - 1); $pn.Dispose()
            if ($t.Title) {
                $flags = [System.Windows.Forms.TextFormatFlags]'VerticalCenter, Left, SingleLine, NoPadding, EndEllipsis'
                $x = 16
                if ($t.Icon) { [System.Windows.Forms.TextRenderer]::DrawText($g, $t.Icon, $ZF.Icon, (New-Object System.Drawing.Rectangle(16, 10, 22, 24)), $ZC.Accent, $flags); $x = 42 }
                [System.Windows.Forms.TextRenderer]::DrawText($g, $t.Title, $ZF.H3, (New-Object System.Drawing.Rectangle($x, 10, [math]::Max(10, ($s.Width / 2 + 60 - $x)), 24)), $ZC.Text, $flags)
                if ($t.Right) {
                    $rf = [System.Windows.Forms.TextFormatFlags]'VerticalCenter, Right, SingleLine, NoPadding, EndEllipsis'
                    [System.Windows.Forms.TextRenderer]::DrawText($g, $t.Right, $ZF.Small, (New-Object System.Drawing.Rectangle([int]($s.Width / 2), 10, [int]($s.Width / 2 - 16), 24)), $t.RightColor, $rf)
                }
                $pl = New-Object System.Drawing.Pen($ZC.Border, 1); $g.DrawLine($pl, 1, 41, $s.Width - 2, 41); $pl.Dispose()
            }
         } catch { } })
    $p
}
function Set-ZCardRight { param($Card, [string]$Text, $Color = $null) $Card.Tag.Right = $Text; if ($Color) { $Card.Tag.RightColor = $Color }; $Card.Invalidate() }

function New-ZCols {
    # Yan yana kartlar: Widths = yüzde (ör. 60,40) veya negatif = sabit piksel
    param([object[]]$Controls, [double[]]$Widths, [string]$Dock = 'Top', [int]$Height = 0, [int]$Gap = 12)
    $t = New-Object System.Windows.Forms.TableLayoutPanel
    $t.Dock = $Dock; if ($Height) { $t.Height = $Height }; $t.BackColor = $ZC.Bg
    $t.ColumnCount = $Controls.Count; $t.RowCount = 1; $t.Margin = New-Object System.Windows.Forms.Padding(0); $t.Padding = New-Object System.Windows.Forms.Padding(0)
    for ($i = 0; $i -lt $Controls.Count; $i++) {
        $w = $Widths[$i]
        if ($w -lt 0) { [void]$t.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, [float](-$w)))) }
        else { [void]$t.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, [float]$w))) }
    }
    [void]$t.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, [float]100)))
    for ($i = 0; $i -lt $Controls.Count; $i++) {
        $c = $Controls[$i]; $c.Dock = 'Fill'
        $r = $Gap; if ($i -eq $Controls.Count - 1) { $r = 0 }
        $c.Margin = New-Object System.Windows.Forms.Padding(0, 0, $r, 0)
        $t.Controls.Add($c, $i, 0)
    }
    Set-ZDB $t
    $t
}

# ---- Göstergeler ----
function New-ZKpi { param([string]$Label, $Color, [string]$Value = '—', [string]$SubText = '')
    $p = New-Object System.Windows.Forms.Panel; $p.BackColor = $ZC.Surf
    $p.Tag = @{ Label = $Label; Value = $Value; Sub = $SubText; Color = $Color }
    Set-ZDB $p
    $p.Add_Paint({
            param($s, $e) try {
            $g = $e.Graphics; $t = $s.Tag
            $pn = New-Object System.Drawing.Pen($ZC.Border, 1); $g.DrawRectangle($pn, 0, 0, $s.Width - 1, $s.Height - 1); $pn.Dispose()
            $cb = New-Object System.Drawing.SolidBrush($t.Color); $g.FillRectangle($cb, 0, 0, 3, $s.Height); $cb.Dispose()
            $fl = [System.Windows.Forms.TextFormatFlags]'Left, SingleLine, NoPadding, EndEllipsis'
            [System.Windows.Forms.TextRenderer]::DrawText($g, $t.Label.ToUpper(), $ZF.Tiny, (New-Object System.Drawing.Rectangle(16, 12, ($s.Width - 24), 16)), $ZC.Muted, $fl)
            [System.Windows.Forms.TextRenderer]::DrawText($g, "$($t.Value)", $ZF.Kpi, (New-Object System.Drawing.Rectangle(14, 30, ($s.Width - 20), 38)), $t.Color, $fl)
            if ($t.Sub) { [System.Windows.Forms.TextRenderer]::DrawText($g, $t.Sub, $ZF.Small, (New-Object System.Drawing.Rectangle(16, ($s.Height - 26), ($s.Width - 24), 18)), $ZC.Text2, $fl) }
         } catch { } })
    $p
}
function Set-ZKpi { param($K, $Value, [string]$SubText = $null, $Color = $null)
    $K.Tag.Value = $Value; if ($null -ne $SubText) { $K.Tag.Sub = $SubText }; if ($Color) { $K.Tag.Color = $Color }; $K.Invalidate()
}

function New-ZMeter { param([string]$Title, $Color)
    $p = New-Object System.Windows.Forms.Panel; $p.BackColor = $ZC.Surf
    $p.Tag = @{ Title = $Title; Value = 0; Color = $Color; Sub = ''; Hist = New-Object System.Collections.ArrayList }
    Set-ZDB $p
    $p.Add_Paint({
            param($s, $e) try {
            $g = $e.Graphics; $t = $s.Tag; $g.SmoothingMode = 'AntiAlias'
            $w = $s.Width; $h = $s.Height
            $pn = New-Object System.Drawing.Pen($ZC.Border, 1); $g.DrawRectangle($pn, 0, 0, $w - 1, $h - 1); $pn.Dispose()
            $fl = [System.Windows.Forms.TextFormatFlags]'Left, SingleLine, NoPadding, EndEllipsis'
            $fr = [System.Windows.Forms.TextFormatFlags]'Right, SingleLine, NoPadding'
            [System.Windows.Forms.TextRenderer]::DrawText($g, $t.Title.ToUpper(), $ZF.Tiny, (New-Object System.Drawing.Rectangle(14, 12, ($w - 100), 16)), $ZC.Muted, $fl)
            [System.Windows.Forms.TextRenderer]::DrawText($g, ('%' + [int]$t.Value), $ZF.KpiS, (New-Object System.Drawing.Rectangle(($w - 100), 8, 86, 28)), $t.Color, $fr)
            if ($t.Sub) { [System.Windows.Forms.TextRenderer]::DrawText($g, $t.Sub, $ZF.Small, (New-Object System.Drawing.Rectangle(14, 30, ($w - 110), 16)), $ZC.Text2, $fl) }
            $top = 52; $bot = $h - 10; $gh = $bot - $top; $left = 12; $gw = $w - 24
            $d = @($t.Hist)
            if ($d.Count -gt 1 -and $gh -gt 6) {
                $n = 40; $start = [math]::Max(0, $d.Count - $n)
                $pts = New-Object 'System.Collections.Generic.List[System.Drawing.PointF]'
                for ($i = $start; $i -lt $d.Count; $i++) {
                    $px = $left + $gw * ($i - $start) / ($n - 1)
                    $py = $bot - $gh * [math]::Min(100, [math]::Max(0, (ConvertTo-ZNum $d[$i]))) / 100
                    $pts.Add((New-Object System.Drawing.PointF([float]$px, [float]$py)))
                }
                $fillPts = New-Object 'System.Collections.Generic.List[System.Drawing.PointF]'
                $fillPts.AddRange($pts); $fillPts.Add((New-Object System.Drawing.PointF($pts[$pts.Count - 1].X, [float]$bot))); $fillPts.Add((New-Object System.Drawing.PointF($pts[0].X, [float]$bot)))
                $fb = New-Object System.Drawing.SolidBrush((ARGB 38 $t.Color)); $g.FillPolygon($fb, $fillPts.ToArray()); $fb.Dispose()
                $lp = New-Object System.Drawing.Pen($t.Color, 1.6); $g.DrawLines($lp, $pts.ToArray()); $lp.Dispose()
            }
         } catch { } })
    $p
}
function Push-ZMeter { param($M, [double]$V, [string]$Sub = '')
    $M.Tag.Value = $V; $M.Tag.Sub = $Sub; [void]$M.Tag.Hist.Add($V); if ($M.Tag.Hist.Count -gt 60) { $M.Tag.Hist.RemoveAt(0) }; $M.Invalidate()
}

function New-ZRing {
    $p = New-Object System.Windows.Forms.Panel; $p.BackColor = $ZC.Surf
    $p.Tag = @{ Value = -1; Grade = '-'; Label = 'ZETX PUANI'; Sub = 'Henüz tarama yok' }
    Set-ZDB $p
    $p.Add_Paint({
            param($s, $e) try {
            $t = $s.Tag; $g = $e.Graphics; $g.SmoothingMode = 'AntiAlias'
            $pn0 = New-Object System.Drawing.Pen($ZC.Border, 1); $g.DrawRectangle($pn0, 0, 0, $s.Width - 1, $s.Height - 1); $pn0.Dispose()
            $sz = [math]::Min($s.Width - 40, $s.Height - 64); if ($sz -lt 40) { return }
            $x = [float](($s.Width - $sz) / 2); $y = [float]18
            $pb = New-Object System.Drawing.Pen($ZC.Surf2, 11); $g.DrawArc($pb, $x, $y, [float]$sz, [float]$sz, [float]135, [float]270); $pb.Dispose()
            $col = $ZC.Muted
            if ($t.Value -ge 0) {
                $col = $ZC.Red; if ($t.Value -ge 80) { $col = $ZC.Green } elseif ($t.Value -ge 65) { $col = $ZC.Accent } elseif ($t.Value -ge 50) { $col = $ZC.Orange }
                $pf = New-Object System.Drawing.Pen($col, 11); $pf.StartCap = 'Round'; $pf.EndCap = 'Round'
                $g.DrawArc($pf, $x, $y, [float]$sz, [float]$sz, [float]135, [float](270 * [math]::Max(1, $t.Value) / 100)); $pf.Dispose()
            }
            $txt = '--'; if ($t.Value -ge 0) { $txt = "$([int]$t.Value)" }
            $fc = [System.Windows.Forms.TextFormatFlags]'HorizontalCenter, VerticalCenter, SingleLine, NoPadding'
            $cy = [int]($y + $sz / 2)
            [System.Windows.Forms.TextRenderer]::DrawText($g, $txt, $ZF.Ring, (New-Object System.Drawing.Rectangle(0, ($cy - 30), $s.Width, 48)), $ZC.Text, $fc)
            [System.Windows.Forms.TextRenderer]::DrawText($g, $t.Label, $ZF.Tiny, (New-Object System.Drawing.Rectangle(0, ($cy + 18), $s.Width, 16)), $ZC.Muted, $fc)
            [System.Windows.Forms.TextRenderer]::DrawText($g, ('DERECE  ' + $t.Grade), $ZF.Bold, (New-Object System.Drawing.Rectangle(0, ($s.Height - 44), $s.Width, 18)), $col, $fc)
            [System.Windows.Forms.TextRenderer]::DrawText($g, $t.Sub, $ZF.Small, (New-Object System.Drawing.Rectangle(8, ($s.Height - 26), ($s.Width - 16), 16)), $ZC.Text2, $fc)
         } catch { } })
    $p
}
function Set-ZRing { param($R, $Value, [string]$Grade, [string]$Sub = $null, [string]$Label = $null)
    $R.Tag.Value = ConvertTo-ZInt $Value -1; $R.Tag.Grade = $Grade; if ($null -ne $Sub) { $R.Tag.Sub = $Sub }; if ($Label) { $R.Tag.Label = $Label }; $R.Invalidate()
}

function New-ZScoreBar { param([string]$Title, $Color, [double]$Max = 100)
    $p = New-Object System.Windows.Forms.Panel; $p.Dock = 'Top'; $p.Height = 50; $p.BackColor = $ZC.Surf
    $p.Tag = @{ Title = $Title; Value = 0; Max = $Max; Color = $Color; Text = '—' }
    Set-ZDB $p
    $p.Add_Paint({
            param($s, $e) try {
            $t = $s.Tag; $g = $e.Graphics; $g.SmoothingMode = 'AntiAlias'; $w = $s.Width
            $fl = [System.Windows.Forms.TextFormatFlags]'Left, SingleLine, NoPadding, EndEllipsis'; $fr = [System.Windows.Forms.TextFormatFlags]'Right, SingleLine, NoPadding, EndEllipsis'
            [System.Windows.Forms.TextRenderer]::DrawText($g, $t.Title, $ZF.Body, (New-Object System.Drawing.Rectangle(0, 4, [math]::Max(10, ($w / 2)), 20)), $ZC.Text2, $fl)
            [System.Windows.Forms.TextRenderer]::DrawText($g, $t.Text, $ZF.Bold, (New-Object System.Drawing.Rectangle([int]($w / 2), 4, [int]($w / 2 - 2), 20)), $ZC.Text, $fr)
            $bp = Get-ZRoundPath 0 28 ($w - 2) 8 4; $bb = New-Object System.Drawing.SolidBrush($ZC.Surf2); $g.FillPath($bb, $bp); $bb.Dispose(); $bp.Dispose()
            $fw = [float](($w - 2) * [math]::Min(1, [math]::Max(0, $t.Value / $t.Max)))
            if ($fw -gt 8) { $fp = Get-ZRoundPath 0 28 $fw 8 4; $fb = New-Object System.Drawing.SolidBrush($t.Color); $g.FillPath($fb, $fp); $fb.Dispose(); $fp.Dispose() }
         } catch { } })
    $p
}
function Set-ZScoreBar { param($B, [double]$V, [string]$Text) $B.Tag.Value = $V; $B.Tag.Text = $Text; $B.Invalidate() }

function New-ZGraph { param([int]$Height = 200, [string]$Dock = 'Top')
    $p = New-Object System.Windows.Forms.Panel; $p.Dock = $Dock; $p.Height = $Height; $p.BackColor = $ZC.Surf
    $p.Tag = @{ Series = @(); Points = 60 }
    Set-ZDB $p
    $p.Add_Paint({
            param($s, $e) try {
            $t = $s.Tag; $g = $e.Graphics; $g.SmoothingMode = 'AntiAlias'
            $w = $s.ClientSize.Width; $h = $s.ClientSize.Height
            $left = 34; $top = 30; $bot = 20; $right = 6; $gw = $w - $left - $right; $gh = $h - $top - $bot
            if ($gw -lt 20 -or $gh -lt 20) { return }
            $grid = New-Object System.Drawing.Pen($ZC.Surf2, 1)
            $fl = [System.Windows.Forms.TextFormatFlags]'Left, SingleLine, NoPadding'
            foreach ($v in 0, 25, 50, 75, 100) {
                $yy = [int]($top + $gh - ($gh * $v / 100)); $g.DrawLine($grid, $left, $yy, $left + $gw, $yy)
                [System.Windows.Forms.TextRenderer]::DrawText($g, "$v", $ZF.Small, (New-Object System.Drawing.Rectangle(2, ($yy - 8), 30, 16)), $ZC.Muted, $fl)
            }
            $lx = $left
            foreach ($sr in $t.Series) {
                $d = @($sr.Data)
                if ($d.Count -gt 1) {
                    $pts = New-Object 'System.Collections.Generic.List[System.Drawing.PointF]'
                    $n = [math]::Max(2, $t.Points); $start = [math]::Max(0, $d.Count - $n)
                    for ($i = $start; $i -lt $d.Count; $i++) {
                        $px = $left + $gw * ($i - $start) / ($n - 1)
                        $py = $top + $gh - ($gh * [math]::Min(100, [math]::Max(0, (ConvertTo-ZNum $d[$i]))) / 100)
                        $pts.Add((New-Object System.Drawing.PointF([float]$px, [float]$py)))
                    }
                    $pen = New-Object System.Drawing.Pen($sr.Color, 2); $g.DrawLines($pen, $pts.ToArray()); $pen.Dispose()
                }
                $last = ''; if ($d.Count) { $last = '  %' + (ConvertTo-ZInt $d[$d.Count - 1]) }
                $label = $sr.Name + $last
                $cb = New-Object System.Drawing.SolidBrush($sr.Color); $g.FillEllipse($cb, $lx, 9, 9, 9); $cb.Dispose()
                [System.Windows.Forms.TextRenderer]::DrawText($g, $label, $ZF.Small, (New-Object System.Drawing.Point(($lx + 13), 6)), $ZC.Text2)
                $lx += [System.Windows.Forms.TextRenderer]::MeasureText($label, $ZF.Small).Width + 28
            }
            $grid.Dispose()
         } catch { } })
    $p
}

# ---- Tablo ----
function Get-ZSevColor { param([string]$S)
    switch -Regex ($S) {
        '^KRİTİK|^Çok eski|^Zayıf|^MAVİ|^Sürücü yok' { return $ZC.Red }
        '^UYARI|^Eski|^Oynanabilir|^Windows genel|^ANİ|^ÖNCE|^Güncelleme var|^Yeni sürüm' { return $ZC.Orange }
        '^BİLGİ|^Akıcı|^ÖLÇÜM' { return $ZC.Blue }
        '^İYİ|^Güncel|^Mükemmel|^Çok iyi|^TEMİZ|^Etkin|^SONRA' { return $ZC.Green }
        default { return $ZC.Muted }
    }
}

function New-ZGrid {
    # Sütun: 'Ad:ağırlık' | '@SEV:Ad:ağırlık' rozet | '@ACT:ağırlık' işlem düğmesi
    param([string[]]$Columns, [switch]$CheckBox, [switch]$Wrap, [switch]$NoHeader)
    $g = New-Object System.Windows.Forms.DataGridView
    $g.BackgroundColor = $ZC.Surf; $g.BorderStyle = 'None'; $g.GridColor = $ZC.Border
    $g.EnableHeadersVisualStyles = $false
    $hs = $g.ColumnHeadersDefaultCellStyle
    $hs.BackColor = $ZC.Surf; $hs.ForeColor = $ZC.Muted; $hs.SelectionBackColor = $ZC.Surf; $hs.SelectionForeColor = $ZC.Muted; $hs.Font = $ZF.Tiny
    $hs.Padding = New-Object System.Windows.Forms.Padding(6, 0, 6, 0)
    $g.ColumnHeadersBorderStyle = 'Single'; $g.ColumnHeadersHeightSizeMode = 'DisableResizing'; $g.ColumnHeadersHeight = 34
    $g.ColumnHeadersVisible = (-not $NoHeader)
    $ds = $g.DefaultCellStyle
    $ds.BackColor = $ZC.Surf; $ds.ForeColor = $ZC.Text; $ds.SelectionBackColor = $ZC.AccentDim; $ds.SelectionForeColor = $ZC.White; $ds.Font = $ZF.Body
    $ds.Padding = New-Object System.Windows.Forms.Padding(6, 4, 6, 4)
    if ($Wrap) { $ds.WrapMode = [System.Windows.Forms.DataGridViewTriState]::True; $g.AutoSizeRowsMode = 'AllCells' }
    else { $ds.WrapMode = [System.Windows.Forms.DataGridViewTriState]::False; $g.AutoSizeRowsMode = 'None' }
    $g.RowTemplate.Height = 36
    $g.RowHeadersVisible = $false; $g.AllowUserToAddRows = $false; $g.AllowUserToDeleteRows = $false; $g.AllowUserToResizeRows = $false; $g.AllowUserToResizeColumns = $true
    $g.SelectionMode = 'FullRowSelect'; $g.MultiSelect = $false; $g.AutoSizeColumnsMode = 'Fill'
    $g.CellBorderStyle = 'SingleHorizontal'; $g.Dock = 'Fill'; $g.ReadOnly = (-not $CheckBox); $g.StandardTab = $true
    if ($CheckBox) {
        $cb = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
        $cb.Name = 'Sec'; $cb.HeaderText = ''; $cb.FillWeight = 4; $cb.MinimumWidth = 34; $cb.FlatStyle = 'Flat'
        [void]$g.Columns.Add($cb)
        $g.Add_CurrentCellDirtyStateChanged({ param($s, $e) if ($s.IsCurrentCellDirty) { [void]$s.CommitEdit('CurrentCellChange') } })
    }
    foreach ($spec in $Columns) {
        $parts = @($spec.Split(':')); $kind = ''
        if ($parts[0] -eq '@SEV') { $kind = 'SEV'; $parts = @($parts[1..($parts.Count - 1)]) }
        elseif ($parts[0] -eq '@ACT') { $kind = 'ACT'; $parts = @('İşlem') + @($parts[1..($parts.Count - 1)]) }
        $name = $parts[0]; $w = 100; if ($parts.Count -gt 1) { $w = ConvertTo-ZInt $parts[1] 100 }
        $tc = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
        $tc.Name = $name; $tc.HeaderText = $name.ToUpper(); $tc.FillWeight = [math]::Max(1, $w); $tc.ReadOnly = $true; $tc.SortMode = 'NotSortable'
        $tc.ValueType = [string]; $tc.Tag = $kind
        if ($kind -eq 'ACT') { $tc.HeaderText = ''; $tc.MinimumWidth = 96 }
        if ($kind -eq 'SEV') { $tc.MinimumWidth = 92 }
        [void]$g.Columns.Add($tc)
    }
    $g.Add_DataError({ param($s, $e) $e.ThrowException = $false; $e.Cancel = $true })
    $g.Add_CellPainting({
            param($s, $e) try {
            if ($e.RowIndex -lt 0 -or $e.ColumnIndex -lt 0) { return }
            $kind = $s.Columns[$e.ColumnIndex].Tag
            if ($kind -ne 'SEV' -and $kind -ne 'ACT') { return }
            $e.PaintBackground($e.CellBounds, $true)
            $txt = "$($e.Value)"
            if ($txt) {
                $gr = $e.Graphics; $gr.SmoothingMode = 'AntiAlias'
                $tw = [System.Windows.Forms.TextRenderer]::MeasureText($txt, $ZF.Tiny).Width
                $bh = 22; $bw = $tw + 18
                $bx = $e.CellBounds.X + 8; $by = $e.CellBounds.Y + [int](($e.CellBounds.Height - $bh) / 2)
                if ($kind -eq 'ACT') { $bw = [math]::Max($bw, 70); $bx = $e.CellBounds.X + [int](($e.CellBounds.Width - $bw) / 2) }
                $col = $ZC.Accent; if ($kind -eq 'SEV') { $col = Get-ZSevColor $txt }
                $path = Get-ZRoundPath $bx $by $bw $bh 11
                $fb = New-Object System.Drawing.SolidBrush((ARGB 40 $col)); $gr.FillPath($fb, $path); $fb.Dispose()
                if ($kind -eq 'ACT') { $pn = New-Object System.Drawing.Pen((ARGB 160 $col), 1); $gr.DrawPath($pn, $path); $pn.Dispose() }
                $path.Dispose()
                $tcol = $col; if ($kind -eq 'ACT') { $tcol = $ZC.AccentHi }
                [System.Windows.Forms.TextRenderer]::DrawText($gr, $txt, $ZF.Tiny, (New-Object System.Drawing.Rectangle($bx, $by, $bw, $bh)), $tcol, [System.Windows.Forms.TextFormatFlags]'HorizontalCenter, VerticalCenter, SingleLine, NoPadding')
            }
            $e.Handled = $true
         } catch { } })
    $g.Add_CellMouseEnter({ param($s, $e) if ($e.RowIndex -ge 0 -and $e.ColumnIndex -ge 0 -and $s.Columns[$e.ColumnIndex].Tag -eq 'ACT' -and "$($s.Rows[$e.RowIndex].Cells[$e.ColumnIndex].Value)") { $s.Cursor = [System.Windows.Forms.Cursors]::Hand } })
    $g.Add_CellMouseLeave({ param($s, $e) $s.Cursor = [System.Windows.Forms.Cursors]::Default })
    Set-ZDB $g
    $g
}

function Add-ZRow { param($Grid, [object[]]$Values, $Tag = $null)
    $vals = New-Object 'System.Collections.Generic.List[object]'
    foreach ($v in $Values) { if ($null -eq $v) { $vals.Add('') } elseif ($v -is [bool]) { $vals.Add($v) } else { $vals.Add([string]$v) } }
    $i = $Grid.Rows.Add($vals.ToArray())
    if ($null -ne $Tag) { $Grid.Rows[$i].Tag = $Tag }
    $i
}

function New-ZFindingsGrid {
    $g = New-ZGrid @('@SEV:Önem:10', 'Kategori:10', 'Sorun:24', 'Ayrıntı:25', 'Öneri:27', '@ACT:11') -Wrap
    $g.Add_CellClick({
            param($s, $e)
            if ($e.RowIndex -lt 0 -or $e.ColumnIndex -lt 0) { return }
            if ($s.Columns[$e.ColumnIndex].Tag -ne 'ACT') { return }
            $fnd = $s.Rows[$e.RowIndex].Tag
            if ($fnd -and $fnd.FixId) { Invoke-ZUIFix $fnd }
        })
    $g
}

function Set-ZFindings { param($Grid, [object[]]$Findings)
    $Grid.SuspendLayout(); $Grid.Rows.Clear()
    foreach ($f in @($Findings)) {
        if (-not $f) { continue }
        $lbl = ''; if ($f.FixId) { $lbl = $f.FixLabel }
        [void](Add-ZRow $Grid @($f.Severity, $f.Category, $f.Title, $f.Detail, $f.Advice, $lbl) $f)
    }
    if ($Grid.Rows.Count -eq 0) { [void](Add-ZRow $Grid @('İYİ', '—', 'Sorun bulunamadı', '', 'Bu bölümde herhangi bir sorun tespit edilmedi.', '')) }
    $Grid.ResumeLayout()
}

# =====================================================================
#  ETKİNLİK GÜNLÜĞÜ + ARKA PLAN İŞLERİ
# =====================================================================
function Write-ZActivity { param([string]$Line)
    if (-not $UI.Log) { return }
    if ($UI.Log.TextLength -gt 300000) { $UI.Log.Text = $UI.Log.Text.Substring($UI.Log.TextLength - 100000) }
    $UI.Log.AppendText($Line + [Environment]::NewLine)
}

function Start-ZJob {
    param([string]$Name, [scriptblock]$Script, [hashtable]$Params = @{}, [scriptblock]$OnDone = $null, [object[]]$Disable = @(), [switch]$Quiet)
    foreach ($j in $Script:Jobs) { if ($j.Name -eq $Name) { if (-not $Quiet) { Show-ZInfo ('«{0}» işlemi zaten çalışıyor.' -f $Name) }; return $null } }
    $sync = [hashtable]::Synchronized(@{ Log = New-Object 'System.Collections.Concurrent.ConcurrentQueue[string]'; Samples = New-Object 'System.Collections.Concurrent.ConcurrentQueue[object]'; Progress = 0; Status = $Name; Cancel = $false })
    $rs = [runspacefactory]::CreateRunspace(); $rs.ApartmentState = 'STA'; $rs.ThreadOptions = 'ReuseThread'; $rs.Open()
    $rs.SessionStateProxy.SetVariable('Sync', $sync); $rs.SessionStateProxy.SetVariable('JobParams', $Params)
    $ps = [powershell]::Create(); $ps.Runspace = $rs
    [void]$ps.AddScript($Script:CoreCode + "`r`n" + $Script.ToString())
    $handle = $ps.BeginInvoke()
    foreach ($zctl in $Disable) { if ($zctl) { $zctl.Enabled = $false } }
    $job = [pscustomobject]@{ Name = $Name; PS = $ps; Handle = $handle; Sync = $sync; OnDone = $OnDone; Disable = $Disable; Runspace = $rs; Quiet = [bool]$Quiet }
    [void]$Script:Jobs.Add($job)
    if (-not $Quiet) { Write-ZActivity ('▶ ' + $Name); Set-ZTaskChip $Name 0 }
    $job
}

function Set-ZTaskChip { param([string]$Text, [int]$Pct, [bool]$Busy = $true)
    if (-not $UI.Chip) { return }
    $UI.Chip.Tag.Text = $Text; $UI.Chip.Tag.Pct = $Pct; $UI.Chip.Tag.Busy = $Busy; $UI.Chip.Invalidate()
    if ($UI.FixBusy -and $UI.FixBusy.Visible -and $Busy) { $UI.FixBusy.Tag.Text = $Text; $UI.FixBusy.Tag.Pct = $Pct; $UI.FixBusy.Invalidate() }
}

function Update-ZJobs {
    $active = $null
    foreach ($job in @($Script:Jobs)) {
        $line = $null
        while ($job.Sync.Log.TryDequeue([ref]$line)) { Write-ZActivity $line }
        if (-not $job.Quiet) { $active = $job }
        if ($job.Handle.IsCompleted) {
            $out = $null
            try { $out = $job.PS.EndInvoke($job.Handle) } catch { Write-ZActivity ('✖ ' + $job.Name + ': ' + $_.Exception.Message) }
            while ($job.Sync.Log.TryDequeue([ref]$line)) { Write-ZActivity $line }
            $ec = 0
            foreach ($er in $job.PS.Streams.Error) {
                if ("$er" -match 'NativeCommandError') { continue }
                try { Add-Content -Path (Join-Path $Global:ZLogDir 'hata-kaydi.log') -Value ('[{0}] {1} :: {2} :: satır {3}' -f (Get-Date), $job.Name, "$er", $er.InvocationInfo.ScriptLineNumber) -Encoding UTF8 } catch {}
                $ec++
            }
            if ($ec -gt 0) { Write-ZActivity ("ⓘ {0}: {1} küçük uyarı hata-kaydi.log dosyasına yazıldı." -f $job.Name, $ec) }
            foreach ($zctl in $job.Disable) { if ($zctl) { $zctl.Enabled = $true } }
            $result = $null
            if ($out -and $out.Count -gt 0) { $result = $out[$out.Count - 1] }
            try { $job.PS.Dispose(); $job.Runspace.Close(); $job.Runspace.Dispose() } catch {}
            $Script:Jobs.Remove($job)
            if (-not $job.Quiet) { Write-ZActivity ('■ ' + $job.Name + ' bitti.'); Set-ZTaskChip 'Hazır' 100 $false }
            if ($job.OnDone) { try { & $job.OnDone $result } catch { Write-ZErrorLog $_ ('OnDone: ' + $job.Name); Write-ZActivity ('Arayüz hatası (' + $job.Name + '): ' + $_.Exception.Message) } }
        }
    }
    if ($active -and -not $active.Handle.IsCompleted) { Set-ZTaskChip ($active.Sync.Status) (ConvertTo-ZInt $active.Sync.Progress) $true }
    $line = $null
    while ($Global:Sync.Log.TryDequeue([ref]$line)) { Write-ZActivity $line }
}

function Confirm-Z { param([string]$Text) ([System.Windows.Forms.MessageBox]::Show($Text, 'ZETX — Onay', 'YesNo', 'Question') -eq 'Yes') }
function Show-ZInfo { param([string]$Text, [string]$Icon = 'Information') [System.Windows.Forms.MessageBox]::Show($Text, 'ZETX PC ARIZA TAKİP ONARIM', 'OK', $Icon) | Out-Null }

$Script:ConfirmFix = @{
    CHKDSK_SCHEDULE = 'Disk taraması bir sonraki yeniden başlatmada yapılacak ve saatler sürebilir. Devam edilsin mi?'
    NET_RESET = 'Ağ ayarları sıfırlanacak, internet birkaç saniye kesilecek ve yeniden başlatma gerekecek. Devam edilsin mi?'
    WU_RESET = 'Windows Update hizmetleri durdurulup önbelleği sıfırlanacak. Devam edilsin mi?'
    HOSTS_RESET = 'HOSTS dosyası varsayılana döndürülecek (yedek alınır). Devam edilsin mi?'
    WINLOGON_SHELL = 'Winlogon Shell değeri explorer.exe yapılacak (yedek alınır). Devam edilsin mi?'
    WINLOGON_USERINIT = 'Userinit değeri varsayılana döndürülecek (yedek alınır). Devam edilsin mi?'
    REG_DEL_VALUE = 'Kayıt defteri değeri kaldırılacak (önce yedek alınır). Devam edilsin mi?'
    DNS_CLOUDFLARE = 'Etkin ağ bağdaştırıcılarının DNS sunucusu 1.1.1.1 / 1.0.0.1 yapılacak. Devam edilsin mi?'
    ICON_CACHE = 'Windows Gezgini kısa süre kapanıp yeniden açılacak. Devam edilsin mi?'
    EXPLORER_RESTART = 'Windows Gezgini yeniden başlatılacak. Devam edilsin mi?'
    FULL_REPAIR = 'TAM ONARIM: Geri yükleme noktası + DISM + SFC + CHKDSK sırayla çalışır, 20–60 dakika sürebilir. Başlatılsın mı?'
    APPINIT_OFF = 'AppInit_DLLs devre dışı bırakılacak (yedek alınır). Devam edilsin mi?'
}
$Script:NoConfirm = @('OPEN_URL', 'GPU_DRIVER', 'OPEN_WU', 'OPEN_DEFENDER', 'BATTERY_REPORT', 'DEVICE_RESCAN', 'DNS_FLUSH', 'RESTORE_POINT', 'WU_DRIVERS', 'POWER_HIGH', 'POWER_ULTIMATE', 'DEFENDER_UPDATE')

function Invoke-ZUIFix { param($Finding, [switch]$NoConfirm)
    $id = $Finding.FixId; $data = $Finding.FixData
    $title = Get-ZFixTitle $id; if (-not $title) { $title = $Finding.FixLabel }; if (-not $title) { $title = $id }
    if (-not $NoConfirm -and $id -notin $Script:NoConfirm) {
        $q = $Script:ConfirmFix[$id]; if (-not $q) { $q = ('«{0}» için «{1}» uygulansın mı?' -f $Finding.Title, $title) }
        if (-not (Confirm-Z $q)) { return }
    }
    $rp = $false; if ($UI.RestoreCheck -and $UI.RestoreCheck.Checked -and $id -in 'SFC', 'DISM_RESTORE', 'WINLOGON_SHELL', 'WINLOGON_USERINIT', 'REG_DEL_VALUE', 'WU_RESET', 'NET_RESET') { $rp = $true }
    [void](Start-ZJob ('Onarım: ' + $title) {
            if ($JobParams.RP) { [void](New-ZRestorePoint) }
            $r = Invoke-ZFix $JobParams.Id $JobParams.Data
            [pscustomobject]@{ R = $r; Id = $JobParams.Id; RP = [bool]$JobParams.RP }
        } @{ Id = $id; Data = $data; RP = $rp } {
            param($res)
            if ($res -and $res.R -and ($res.Id -in 'RESTORE_POINT', 'FULL_REPAIR' -or $res.RP) -and $UI.RpBanner) { $UI.RpBanner.Visible = $false }
            if ($res -and $res.Id -eq 'RESTORE_POINT') { if ($res.R) { Show-ZInfo 'Sistem geri yükleme noktası oluşturuldu.' } else { Show-ZInfo 'Geri yükleme noktası oluşturulamadı. Ayrıntılar İşlem Günlüğüʼnde.' 'Warning' } }
        })
}

# =====================================================================
#  LOGO + İKON
# =====================================================================
$Script:AppIcon = $null; $Script:AppIconImg = $null
try { $ms = New-Object System.IO.MemoryStream(, [Convert]::FromBase64String($Script:LogoB64)); $Script:AppIconImg = [System.Drawing.Image]::FromStream($ms) } catch {}
try { $Script:AppIcon = [System.Drawing.Icon]::ExtractAssociatedIcon([Diagnostics.Process]::GetCurrentProcess().MainModule.FileName) } catch {}
if ($PSCommandPath) {
    $icoFile = Join-Path (Split-Path -Parent $PSCommandPath) 'zetx.ico'
    if (Test-Path $icoFile) { try { $Script:AppIcon = New-Object System.Drawing.Icon($icoFile) } catch {} }
}

# =====================================================================
#  ANA PENCERE
# =====================================================================
$form = New-Object System.Windows.Forms.Form
$form.SuspendLayout()
$form.AutoScaleDimensions = New-Object System.Drawing.SizeF(96, 96); $form.AutoScaleMode = 'Dpi'
$form.Text = ('{0}  v{1}' -f $Global:ZETX.AppName, $Global:ZETX.Version)
$form.ClientSize = New-Object System.Drawing.Size(1380, 860); $form.MinimumSize = New-Object System.Drawing.Size(1180, 720)
$form.StartPosition = 'CenterScreen'; $form.BackColor = $ZC.Bg; $form.ForeColor = $ZC.Text; $form.Font = $ZF.Body
if ($Script:AppIcon) { $form.Icon = $Script:AppIcon }
Set-ZDB $form

# ---- Kenar çubuğu ----
$side = New-ZPanel 'Left' 0 $ZC.Side 0; $side.Width = 250
$side.Add_Paint({ param($s, $e) try { $pn = New-Object System.Drawing.Pen($ZC.Border, 1); $e.Graphics.DrawLine($pn, $s.Width - 1, 0, $s.Width - 1, $s.Height); $pn.Dispose()  } catch { } })
$logo = New-Object System.Windows.Forms.Panel; $logo.Dock = 'Top'; $logo.Height = 80; $logo.BackColor = $ZC.Side; Set-ZDB $logo
$logo.Add_Paint({
        param($s, $e) try {
        $g = $e.Graphics; $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBicubic'
        if ($Script:AppIconImg) { $g.DrawImage($Script:AppIconImg, 22, 20, 40, 40) }
        [System.Windows.Forms.TextRenderer]::DrawText($g, 'ZETX', $ZF.Logo, (New-Object System.Drawing.Point(70, 15)), $ZC.White)
        [System.Windows.Forms.TextRenderer]::DrawText($g, 'PC Arıza Takip Onarım', $ZF.LogoSub, (New-Object System.Drawing.Point(72, 46)), $ZC.Text2)
     } catch { } })
$nav = New-Object System.Windows.Forms.FlowLayoutPanel; $nav.Dock = 'Fill'; $nav.FlowDirection = 'TopDown'; $nav.WrapContents = $false; $nav.AutoScroll = $true; $nav.BackColor = $ZC.Side
$nav.Padding = New-Object System.Windows.Forms.Padding(0, 0, 0, 4)

$Script:NavDef = @(
    @('#', 'İZLEME'),
    @('dash', 'Genel Bakış', $ZI.Home, 'Sistem sağlığı, canlı kullanım ve hızlı işlemler'),
    @('track', 'Takip & Rapor', $ZI.Hist, 'Tarama geçmişi, puan değişimi, HTML rapor ve otomatik takip'),
    @('#', 'TANILAMA'),
    @('fix', 'Tarama & Onarım', $ZI.Scan, 'Tüm arızaları tarayın, önerileri görün ve tek tıkla onarın'),
    @('hw', 'Donanım', $ZI.Hw, 'Disk sağlığı (SMART), bellek modülleri, aygıtlar ve donanım hataları'),
    @('sys', 'Sistem Arızaları', $ZI.Warn, 'Mavi ekran geçmişi, ani kapanmalar, çöken programlar ve hizmetler'),
    @('drv', 'Sürücü & BIOS', $ZI.Driver, 'Yüklü sürücü ve BIOS sürümleri, güncelleme bağlantıları'),
    @('net', 'Ağ / İnternet', $ZI.Net, 'Ping, paket kaybı, DNS ve bağlantı kalitesi'),
    @('#', 'PERFORMANS'),
    @('fps', 'FPS & Oyunlar', $ZI.Game, 'Tahmini oyun FPS değerleri ve öncesi / sonrası gerçek FPS ölçümü'),
    @('bott', 'Darboğaz Analizi', $ZI.Bolt, 'İşlemci ↔ ekran kartı dengesi ve oyun içi canlı ölçüm'),
    @('score', 'Sistem Puanı', $ZI.Star, 'ZETX genel puanı ve Windows performans testleri'),
    @('#', 'ONARIM'),
    @('repair', 'Dosya Onarımı', $ZI.Repair, 'SFC, DISM, CHKDSK ve Windows bileşen onarımları'),
    @('reg', 'Kayıt Defteri', $ZI.Reg, 'Geçersiz girdiler, yedekleme ve ele geçirme kontrolü'),
    @('clean', 'Temizlik & Başlangıç', $ZI.Clean, 'Gereksiz dosyalar, başlangıç programları ve güç planı'),
    @('#', 'DİĞER'),
    @('about', 'Hakkında', $ZI.Info, 'Geliştirici, Discord topluluğu ve iletişim')
)
foreach ($n in $Script:NavDef) {
    if ($n[0] -eq '#') {
        $gl = New-ZLabel $n[1] $ZF.Tiny $ZC.Muted 'None' 0 'BottomLeft'
        $gl.AutoSize = $false; $gl.Width = 246; $gl.Height = 30; $gl.Padding = New-Object System.Windows.Forms.Padding(26, 0, 0, 5); $gl.Margin = New-Object System.Windows.Forms.Padding(0)
        $nav.Controls.Add($gl); continue
    }
    $UI.NavMeta[$n[0]] = @{ Title = $n[1]; Icon = $n[2]; Sub = $n[3] }
    $it = New-Object System.Windows.Forms.Panel; $it.Width = 246; $it.Height = 38; $it.Margin = New-Object System.Windows.Forms.Padding(0, 1, 0, 1); $it.BackColor = $ZC.Side
    $it.Cursor = [System.Windows.Forms.Cursors]::Hand; $it.Tag = @{ Key = $n[0]; Text = $n[1]; Icon = $n[2]; Active = $false; Hover = $false }
    Set-ZDB $it
    $it.Add_Paint({
            param($s, $e) try {
            $t = $s.Tag; $g = $e.Graphics; $g.SmoothingMode = 'AntiAlias'
            if ($t.Active -or $t.Hover) {
                $p = Get-ZRoundPath 10 1 ($s.Width - 22) ($s.Height - 2) 6
                $bc = $ZC.Hover; if ($t.Active) { $bc = $ZC.Surf2 }
                $b = New-Object System.Drawing.SolidBrush($bc); $g.FillPath($b, $p); $b.Dispose(); $p.Dispose()
            }
            if ($t.Active) { $ab = New-Object System.Drawing.SolidBrush($ZC.Accent); $g.FillRectangle($ab, 10, 9, 3, $s.Height - 18); $ab.Dispose() }
            $fc = $ZC.Text2; $ic = $ZC.Muted; $fnt = $ZF.Nav
            if ($t.Active) { $fc = $ZC.White; $ic = $ZC.Accent; $fnt = $ZF.NavB } elseif ($t.Hover) { $fc = $ZC.Text }
            $fl = [System.Windows.Forms.TextFormatFlags]'VerticalCenter, Left, SingleLine, NoPadding'
            [System.Windows.Forms.TextRenderer]::DrawText($g, $t.Icon, $ZF.Icon, (New-Object System.Drawing.Rectangle(26, 0, 22, $s.Height)), $ic, $fl)
            [System.Windows.Forms.TextRenderer]::DrawText($g, $t.Text, $fnt, (New-Object System.Drawing.Rectangle(56, 0, ($s.Width - 66), $s.Height)), $fc, $fl)
         } catch { } })
    $it.Add_MouseEnter({ $this.Tag.Hover = $true; $this.Invalidate() })
    $it.Add_MouseLeave({ $this.Tag.Hover = $false; $this.Invalidate() })
    $it.Add_Click({ Show-ZPage $this.Tag.Key })
    $UI.Nav[$n[0]] = $it
    $nav.Controls.Add($it)
}
$licBox = New-Object System.Windows.Forms.Panel; $licBox.Dock = 'Bottom'; $licBox.Height = 104; $licBox.BackColor = $ZC.Side; $licBox.Cursor = [System.Windows.Forms.Cursors]::Hand; Set-ZDB $licBox
$licBox.Add_Paint({
        param($s, $e) try {
        $g = $e.Graphics; $g.SmoothingMode = 'AntiAlias'
        $p = Get-ZRoundPath 14 8 ($s.Width - 30) ($s.Height - 18) 8
        $b = New-Object System.Drawing.SolidBrush($ZC.Surf); $g.FillPath($b, $p); $b.Dispose()
        $pn = New-Object System.Drawing.Pen($ZC.Border, 1); $g.DrawPath($pn, $p); $pn.Dispose(); $p.Dispose()
        [System.Windows.Forms.TextRenderer]::DrawText($g, $ZI.Check, $ZF.Icon, (New-Object System.Drawing.Point(28, 22)), $ZC.Green)
        [System.Windows.Forms.TextRenderer]::DrawText($g, 'ÜCRETSİZ SÜRÜM', $ZF.Tiny, (New-Object System.Drawing.Point(52, 23)), $ZC.Green)
        [System.Windows.Forms.TextRenderer]::DrawText($g, 'Tüm özellikler açık', $ZF.Bold, (New-Object System.Drawing.Point(28, 44)), $ZC.Text)
        [System.Windows.Forms.TextRenderer]::DrawText($g, ($ZI.Chat + '  Discord topluluğuna katıl'), $ZF.Small, (New-Object System.Drawing.Point(28, 68)), $ZC.AccentHi)
        } catch { } })
$licBox.Add_Click({ Start-Process $Global:ZETX.Discord })
$side.Controls.Add($nav); $side.Controls.Add($licBox); $side.Controls.Add($logo)

# ---- Üst başlık ----
$header = New-Object System.Windows.Forms.Panel; $header.Dock = 'Top'; $header.Height = 76; $header.BackColor = $ZC.Bg; Set-ZDB $header
$header.Tag = @{ Title = ''; Sub = ''; Icon = '' }
$header.Add_Paint({
        param($s, $e) try {
        $g = $e.Graphics; $t = $s.Tag
        $fl = [System.Windows.Forms.TextFormatFlags]'Left, SingleLine, NoPadding, EndEllipsis'
        [System.Windows.Forms.TextRenderer]::DrawText($g, $t.Icon, $ZF.IconL, (New-Object System.Drawing.Point(28, 22)), $ZC.Accent)
        $tw = [math]::Max(100, $s.Width - 560)
        [System.Windows.Forms.TextRenderer]::DrawText($g, $t.Title, $ZF.H1, (New-Object System.Drawing.Rectangle(62, 14, $tw, 30)), $ZC.Text, $fl)
        [System.Windows.Forms.TextRenderer]::DrawText($g, $t.Sub, $ZF.Sub, (New-Object System.Drawing.Rectangle(63, 44, $tw, 20)), $ZC.Text2, $fl)
        $pn = New-Object System.Drawing.Pen($ZC.Border, 1); $g.DrawLine($pn, 0, $s.Height - 1, $s.Width, $s.Height - 1); $pn.Dispose()
     } catch { } })
$chip = New-Object System.Windows.Forms.Panel; $chip.Width = 360; $chip.Height = 40; $chip.BackColor = $ZC.Bg
$chip.Tag = @{ Text = 'Hazır'; Pct = 0; Busy = $false }; Set-ZDB $chip
$chip.Add_Paint({
        param($s, $e) try {
        $g = $e.Graphics; $g.SmoothingMode = 'AntiAlias'; $t = $s.Tag
        $p = Get-ZRoundPath 0.5 0.5 ($s.Width - 1.5) ($s.Height - 1.5) 8
        $b = New-Object System.Drawing.SolidBrush($ZC.Surf); $g.FillPath($b, $p); $b.Dispose()
        $pn = New-Object System.Drawing.Pen($ZC.Border, 1); $g.DrawPath($pn, $p); $pn.Dispose(); $p.Dispose()
        $dot = $ZC.Green; if ($t.Busy) { $dot = $ZC.Accent }
        $db = New-Object System.Drawing.SolidBrush($dot); $g.FillEllipse($db, 14, 16, 8, 8); $db.Dispose()
        $txt = $t.Text; if ($t.Busy) { $txt = ('{0}  —  %{1}' -f $t.Text, $t.Pct) }
        $ty = 11; if ($t.Busy) { $ty = 6 }
        [System.Windows.Forms.TextRenderer]::DrawText($g, $txt, $ZF.Small, (New-Object System.Drawing.Rectangle(30, $ty, ($s.Width - 40), 18)), $ZC.Text, [System.Windows.Forms.TextFormatFlags]'Left, SingleLine, NoPadding, EndEllipsis')
        if ($t.Busy) {
            $bg = New-Object System.Drawing.SolidBrush($ZC.Surf2); $g.FillRectangle($bg, 30, 27, $s.Width - 44, 4); $bg.Dispose()
            $fg = New-Object System.Drawing.SolidBrush($ZC.Accent); $g.FillRectangle($fg, 30, 27, [int](($s.Width - 44) * [math]::Min(100, $t.Pct) / 100), 4); $fg.Dispose()
        }
     } catch { } })
$logBtn = New-ZBtn 'Günlük' $ZI.List 'ghost' 96 36
$header.Controls.Add($chip); $header.Controls.Add($logBtn)
$Script:PlaceHeader = { $chip.Left = $header.Width - $chip.Width - 128; $chip.Top = 18; $logBtn.Left = $header.Width - $logBtn.Width - 22; $logBtn.Top = 20 }
$header.Add_Resize({ & $Script:PlaceHeader })
$UI.Header = $header; $UI.Chip = $chip

# ---- Etkinlik günlüğü (alt çekmece) ----
$drawer = New-ZPanel 'Bottom' 168 $ZC.Console 0
$drawer.Add_Paint({ param($s, $e) try { $pn = New-Object System.Drawing.Pen($ZC.Border, 1); $e.Graphics.DrawLine($pn, 0, 0, $s.Width, 0); $pn.Dispose()  } catch { } })
$drHead = New-ZPanel 'Top' 32 $ZC.Console 0; $drHead.Padding = New-Object System.Windows.Forms.Padding(26, 2, 14, 0)
$drTitle = New-ZLabel 'İŞLEM GÜNLÜĞÜ' $ZF.Tiny $ZC.Muted 'Fill' 0 'MiddleLeft'
$drClear = New-ZBtn 'Temizle' '' 'ghost' 74 26; $drClear.Dock = 'Right'
$drHead.Controls.Add($drTitle); $drHead.Controls.Add($drClear)
$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Multiline = $true; $logBox.ReadOnly = $true; $logBox.ScrollBars = 'Vertical'; $logBox.WordWrap = $true
$logBox.BackColor = $ZC.Console; $logBox.ForeColor = (RGB 150 220 180); $logBox.Font = $ZF.Mono; $logBox.BorderStyle = 'None'; $logBox.Dock = 'Fill'
$logWrap = New-ZPanel 'Fill' 0 $ZC.Console 0; $logWrap.Padding = New-Object System.Windows.Forms.Padding(26, 0, 8, 8); $logWrap.Controls.Add($logBox)
$drawer.Controls.Add($logWrap); $drawer.Controls.Add($drHead)
$UI.Log = $logBox
$drClear.Add_Click({ $UI.Log.Clear() })
$logBtn.Add_Click({ $drawer.Visible = -not $drawer.Visible })

$content = New-ZPanel 'Fill' 0 $ZC.Bg 0

function New-ZPage { param([string]$Key)
    $p = New-ZPanel 'Fill' 0 $ZC.Bg 0
    $p.Padding = New-Object System.Windows.Forms.Padding(26, 16, 26, 18); $p.Visible = $false
    $UI.Pages[$Key] = $p; $content.Controls.Add($p); $p
}

function New-ZBusyCard {
    $p = New-Object System.Windows.Forms.Panel; $p.Dock = 'Top'; $p.Height = 64; $p.BackColor = $ZC.Bg; $p.Visible = $false
    $p.Tag = @{ Text = ''; Pct = 0 }; Set-ZDB $p
    $p.Add_Paint({
            param($s, $e) try {
            $g = $e.Graphics; $g.SmoothingMode = 'AntiAlias'; $t = $s.Tag
            $pa = Get-ZRoundPath 0.5 0.5 ($s.Width - 1.5) ($s.Height - 13) 8
            $b = New-Object System.Drawing.SolidBrush($ZC.AccentDim); $g.FillPath($b, $pa); $b.Dispose(); $pa.Dispose()
            [System.Windows.Forms.TextRenderer]::DrawText($g, $ZI.Refresh, $ZF.IconM, (New-Object System.Drawing.Point(16, 14)), $ZC.AccentHi)
            [System.Windows.Forms.TextRenderer]::DrawText($g, ('{0}   %{1}' -f $t.Text, $t.Pct), $ZF.Bold, (New-Object System.Drawing.Point(44, 10)), $ZC.White)
            $bg = New-Object System.Drawing.SolidBrush((RGB 18 32 54)); $g.FillRectangle($bg, 44, 34, $s.Width - 64, 5); $bg.Dispose()
            $fg = New-Object System.Drawing.SolidBrush($ZC.Accent); $g.FillRectangle($fg, 44, 34, [int](($s.Width - 64) * [math]::Min(100, $t.Pct) / 100), 5); $fg.Dispose()
         } catch { } })
    $p
}

# =====================================================================
#  SAYFA: GENEL BAKIŞ
# =====================================================================
$pg = New-ZPage 'dash'
$rpBanner = New-Object System.Windows.Forms.Panel; $rpBanner.Dock = 'Top'; $rpBanner.Height = 64; $rpBanner.BackColor = $ZC.Bg; $rpBanner.Visible = $false
$rpBanner.Tag = @{ Text = '' }; Set-ZDB $rpBanner
$rpBanner.Add_Paint({
        param($s, $e) try {
        $g = $e.Graphics; $g.SmoothingMode = 'AntiAlias'
        $pa = Get-ZRoundPath 0.5 0.5 ($s.Width - 1.5) ($s.Height - 13) 8
        $b = New-Object System.Drawing.SolidBrush((RGB 52 38 14)); $g.FillPath($b, $pa); $b.Dispose()
        $pn = New-Object System.Drawing.Pen((ARGB 140 $ZC.Orange), 1); $g.DrawPath($pn, $pa); $pn.Dispose(); $pa.Dispose()
        [System.Windows.Forms.TextRenderer]::DrawText($g, $ZI.Restore, $ZF.IconM, (New-Object System.Drawing.Point(16, 15)), $ZC.Orange)
        [System.Windows.Forms.TextRenderer]::DrawText($g, $s.Tag.Text, $ZF.Bold, (New-Object System.Drawing.Rectangle(46, 0, ($s.Width - 260), ($s.Height - 12))), $ZC.Text, [System.Windows.Forms.TextFormatFlags]'Left, VerticalCenter, WordBreak, NoPadding, EndEllipsis')
        } catch { } })
$rpNow = New-ZBtn 'Şimdi Oluştur' $ZI.Restore 'primary' 150 34; $rpNow.Anchor = 'Top, Right'
$rpLater = New-ZBtn 'Sonra' '' 'ghost' 64 34; $rpLater.Anchor = 'Top, Right'
$rpBanner.Controls.Add($rpNow); $rpBanner.Controls.Add($rpLater)
$rpBanner.Add_Resize({ $rpLater.Left = $rpBanner.Width - $rpLater.Width - 12; $rpLater.Top = 9; $rpNow.Left = $rpLater.Left - $rpNow.Width - 6; $rpNow.Top = 9 })
$rpLater.Add_Click({ $rpBanner.Visible = $false })
$rpNow.Add_Click({ Invoke-ZUIFix (New-ZFinding 'BİLGİ' 'Güvenlik' 'Geri yükleme noktası' '' '' 'RESTORE_POINT') -NoConfirm })
$UI.RpBanner = $rpBanner
$ring = New-ZRing; $UI.Ring = $ring
$kH = New-ZKpi 'Sistem sağlığı' $ZC.Green '—' 'Tarama bekleniyor'
$kP = New-ZKpi 'Performans' $ZC.Accent '—' 'Donanım sınıfı'
$kC = New-ZKpi 'Kritik sorun' $ZC.Red '—' ''
$kW = New-ZKpi 'Uyarı' $ZC.Orange '—' ''
$UI.Kpi = @{ H = $kH; P = $kP; C = $kC; W = $kW }
$kGrid = New-Object System.Windows.Forms.TableLayoutPanel; $kGrid.BackColor = $ZC.Bg; $kGrid.ColumnCount = 2; $kGrid.RowCount = 2
[void]$kGrid.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, [float]50))); [void]$kGrid.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, [float]50)))
[void]$kGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, [float]50))); [void]$kGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, [float]50)))
foreach ($k0 in $kH, $kP, $kC, $kW) { $k0.Dock = 'Fill' }
$kH.Margin = New-Object System.Windows.Forms.Padding(0, 0, 6, 6); $kP.Margin = New-Object System.Windows.Forms.Padding(6, 0, 0, 6); $kC.Margin = New-Object System.Windows.Forms.Padding(0, 6, 6, 0); $kW.Margin = New-Object System.Windows.Forms.Padding(6, 6, 0, 0)
$kGrid.Controls.Add($kH, 0, 0); $kGrid.Controls.Add($kP, 1, 0); $kGrid.Controls.Add($kC, 0, 1); $kGrid.Controls.Add($kW, 1, 1)
$qa = New-ZCard 'Hızlı İşlemler' $ZI.Bolt 'Fill'
$qaFlow = New-Object System.Windows.Forms.FlowLayoutPanel; $qaFlow.Dock = 'Fill'; $qaFlow.FlowDirection = 'TopDown'; $qaFlow.WrapContents = $false; $qaFlow.BackColor = $ZC.Surf
$btnScan = New-ZBtn 'Tam Tarama Başlat' $ZI.Play 'primary' 238 38
$btnFull = New-ZBtn 'Tam Onarım (DISM+SFC+CHKDSK)' $ZI.Repair 'purple' 238 34
$btnRep = New-ZBtn 'HTML Rapor Oluştur' $ZI.Doc 'secondary' 238 34
$btnRp = New-ZBtn 'Geri Yükleme Noktası' $ZI.Restore 'secondary' 238 34
$qaFlow.Controls.AddRange(@($btnScan, $btnFull, $btnRep, $btnRp)); $qa.Controls.Add($qaFlow)
$row1 = New-ZCols @($ring, $kGrid, $qa) @(-250, 100, -272) 'Top' 236
$mCpu = New-ZMeter 'İşlemci' $ZC.Accent; $mGpu = New-ZMeter 'Ekran kartı' $ZC.Purple; $mRam = New-ZMeter 'Bellek' $ZC.Green; $mDisk = New-ZMeter 'Disk' $ZC.Orange
$UI.Meters = @{ Cpu = $mCpu; Gpu = $mGpu; Ram = $mRam; Disk = $mDisk }
$row2 = New-ZCols @($mCpu, $mGpu, $mRam, $mDisk) @(25, 25, 25, 25) 'Top' 118
$infoCard = New-ZCard 'Sistem Özeti' $ZI.Hw 'Fill'
$infoGrid = New-ZGrid @('Özellik:26', 'Değer:74') -NoHeader; $infoGrid.Columns[0].DefaultCellStyle.ForeColor = $ZC.Text2; $infoGrid.RowTemplate.Height = 30
$infoCard.Controls.Add($infoGrid); $UI.InfoGrid = $infoGrid
$topCard = New-ZCard 'Öne Çıkan Bulgular' $ZI.Warn 'Fill'
$topGrid = New-ZGrid @('@SEV:Önem:28', 'Sorun:72') -NoHeader; $topGrid.RowTemplate.Height = 34
$topCard.Controls.Add($topGrid); $UI.TopGrid = $topGrid
[void](Add-ZRow $topGrid @('BİLGİ', 'Tam tarama yapıldığında önemli bulgular burada listelenir.'))
$topGrid.Add_CellDoubleClick({ Show-ZPage 'fix' })
$row3 = New-ZCols @($infoCard, $topCard) @(56, 44) 'Fill'
Add-ZDock $pg @($rpBanner, $row1, (New-ZSpacer 12), $row2, (New-ZSpacer 12), $row3)

function Update-ZScoreUI { param($Scan)
    if (-not $Scan -or -not $Scan.Scores) { return }
    $s = $Scan.Scores
    Set-ZRing $UI.Ring $s.Overall $s.Grade ('Son tarama: ' + (Get-Date -Format 'dd.MM.yyyy HH:mm')) 'ZETX PUANI'
    Set-ZKpi $UI.Kpi.H ("$($s.Health)") '/ 100 sağlık puanı'
    Set-ZKpi $UI.Kpi.P ("$($s.Performance)") ("CPU {0} • GPU {1}" -f $Scan.Static.CpuScore, $Scan.Static.GpuScore)
    Set-ZKpi $UI.Kpi.C ("$($s.Critical)") $(if ($s.Critical) { 'Hemen ilgilenin' } else { 'Kritik sorun yok' })
    Set-ZKpi $UI.Kpi.W ("$($s.Warning)") ("{0} bilgi notu" -f $s.Info)
    $UI.TopGrid.Rows.Clear()
    foreach ($f in @($Scan.Findings | Where-Object { $_.Severity -in 'KRİTİK', 'UYARI' } | Select-Object -First 8)) { [void](Add-ZRow $UI.TopGrid @($f.Severity, $f.Title) $f) }
    if ($UI.TopGrid.Rows.Count -eq 0) { [void](Add-ZRow $UI.TopGrid @('İYİ', 'Kritik veya uyarı düzeyinde sorun yok')) }
    if ($UI.ScoreBars) {
        Set-ZScoreBar $UI.ScoreBars.Overall $s.Overall ("{0} / 100  •  Derece {1}" -f $s.Overall, $s.Grade)
        Set-ZScoreBar $UI.ScoreBars.Health $s.Health ("{0} / 100" -f $s.Health)
        Set-ZScoreBar $UI.ScoreBars.Perf $s.Performance ("{0} / 100" -f $s.Performance)
        Set-ZRing $UI.ScoreRing2 $s.Overall $s.Grade ('Kritik {0} • Uyarı {1}' -f $s.Critical, $s.Warning)
    }
}

$Script:ScanScript = { $r = Invoke-ZFullScan; [pscustomobject]@{ R = $r } }
$Script:OnScanDone = {
    param($res)
    if ($UI.FixBusy) { $UI.FixBusy.Visible = $false }
    if (-not $res -or -not $res.R) { Show-ZInfo 'Tarama tamamlanamadı. Ayrıntılar İşlem Günlüğüʼnde ve Belgeler\ZETX PC Ariza Takip\Kayitlar\hata-kaydi.log dosyasında.' 'Warning'; return }
    $Script:LastScan = $res.R
    $Script:AllFindings = @($res.R.Findings)
    Update-ZScoreUI $res.R
    Update-ZFixGrid
    Update-ZBeforeAfter
    Update-ZHistoryUI
    Show-ZPage 'fix'
}
function Start-ZFullScan {
    $j = Start-ZJob 'Tam Tarama' $Script:ScanScript @{} $Script:OnScanDone @($btnScan, $UI.FixScanBtn, $UI.ScoreScanBtn)
    if ($j) {
        $UI.FixBusy.Tag.Text = 'Tam tarama sürüyor — donanım, olay günlükleri, Windows, sürücüler, güvenlik ve kayıt defteri (1–3 dk)'; $UI.FixBusy.Tag.Pct = 0
        $UI.FixBusy.Visible = $true; $UI.FixBusy.Invalidate()
        Show-ZPage 'fix'
    }
}
$btnScan.Add_Click({ Start-ZFullScan })
$btnFull.Add_Click({ Invoke-ZUIFix (New-ZFinding 'BİLGİ' 'Onarım' 'Tam onarım' '' '' 'FULL_REPAIR') })
$btnRp.Add_Click({ Invoke-ZUIFix (New-ZFinding 'BİLGİ' 'Onarım' 'Geri yükleme noktası' '' '' 'RESTORE_POINT') -NoConfirm })
$btnRep.Add_Click({ New-ZUIReport })

function New-ZUIReport {
    [void](Start-ZJob 'HTML Rapor' {
            $scan = $JobParams.Scan
            if (-not $scan) { $scan = Invoke-ZFullScan }
            $file = Export-ZReport $scan (Get-ZSystemInfo) $JobParams.Lic
            Write-ZLog ("Rapor kaydedildi: {0}" -f $file) 'OK'
            [pscustomobject]@{ R = $file; Scan = $scan }
        } @{ Scan = $Script:LastScan; Lic = $null } {
            param($res)
            if ($res -and $res.R) {
                if (-not $Script:LastScan -and $res.Scan) { $Script:LastScan = $res.Scan; $Script:AllFindings = @($res.Scan.Findings); Update-ZScoreUI $res.Scan; Update-ZFixGrid; Update-ZHistoryUI }
                Start-Process $res.R
            }
        })
}

# =====================================================================
#  SAYFA: TARAMA & ONARIM
# =====================================================================
$pg = New-ZPage 'fix'
$b1 = New-ZBtn 'Tam Tarama' $ZI.Play 'primary'
$b2 = New-ZBtn 'Seçili Sorunu Onar' $ZI.Repair 'secondary'
$b3 = New-ZBtn 'Güvenli Onarımları Uygula + Yeniden Tara' $ZI.Bolt 'purple'
$rpc = New-ZCheck 'Önemli onarımlardan önce geri yükleme noktası oluştur' $true; $UI.RestoreCheck = $rpc
$UI.FixScanBtn = $b1
$chips = @()
foreach ($fl in 'Tümü', 'KRİTİK', 'UYARI', 'BİLGİ') {
    $label = @{ 'Tümü' = 'Tümü'; 'KRİTİK' = 'Kritik'; 'UYARI' = 'Uyarı'; 'BİLGİ' = 'Bilgi' }[$fl]
    $cb = New-ZBtn ($label + '  0') '' 'chip' 96 30; $cb.Tag.Filter = $fl; $cb.Tag.Base = $label
    if ($fl -eq 'Tümü') { $cb.Tag.Active = $true }
    $cb.Add_Click({ $Script:Filter = $this.Tag.Filter; foreach ($x in $UI.Chips) { $x.Tag.Active = ($x.Tag.Filter -eq $Script:Filter); $x.Invalidate() }; Update-ZFixGrid })
    $chips += $cb
}
$UI.Chips = $chips
$fixBusy = New-ZBusyCard; $UI.FixBusy = $fixBusy
$baKpis = @((New-ZKpi 'Önceki tarama' $ZC.Muted '—' 'Kayıt yok'), (New-ZKpi 'Son tarama' $ZC.Accent '—' 'Kayıt yok'), (New-ZKpi 'Değişim (öncesi → sonrası)' $ZC.Green '—' 'İki tarama sonrası görünür'))
$UI.BA = $baKpis
$baRow = New-ZCols $baKpis @(33, 33, 34) 'Top' 100
$fixCard = New-ZCard 'Bulgular ve Öneriler' $ZI.Scan 'Fill'
$fixGrid = New-ZFindingsGrid; $fixCard.Controls.Add($fixGrid); $UI.FixGrid = $fixGrid; $UI.FixCard = $fixCard
Add-ZDock $pg @((New-ZBar @($b1, $b2, $b3, $rpc)), $fixBusy, $baRow, (New-ZSpacer 12), (New-ZBar $chips), $fixCard)
Set-ZFindings $fixGrid @((New-ZFinding 'BİLGİ' '—' 'Henüz tarama yapılmadı' '' '«Tam Tarama» ile donanım, sistem, sürücü, güvenlik ve kayıt defterini birlikte tarayın.'))

function Update-ZFixGrid {
    $list = @($Script:AllFindings)
    if ($Script:Filter -ne 'Tümü') { $list = @($list | Where-Object { $_.Severity -eq $Script:Filter }) }
    Set-ZFindings $UI.FixGrid $list
    $all = @($Script:AllFindings)
    Set-ZCardRight $UI.FixCard ('{0} bulgu  •  {1} tek tıkla onarılabilir' -f $all.Count, @($all | Where-Object { $_.FixId }).Count)
    foreach ($x in $UI.Chips) {
        $n = $all.Count; if ($x.Tag.Filter -ne 'Tümü') { $n = @($all | Where-Object { $_.Severity -eq $x.Tag.Filter }).Count }
        Set-ZBtnText $x ('{0}  {1}' -f $x.Tag.Base, $n)
    }
}

function Update-ZBeforeAfter {
    $h = @(Get-ZHistory)
    if ($h.Count -ge 1) { $c = $h[$h.Count - 1]; Set-ZKpi $UI.BA[1] ("{0}  ({1})" -f $c.Puan, $c.Derece) ("{0} • Kritik {1} • Uyarı {2}" -f $c.Tarih, $c.Kritik, $c.Uyari) }
    $cmp = Compare-ZHistory
    if ($cmp) {
        $p = $cmp.Previous
        Set-ZKpi $UI.BA[0] ("{0}  ({1})" -f $p.Puan, $p.Derece) ("{0} • Kritik {1} • Uyarı {2}" -f $p.Tarih, $p.Kritik, $p.Uyari)
        $d = ConvertTo-ZInt $cmp.Delta; $sign = ''; if ($d -gt 0) { $sign = '+' }
        $col = $ZC.Green; if ($d -lt 0) { $col = $ZC.Red } elseif ($d -eq 0) { $col = $ZC.Text2 }
        Set-ZKpi $UI.BA[2] ("{0}{1} puan" -f $sign, $d) ("Giderilen {0} • Yeni {1} sorun" -f @($cmp.Fixed).Count, @($cmp.New).Count) $col
    }
}

$b1.Add_Click({ Start-ZFullScan })
$b2.Add_Click({
        if ($fixGrid.SelectedRows.Count -eq 0) { Show-ZInfo 'Önce listeden bir sorun seçin.'; return }
        $fnd = $fixGrid.SelectedRows[0].Tag
        if (-not $fnd -or -not $fnd.FixId) { Show-ZInfo 'Bu bulgu için otomatik onarım yok. «Öneri» sütunundaki adımları uygulayın.'; return }
        Invoke-ZUIFix $fnd
    })
$Script:SafeFixes = @('RESTORE_POINT', 'TEMP_CLEAN', 'SERVICE_FIX', 'SERVICE_MANUAL', 'FIREWALL_ON', 'DEFENDER_UPDATE', 'PAGEFILE_AUTO', 'POWER_HIGH', 'WMI_REPAIR', 'DNS_FLUSH', 'DEVICE_RESCAN', 'PROXY_OFF')
$b3.Add_Click({
        if (-not $Script:LastScan) { Show-ZInfo 'Önce tam tarama yapın.'; return }
        $list = @($Script:AllFindings | Where-Object { $_.FixId -in $Script:SafeFixes } | Sort-Object FixId, FixData -Unique)
        if ($list.Count -eq 0) { Show-ZInfo 'Otomatik uygulanabilecek güvenli onarım bulunmadı. Diğer bulgular için satırdaki düğmeleri kullanın.'; return }
        $txt = ($list | ForEach-Object { '• ' + $_.Title }) -join "`n"
        if (-not (Confirm-Z ("Şu güvenli onarımlar uygulanacak ve ardından öncesi / sonrası karşılaştırması için yeniden tarama yapılacak:`n`n{0}`n`nDevam edilsin mi?" -f $txt))) { return }
        $items = @($list | ForEach-Object { @{ Id = $_.FixId; Data = $_.FixData } })
        $j = Start-ZJob 'Toplu Onarım + Yeniden Tarama' {
            if ($JobParams.RP) { [void](New-ZRestorePoint) }
            $n = 0; foreach ($it in $JobParams.Items) { $n++; Set-ZProgress ([int]($n / $JobParams.Items.Count * 50)) ("Onarım $n/" + $JobParams.Items.Count); [void](Invoke-ZFix $it.Id $it.Data) }
            Write-ZLog 'Onarımlar bitti. Öncesi / sonrası karşılaştırması için yeniden taranıyor...' 'OK'
            $r = Invoke-ZFullScan
            [pscustomobject]@{ R = $r }
        } @{ Items = $items; RP = $UI.RestoreCheck.Checked } $Script:OnScanDone @($b3, $b1, $btnScan)
        if ($j) { $UI.FixBusy.Tag.Text = 'Onarımlar uygulanıyor, ardından yeniden taranacak'; $UI.FixBusy.Visible = $true; $UI.FixBusy.Invalidate() }
    })

# =====================================================================
#  SAYFA: DONANIM
# =====================================================================
$pg = New-ZPage 'hw'
$h1 = New-ZBtn 'Donanımı Tara' $ZI.Play 'primary'
$h2 = New-ZBtn 'Bellek (RAM) Testi' $ZI.Diag
$h3 = New-ZBtn 'Pil Raporu' $ZI.Doc
$h4 = New-ZBtn 'Aygıtları Yeniden Tara' $ZI.Refresh
$h5 = New-ZBtn 'Aygıt Yöneticisi' $ZI.Settings
$diskCard = New-ZCard 'Disk Sağlığı (SMART)' $ZI.Save 'Top' 190
$diskGrid = New-ZGrid @('Disk:22', 'Tür:9', 'Bağlantı:9', 'Boyut:9', '@SEV:Sağlık:10', 'Sıcaklık:8', 'Aşınma:7', 'Okuma hatası:9', 'Yazma hatası:9', 'Çalışma:9'); $diskCard.Controls.Add($diskGrid)
$ramCard = New-ZCard 'Bellek Modülleri' $ZI.Hw 'Top' 170
$ramGrid = New-ZGrid @('Yuva:12', 'Banka:12', 'Kapasite:10', 'Üretici:14', 'Parça no:20', 'Nominal hız:12', 'Çalışan hız:12'); $ramCard.Controls.Add($ramGrid)
$hwCard = New-ZCard 'Donanım Bulguları' $ZI.Warn 'Fill'
$hwGrid = New-ZFindingsGrid; $hwCard.Controls.Add($hwGrid)
Add-ZDock $pg @((New-ZBar @($h1, $h2, $h3, $h4, $h5)), $diskCard, (New-ZSpacer 12), $ramCard, (New-ZSpacer 12), $hwCard)
$h1.Add_Click({
        [void](Start-ZJob 'Donanım Taraması' {
                $f = Test-ZHardware; $d = Get-ZDiskHealth; $m = Get-ZRamModules
                Write-ZLog 'Donanım taraması tamamlandı.' 'OK'
                [pscustomobject]@{ R = @($f); Disks = @($d); Ram = @($m) }
            } @{} {
                param($res)
                if (-not $res) { return }
                Set-ZFindings $hwGrid $res.R
                $diskGrid.Rows.Clear()
                foreach ($d in $res.Disks) {
                    $hs = 'İYİ'; if ($d.Saglik -match 'Warning') { $hs = 'UYARI' } elseif ($d.Saglik -match 'Unhealthy') { $hs = 'KRİTİK' }
                    [void](Add-ZRow $diskGrid @($d.Disk, $d.Tur, $d.Baglanti, $d.Boyut, $hs, $d.Sicaklik, $d.Asinma, $d.OkumaHata, $d.YazmaHata, $d.CalismaSaati))
                }
                $ramGrid.Rows.Clear()
                foreach ($m in $res.Ram) { [void](Add-ZRow $ramGrid @($m.Yuva, $m.Banka, $m.Kapasite, $m.Uretici, $m.ParcaNo, $m.NominalHiz, $m.CalisanHiz)) }
            } @($h1))
    })
$h2.Add_Click({ Invoke-ZUIFix (New-ZFinding 'BİLGİ' 'Donanım' 'Bellek testi' '' '' 'MEMDIAG') })
$h3.Add_Click({ Invoke-ZUIFix (New-ZFinding 'BİLGİ' 'Donanım' 'Pil raporu' '' '' 'BATTERY_REPORT') -NoConfirm })
$h4.Add_Click({ Invoke-ZUIFix (New-ZFinding 'BİLGİ' 'Donanım' 'Aygıt taraması' '' '' 'DEVICE_RESCAN') -NoConfirm })
$h5.Add_Click({ Start-Process 'devmgmt.msc' })

# =====================================================================
#  SAYFA: SİSTEM ARIZALARI
# =====================================================================
$pg = New-ZPage 'sys'
$s1 = New-ZBtn 'Arızaları Tara' $ZI.Play 'primary'
$sDays = New-ZCombo @('Son 7 gün', 'Son 30 gün', 'Son 90 gün') 1 130
$s4 = New-ZBtn 'SFC + DISM Onarımı' $ZI.Repair 'purple'
$s2 = New-ZBtn 'Olay Görüntüleyici' $ZI.List
$s3 = New-ZBtn 'Güvenilirlik İzleyicisi' $ZI.Chart
$crashCard = New-ZCard 'Mavi Ekran (BSOD) ve Ani Kapanma Geçmişi' $ZI.Warn 'Top' 230
$crashGrid = New-ZGrid @('Tarih:14', '@SEV:Tür:13', 'Kod:10', 'Açıklama ve çözüm:63') -Wrap; $crashCard.Controls.Add($crashGrid)
$sysCard = New-ZCard 'Sistem Arıza Bulguları' $ZI.Diag 'Fill'
$sysGrid = New-ZFindingsGrid; $sysCard.Controls.Add($sysGrid)
Add-ZDock $pg @((New-ZBar @($s1, $sDays, $s4, $s2, $s3)), $crashCard, (New-ZSpacer 12), $sysCard)
$s1.Add_Click({
        $days = @(7, 30, 90)[$sDays.SelectedIndex]
        [void](Start-ZJob 'Sistem Arıza Taraması' {
                $f = Test-ZSystemErrors $JobParams.Days; $c = Get-ZCrashHistory $JobParams.Days
                Write-ZLog 'Sistem arıza taraması tamamlandı.' 'OK'
                [pscustomobject]@{ R = @($f); Crash = @($c) }
            } @{ Days = $days } {
                param($res)
                if (-not $res) { return }
                Set-ZFindings $sysGrid $res.R
                $crashGrid.Rows.Clear()
                foreach ($c in @($res.Crash)) {
                    if (-not $c) { continue }
                    $code = ''; if ($c.Kod) { $code = ('0x{0:X}' -f [int64](ConvertTo-ZNum $c.Kod)) }
                    [void](Add-ZRow $crashGrid @($c.Tarih.ToString('dd.MM.yyyy HH:mm'), $c.Tur, $code, $c.Aciklama))
                }
                if ($crashGrid.Rows.Count -eq 0) { [void](Add-ZRow $crashGrid @('—', 'TEMİZ', '', 'Bu dönemde mavi ekran veya ani kapanma kaydı yok.')) }
                Set-ZCardRight $crashCard ('{0} kayıt' -f @($res.Crash | Where-Object { $_ }).Count)
            } @($s1))
    })
$s2.Add_Click({ Start-Process 'eventvwr.msc' })
$s3.Add_Click({ Start-Process 'perfmon.exe' '/rel' })
$s4.Add_Click({ Invoke-ZUIFix (New-ZFinding 'BİLGİ' 'Onarım' 'Sistem dosyaları' '' '' 'FULL_REPAIR') })

# =====================================================================
#  SAYFA: SÜRÜCÜ & BIOS
# =====================================================================
$pg = New-ZPage 'drv'
$v1 = New-ZBtn 'Sürücü ve BIOS Sürümlerini Tara' $ZI.Play 'primary'
$v2 = New-ZBtn 'Windows Updateʼi Yeniden Sorgula' $ZI.Down
$v3 = New-ZBtn 'İsteğe Bağlı Güncellemeler' $ZI.Settings
$v4 = New-ZBtn 'Aygıt Yöneticisi' $ZI.Hw
$biosCard = New-ZCard 'BIOS / Anakart' $ZI.Settings 'Fill'
$biosGrid = New-ZGrid @('Özellik:36', 'Değer:64') -NoHeader; $biosGrid.RowTemplate.Height = 27; $biosGrid.Columns[0].DefaultCellStyle.ForeColor = $ZC.Text2
$biosBtn = New-ZBtn 'Anakart Destek Sayfası (BIOS)' $ZI.Globe 'secondary' 0 32; $biosBtn.Dock = 'Bottom'; $biosBtn.Enabled = $false
$biosCard.Controls.Add($biosGrid); $biosCard.Controls.Add($biosBtn)
$gpuCard = New-ZCard 'Ekran Kartı Sürücüsü' $ZI.Game 'Fill'
$gpuGrid = New-ZGrid @('Özellik:36', 'Değer:64') -NoHeader; $gpuGrid.RowTemplate.Height = 27; $gpuGrid.Columns[0].DefaultCellStyle.ForeColor = $ZC.Text2
$gpuBtn = New-ZBtn 'Güncel Sürücüyü İndir' $ZI.Down 'primary' 0 32; $gpuBtn.Dock = 'Bottom'; $gpuBtn.Enabled = $false
$gpuCard.Controls.Add($gpuGrid); $gpuCard.Controls.Add($gpuBtn)
$drvTop = New-ZCols @($biosCard, $gpuCard) @(50, 50) 'Top' 310
$drvCard = New-ZCard 'Yüklü Sürücüler' $ZI.Driver 'Fill'
$drvGrid = New-ZGrid @('Kategori:11', 'Aygıt:30', 'Üretici:15', 'Sürüm:14', 'Tarih:10', 'Yaş:8', '@SEV:Durum:14', '@ACT:10'); $drvCard.Controls.Add($drvGrid)
$wuCard = New-ZCard 'Windows Updateʼte Bekleyen Sürücü Güncellemeleri' $ZI.Down 'Bottom' 160
$wuGrid = New-ZGrid @('Güncelleme:50', 'Üretici:18', 'Sınıf:14', 'Tarih:18'); $wuCard.Controls.Add($wuGrid)
[void](Add-ZRow $wuGrid @('«Sürücü ve BIOS Sürümlerini Tara» ile Windows Updateʼte bu bilgisayar için yayınlanmış gerçek sürücü güncellemeleri denetlenir.', '', '', ''))
[void](Add-ZRow $biosGrid @('Durum', '«Sürücü ve BIOS Sürümlerini Tara» düğmesine basın.'))
Add-ZDock $pg @((New-ZBar @($v1, $v2, $v3, $v4)), $drvTop, (New-ZSpacer 12), $drvCard, (New-ZSpacer 12), $wuCard)
$drvGrid.Add_CellClick({
        param($s, $e)
        if ($e.RowIndex -lt 0 -or $e.ColumnIndex -lt 0 -or $s.Columns[$e.ColumnIndex].Tag -ne 'ACT') { return }
        $d = $s.Rows[$e.RowIndex].Tag
        if ($d -and $d.Islem) { if ($d.Url -eq 'WU') { Start-Process 'ms-settings:windowsupdate-optionalupdates' } elseif ($d.Url) { Start-Process $d.Url } }
    })
$biosBtn.Add_Click({ if ($Script:BiosUrl) { Start-Process $Script:BiosUrl } })
$gpuBtn.Add_Click({ if ($Script:GpuUrl) { Start-Process $Script:GpuUrl } })
function Convert-ZNvidiaVersion { param([string]$V)
    $p = $V.Split('.'); if ($p.Count -lt 4) { return $V }
    $d = ($p[2] + $p[3]); if ($d.Length -lt 5) { return $V }
    $d = $d.Substring($d.Length - 5); '{0}.{1}' -f $d.Substring(0, 3), $d.Substring(3)
}
$v1.Add_Click({
        $j = Start-ZJob 'Sürücü ve BIOS Taraması' {
                $b = Get-ZBiosInfo; $u = $null; if ($JobParams.WU) { $u = Find-ZDriverUpdates -Force } else { $u = Find-ZDriverUpdates }
                $d = @(Get-ZDriverInventory $u)
                Write-ZLog ("{0} sürücü listelendi." -f $d.Count) 'OK'
                [pscustomobject]@{ R = $d; Bios = $b; WU = @($u | Where-Object { $_ }); WUOk = ($null -ne $u) }
            } @{ WU = [bool]$Script:DrvForceWU } {
                param($res)
                if (-not $res) { return }
                $b = $res.Bios
                if ($b) {
                    $Script:BiosUrl = $b.Url; $biosBtn.Enabled = $true
                    $biosGrid.Rows.Clear()
                    $age = '?'; if ($null -ne $b.BiosYas) { $age = ('{0:N1} yıl önce' -f ($b.BiosYas / 365)) }
                    foreach ($kv in @(@('Anakart', ("{0} {1}" -f $b.Uretici, $b.Model)), @('Sistem', $b.Sistem), @('BIOS sürümü', ("{0}  ({1})" -f $b.BiosSurum, $b.BiosUretici)), @('BIOS tarihi', ("{0}  •  {1}" -f $b.BiosTarih, $age)), @('SMBIOS', $b.SMBIOS), @('Secure Boot', $b.SecureBoot), @('TPM', $b.TPM))) { [void](Add-ZRow $biosGrid $kv) }
                }
                $Script:Drivers = @($res.R)
                $drvGrid.Rows.Clear()
                foreach ($d in $Script:Drivers) { [void](Add-ZRow $drvGrid @($d.Kategori, $d.Aygit, $d.Uretici, $d.Surum, $d.Tarih, $d.Yas, $d.Durum, $d.Islem) $d) }
                $nu = @($Script:Drivers | Where-Object { $_.Islem }).Count
                if ($nu) { Set-ZCardRight $drvCard ('{0} sürücü  •  {1} güncelleme mevcut' -f $Script:Drivers.Count, $nu) $ZC.Orange } else { Set-ZCardRight $drvCard ('{0} sürücü  •  tümü güncel' -f $Script:Drivers.Count) $ZC.Green }
                $wuGrid.Rows.Clear()
                foreach ($u in @($res.WU)) { if ($u) { [void](Add-ZRow $wuGrid @($u.Baslik, $u.Uretici, $u.Sinif, $u.Tarih)) } }
                if ($wuGrid.Rows.Count -eq 0) { if ($res.WUOk) { [void](Add-ZRow $wuGrid @('Windows Updateʼte bu bilgisayar için bekleyen sürücü güncellemesi yok.', '', '', '')) } else { [void](Add-ZRow $wuGrid @('Windows Updateʼe ulaşılamadı (internet / Windows Update hizmeti kapalı olabilir).', '', '', '')) } }
                else { Set-ZCardRight $wuCard ('{0} güncelleme — «Güncelle» ile İsteğe Bağlı Güncellemeler açılır' -f $wuGrid.Rows.Count) $ZC.Orange }
                $gpuGrid.Rows.Clear()
                $gp = @($Script:Drivers | Where-Object { $_.Kategori -eq 'Ekran Kartı' -and $_.Aygit -notmatch 'Basic|Temel|Virtual|Parsec|Meta|Remote' })
                foreach ($g in $gp) {
                    $ver = $g.Surum; if ($g.Aygit -match 'NVIDIA|GeForce') { $ver = ('{0}  (NVIDIA {1})' -f $g.Surum, (Convert-ZNvidiaVersion $g.Surum)) }
                    foreach ($kv in @(@('Ekran kartı', $g.Aygit), @('Sürücü sürümü', $ver), @('Sürücü tarihi', ("{0}  •  {1}" -f $g.Tarih, $g.Yas)), @('Durum', $g.Durum))) { [void](Add-ZRow $gpuGrid $kv) }
                    if ($g.Islem) { $Script:GpuUrl = $g.Url; if ($g.Url -eq 'WU') { $Script:GpuUrl = 'ms-settings:windowsupdate-optionalupdates' }; $gpuBtn.Enabled = $true; Set-ZBtnText $gpuBtn 'Güncel Sürücüyü İndir' } else { $gpuBtn.Enabled = $false; Set-ZBtnText $gpuBtn 'Sürücü güncel' }
                }
                if ($gp.Count -eq 0) { [void](Add-ZRow $gpuGrid @('Ekran kartı', 'Sürücü bulunamadı — Windows temel sürücüsü kullanılıyor olabilir.')) }
            } @($v1, $v2)
        $Script:DrvForceWU = $false
    })
$v2.Add_Click({ $Script:DrvForceWU = $true; $v1.PerformClick() })
$v3.Add_Click({ Start-Process 'ms-settings:windowsupdate-optionalupdates' })
$v4.Add_Click({ Start-Process 'devmgmt.msc' })

# =====================================================================
#  SAYFA: AĞ
# =====================================================================
$pg = New-ZPage 'net'
$n1 = New-ZBtn 'Ağ Testi' $ZI.Play 'primary'
$n2 = New-ZBtn 'DNS Önbelleği Temizle' $ZI.Refresh
$n3 = New-ZBtn 'Ağı Sıfırla' $ZI.Warn 'danger'
$n4 = New-ZBtn 'DNS: Cloudflare' $ZI.Globe
$n5 = New-ZBtn 'DNS: Otomatik' $ZI.Globe
$pingCard = New-ZCard 'Gecikme ve Paket Kaybı' $ZI.Net 'Top' 210
$pingGrid = New-ZGrid @('Hedef:26', 'Ortalama (ms):15', 'Jitter (ms):15', 'Kayıp %:12', 'Min:12', 'Max:12'); $pingCard.Controls.Add($pingGrid)
$netCard = New-ZCard 'Ağ Bulguları' $ZI.Diag 'Fill'
$netGrid = New-ZFindingsGrid; $netCard.Controls.Add($netGrid)
Add-ZDock $pg @((New-ZBar @($n1, $n2, $n3, $n4, $n5)), $pingCard, (New-ZSpacer 12), $netCard)
$n1.Add_Click({
        [void](Start-ZJob 'Ağ Testi' { $r = Test-ZNetwork; [pscustomobject]@{ R = $r } } @{} {
                param($res)
                if (-not $res -or -not $res.R) { return }
                Set-ZFindings $netGrid $res.R.Findings
                $pingGrid.Rows.Clear()
                foreach ($x in @($res.R.Rows)) { if ($x) { [void](Add-ZRow $pingGrid @($x.Hedef, $x.Ortalama, $x.Jitter, $x.Kayip, $x.Min, $x.Max)) } }
            } @($n1))
    })
$n2.Add_Click({ Invoke-ZUIFix (New-ZFinding 'BİLGİ' 'Ağ' 'DNS' '' '' 'DNS_FLUSH') -NoConfirm })
$n3.Add_Click({ Invoke-ZUIFix (New-ZFinding 'BİLGİ' 'Ağ' 'Ağ' '' '' 'NET_RESET') })
$n4.Add_Click({ Invoke-ZUIFix (New-ZFinding 'BİLGİ' 'Ağ' 'DNS' '' '' 'DNS_CLOUDFLARE') })
$n5.Add_Click({ Invoke-ZUIFix (New-ZFinding 'BİLGİ' 'Ağ' 'DNS otomatik' '' '' 'DNS_AUTO') })

# =====================================================================
#  SAYFA: FPS & OYUNLAR
# =====================================================================
$pg = New-ZPage 'fps'
$fRes = New-ZCombo @('1080p', '1440p', '4K') 0 100
$fQ = New-ZCombo @('Düşük', 'Orta', 'Yüksek', 'Ultra') 2 110
$fCalc = New-ZBtn 'FPS Tahmini Hesapla' $ZI.Game 'primary'
$fAdd = New-ZBtn 'Oyun Ekle' $ZI.Check 'success'
$fDel = New-ZBtn 'Seçili Oyunu Sil' $ZI.Clean 'secondary'
$fNote = New-ZLabel '' $ZF.Small $ZC.Text2 'None' 0
$fNote.Margin = New-Object System.Windows.Forms.Padding(6, 11, 0, 0)
$estCard = New-ZCard 'Bu Sistemde Oyunlarda Tahmini FPS' $ZI.Game 'Fill'
$estGrid = New-ZGrid @('Oyun:30', 'Tahmini FPS:15', 'Aralık:14', 'Sınırlayan:21', '@SEV:Değerlendirme:20'); $estCard.Controls.Add($estGrid)
$estNote = New-ZLabel 'Tahminler donanım sınıfına göre hesaplanır; yama, sürücü ve sahneye göre ±%15 değişebilir. Kesin değer için gerçek ölçümü kullanın.' $ZF.Small $ZC.Muted 'Bottom' 34 'MiddleLeft'
$estNote.BackColor = $ZC.Surf; $estCard.Controls.Add($estNote)
$measCard = New-ZCard 'Gerçek FPS Ölçümü — Öncesi / Sonrası' $ZI.Gauge 'Fill'
$mHelp = New-ZLabel "1) Oyunu açın, listeden seçin   2) ÖNCE ölçün   3) Onarım / temizlik / optimizasyon uygulayın   4) Aynı sahnede SONRA ölçün" $ZF.Small $ZC.Text2 'Top' 40 'TopLeft'
$procRow = New-ZPanel 'Top' 34 $ZC.Surf 0
$procCombo = New-Object System.Windows.Forms.ComboBox; $procCombo.DropDownStyle = 'DropDown'; $procCombo.FlatStyle = 'Flat'; $procCombo.BackColor = $ZC.Surf2; $procCombo.ForeColor = $ZC.Text; $procCombo.Font = $ZF.Body; $procCombo.Dock = 'Fill'
$procRefresh = New-ZBtn 'Yenile' $ZI.Refresh 'secondary' 96 32; $procRefresh.Dock = 'Right'
$procGap = New-ZPanel 'Right' 0 $ZC.Surf 0; $procGap.Width = 8
Add-ZDock $procRow @($procCombo, $procGap, $procRefresh)
$durRow = New-Object System.Windows.Forms.FlowLayoutPanel; $durRow.Dock = 'Top'; $durRow.Height = 50; $durRow.BackColor = $ZC.Surf; $durRow.Padding = New-Object System.Windows.Forms.Padding(0, 8, 0, 0)
$mDur = New-ZCombo @('30 saniye', '60 saniye', '90 saniye') 0 110
$mBefore = New-ZBtn 'ÖNCE Ölç' $ZI.Play 'secondary'
$mAfter = New-ZBtn 'SONRA Ölç' $ZI.Play 'success'
$mOnce = New-ZBtn 'Tek Ölçüm' $ZI.Gauge 'ghost'
$durRow.Controls.AddRange(@($mDur, $mBefore, $mAfter, $mOnce))
$fpsK = @((New-ZKpi 'Ortalama FPS' $ZC.Accent '—' ''), (New-ZKpi '%1 Low' $ZC.Purple '—' ''), (New-ZKpi '%0.1 Low' $ZC.Orange '—' ''))
$fpsRow = New-ZCols $fpsK @(34, 33, 33) 'Top' 96 8; $fpsRow.BackColor = $ZC.Surf
$cmpLabel = New-ZLabel 'Öncesi / sonrası karşılaştırması için aynı oyunda ÖNCE ve SONRA ölçümü yapın.' $ZF.Bold $ZC.Text2 'Top' 54 'MiddleLeft'
$cmpLabel.BackColor = $ZC.Surf; $mHelp.BackColor = $ZC.Surf
$fhGrid = New-ZGrid @('Tarih:20', 'Oyun:24', '@SEV:Etiket:14', 'Ort. FPS:14', '%1 Low:14', '%0.1 Low:14')
Add-ZDock $measCard @($mHelp, $procRow, $durRow, $fpsRow, $cmpLabel, $fhGrid)
$fpsCols = New-ZCols @($estCard, $measCard) @(52, 48) 'Fill'
Add-ZDock $pg @((New-ZBar @($fRes, $fQ, $fCalc, $fAdd, $fDel, $fNote)), $fpsCols)

function Update-ZFpsEstimate {
    $st = $Script:StaticBN
    if (-not $st) { return }
    $ramF = 1.0
    if ($Script:SysInfo) { if ($Script:SysInfo.RamModules -eq 1) { $ramF = 0.85 }; if ($Script:SysInfo.RamBytes -lt 16GB) { $ramF *= 0.9 } }
    $est = Get-ZFpsEstimate $st.CpuScore $st.GpuScore "$($fRes.SelectedItem)" "$($fQ.SelectedItem)" $ramF
    $estGrid.Rows.Clear()
    foreach ($e in $est) { $nm = $e.Oyun; if ($e.Ozel) { $nm = $e.Oyun + '   ★ eklenen' }; [void](Add-ZRow $estGrid @($nm, ("{0} FPS" -f $e.Fps), $e.Aralik, $e.Sinirlayan, $e.Degerlendirme) $e) }
    $hz = ''; if ($Script:Display) { $hz = ('   •   Ekran {0}×{1} @ {2} Hz' -f $Script:Display.Width, $Script:Display.Height, $Script:Display.Hz) }
    Set-ZCardRight $estCard ('{0} / {1} ayar' -f $fRes.SelectedItem, $fQ.SelectedItem)
    $fNote.Text = ('İşlemci puanı {0}   •   Ekran kartı puanı {1}{2}' -f $st.CpuScore, $st.GpuScore, $hz)
}
function Update-ZFpsProcs {
    $procCombo.Items.Clear()
    $Script:GameProcs = @(Get-ZGameCandidates)
    foreach ($p in $Script:GameProcs) { [void]$procCombo.Items.Add($p.Text) }
    if ($procCombo.Items.Count) { $procCombo.SelectedIndex = 0 } else { $procCombo.Text = 'oyun.exe — oyunu açıp Yenileʼye basın' }
}
function Get-ZSelectedProc {
    $i = $procCombo.SelectedIndex
    if ($i -ge 0 -and $i -lt @($Script:GameProcs).Count) { return $Script:GameProcs[$i].Name }
    $t = "$($procCombo.Text)".Trim(); if ($t -match '^([\w\.\-]+?\.exe)') { return $Matches[1] }
    $null
}
function Update-ZFpsHistoryUI {
    $fhGrid.Rows.Clear()
    $h = @(Get-ZFpsHistory)
    for ($i = $h.Count - 1; $i -ge 0 -and $i -ge $h.Count - 30; $i--) { $x = $h[$i]; [void](Add-ZRow $fhGrid @($x.Tarih, $x.Oyun, $x.Etiket, $x.OrtFps, $x.Low1, $x.Low01)) }
    $game = Get-ZSelectedProc
    if ($game) {
        $c = Compare-ZFps $game
        if ($c) {
            $sign = ''; if ($c.DeltaAvg -gt 0) { $sign = '+' }
            $cmpLabel.Text = ("{0}:   ÖNCE {1} FPS  →  SONRA {2} FPS   ({3}{4}%)`n%1 Low: {5} → {6}" -f $game, $c.Before.OrtFps, $c.After.OrtFps, $sign, $c.DeltaAvg, $c.Before.Low1, $c.After.Low1)
            $cmpLabel.ForeColor = $(if ($c.DeltaAvg -ge 0) { $ZC.Green } else { $ZC.Red })
        }
    }
}
function Start-ZFpsMeasure { param([string]$Label)
    $game = Get-ZSelectedProc
    if (-not $game) { Show-ZInfo 'Önce oyunu açın, «Yenile»ye basın ve listeden seçin.'; return }
    $sec = @(30, 60, 90)[$mDur.SelectedIndex]
    if (-not (Test-Path $Global:ZPresentMon)) {
        if (-not (Confirm-Z ("Gerçek FPS ölçümü için Intel PresentMon (açık kaynak) bir kez indirilecek:`n{0}`n`nİndirilsin mi?" -f $Global:ZPresentMonUrl))) { return }
    }
    Show-ZInfo ("{0} ölçümü 5 saniye sonra başlayacak ve {1} saniye sürecek.`nTamamʼa basıp hemen oyuna geçin ve normal oynayın." -f $Label, $sec)
    [void](Start-ZJob ('FPS Ölçümü (' + $Label + ')') {
            Write-ZLog '5 saniye içinde oyuna geçin...'; Start-Sleep -Seconds 5
            $r = Measure-ZFps $JobParams.Game $JobParams.Sec $JobParams.Label
            [pscustomobject]@{ R = $r }
        } @{ Game = $game; Sec = $sec; Label = $Label } {
            param($res)
            try { $form.Activate() } catch {}
            if (-not $res -or -not $res.R) { Show-ZInfo 'FPS ölçümü yapılamadı. Oyunun açık olduğundan ve ekranda çalıştığından emin olun. Ayrıntılar İşlem Günlüğüʼnde.' 'Warning'; return }
            $r = $res.R
            Set-ZKpi $fpsK[0] $r.OrtFps ("{0} kare • {1} ms" -f $r.Kare, $r.OrtMs); Set-ZKpi $fpsK[1] $r.Low1 'en yavaş %1 kare'; Set-ZKpi $fpsK[2] $r.Low01 'takılma göstergesi'
            Update-ZFpsHistoryUI
        } @($mBefore, $mAfter, $mOnce))
}
function Show-ZAddGame {
    $st = $Script:StaticBN
    $f = New-Object System.Windows.Forms.Form
    $f.SuspendLayout()
    $f.AutoScaleDimensions = New-Object System.Drawing.SizeF(96, 96); $f.AutoScaleMode = 'Dpi'
    $f.Text = 'Oyun Ekle — Tahmini FPS'; $f.ClientSize = New-Object System.Drawing.Size(560, 470); $f.StartPosition = 'CenterParent'
    $f.FormBorderStyle = 'FixedDialog'; $f.MaximizeBox = $false; $f.MinimizeBox = $false; $f.BackColor = $ZC.Bg; $f.ForeColor = $ZC.Text; $f.Font = $ZF.Body
    if ($Script:AppIcon) { $f.Icon = $Script:AppIcon }
    $wrap = New-ZPanel 'Fill' 0 $ZC.Bg 0; $wrap.Padding = New-Object System.Windows.Forms.Padding(28, 22, 28, 18)
    $h = New-ZLabel 'Yeni Oyun Ekle' $ZF.H1 $ZC.Text 'Top' 34
    $sub = New-ZLabel 'Oyunun ağırlığını seçin. Bu sistemde aldığınız FPSʼi biliyorsanız girin; tahmin o değere göre ayarlanır.' $ZF.Small $ZC.Text2 'Top' 36 'TopLeft'
    $l1 = New-ZLabel 'OYUN ADI' $ZF.Tiny $ZC.Muted 'Top' 26 'BottomLeft'
    $tName = New-Object System.Windows.Forms.TextBox; $tName.Dock = 'Top'; $tName.Font = $ZF.H3; $tName.BackColor = $ZC.Surf; $tName.ForeColor = $ZC.Text; $tName.BorderStyle = 'FixedSingle'
    $l2 = New-ZLabel 'OYUNUN AĞIRLIĞI (GRAFİK YÜKÜ)' $ZF.Tiny $ZC.Muted 'Top' 30 'BottomLeft'
    $cProf = New-Object System.Windows.Forms.ComboBox; $cProf.Dock = 'Top'; $cProf.DropDownStyle = 'DropDownList'; $cProf.FlatStyle = 'Flat'; $cProf.BackColor = $ZC.Surf2; $cProf.ForeColor = $ZC.Text; $cProf.Font = $ZF.Bold
    foreach ($k in $Global:ZGameProfiles.Keys) { [void]$cProf.Items.Add($k) }; $cProf.SelectedIndex = 2
    $l3 = New-ZLabel 'BU SİSTEMDE ÖLÇTÜĞÜM FPS (İSTEĞE BAĞLI — 0 = BİLMİYORUM)' $ZF.Tiny $ZC.Muted 'Top' 30 'BottomLeft'
    $mRow = New-Object System.Windows.Forms.FlowLayoutPanel; $mRow.Dock = 'Top'; $mRow.Height = 40; $mRow.BackColor = $ZC.Bg
    $nFps = New-Object System.Windows.Forms.NumericUpDown; $nFps.Minimum = 0; $nFps.Maximum = 2000; $nFps.Width = 110; $nFps.Font = $ZF.Bold; $nFps.BackColor = $ZC.Surf; $nFps.ForeColor = $ZC.Text; $nFps.Margin = New-Object System.Windows.Forms.Padding(0, 4, 10, 0)
    $mRes = New-ZCombo @('1080p', '1440p', '4K') 0 100; $mQ = New-ZCombo @('Düşük', 'Orta', 'Yüksek', 'Ultra') 2 110
    if ($fRes.SelectedIndex -ge 0) { $mRes.SelectedIndex = $fRes.SelectedIndex }
    $mRow.Controls.AddRange(@($nFps, $mRes, $mQ))
    $l4 = New-ZLabel 'FPS KİLİDİ (İSTEĞE BAĞLI — 0 = YOK)' $ZF.Tiny $ZC.Muted 'Top' 30 'BottomLeft'
    $nCap = New-Object System.Windows.Forms.NumericUpDown; $nCap.Minimum = 0; $nCap.Maximum = 1000; $nCap.Width = 110; $nCap.Font = $ZF.Bold; $nCap.BackColor = $ZC.Surf; $nCap.ForeColor = $ZC.Text; $nCap.Dock = 'Left'
    $capRow = New-ZPanel 'Top' 32 $ZC.Bg 0; $capRow.Controls.Add($nCap)
    $msg = New-ZLabel '' $ZF.Bold $ZC.Red 'Top' 30
    $bRow = New-Object System.Windows.Forms.FlowLayoutPanel; $bRow.Dock = 'Top'; $bRow.Height = 44; $bRow.BackColor = $ZC.Bg
    $ok = New-ZBtn 'Kaydet' $ZI.Check 'primary' 130 36; $cancel = New-ZBtn 'İptal' '' 'ghost' 90 36
    $bRow.Controls.AddRange(@($ok, $cancel))
    $cancel.Add_Click({ $f.Close() })
    $ok.Add_Click({
            $name = "$($tName.Text)".Trim()
            if (-not $name) { $msg.Text = 'Oyun adını yazın.'; return }
            $all = @(Get-ZCustomGames)
            if ($all | Where-Object { $_.Ad -eq $name }) { $msg.Text = 'Bu isimde bir oyun zaten eklenmiş.'; return }
            if (@($Global:ZGames | Where-Object { $_.Ad -eq $name }).Count) { $msg.Text = 'Bu oyun listede zaten var.'; return }
            $cs = 60; $gs = 50; if ($st) { $cs = $st.CpuScore; $gs = $st.GpuScore }
            $ramF = 1.0; if ($Script:SysInfo) { if ($Script:SysInfo.RamModules -eq 1) { $ramF = 0.85 }; if ($Script:SysInfo.RamBytes -lt 16GB) { $ramF *= 0.9 } }
            $ng = New-ZCustomGame $name "$($cProf.SelectedItem)" ([double]$nFps.Value) "$($mRes.SelectedItem)" "$($mQ.SelectedItem)" ([int]$nCap.Value) $cs $gs $ramF
            try { Save-ZCustomGames (@($all) + @($ng)) } catch { $msg.Text = 'Kaydedilemedi: ' + $_.Exception.Message; return }
            $f.Tag = $ng; $f.Close()
        })
    Add-ZDock $wrap @($h, $sub, $l1, $tName, $l2, $cProf, $l3, $mRow, $l4, $capRow, $msg, $bRow)
    $f.Controls.Add($wrap)
    $f.ResumeLayout($false); $f.PerformLayout()
    [void]$f.ShowDialog($form)
    $f.Tag
}
$fAdd.Add_Click({
        $g = Show-ZAddGame
        if ($g) { Update-ZFpsEstimate; Write-ZActivity ('Oyun eklendi: {0} ({1})' -f $g.Ad, $g.Not) }
    })
$fDel.Add_Click({
        if ($estGrid.SelectedRows.Count -eq 0) { Show-ZInfo 'Silmek için listeden eklediğiniz bir oyunu seçin.'; return }
        $e = $estGrid.SelectedRows[0].Tag
        if (-not $e -or -not $e.Ozel) { Show-ZInfo 'Yalnızca sonradan eklediğiniz oyunlar (★ eklenen) silinebilir.'; return }
        if (-not (Confirm-Z ('«{0}» listeden silinsin mi?' -f $e.Oyun))) { return }
        Save-ZCustomGames @(Get-ZCustomGames | Where-Object { $_.Ad -ne $e.Oyun })
        Update-ZFpsEstimate
    })
$fCalc.Add_Click({ if (-not $Script:StaticBN) { $d1.PerformClick() } else { Update-ZFpsEstimate } })
$fRes.Add_SelectedIndexChanged({ Update-ZFpsEstimate })
$fQ.Add_SelectedIndexChanged({ Update-ZFpsEstimate })
$procRefresh.Add_Click({ Update-ZFpsProcs; Update-ZFpsHistoryUI })
$procCombo.Add_SelectedIndexChanged({ Update-ZFpsHistoryUI })
$mBefore.Add_Click({ Start-ZFpsMeasure 'ÖNCE' })
$mAfter.Add_Click({ Start-ZFpsMeasure 'SONRA' })
$mOnce.Add_Click({ Start-ZFpsMeasure 'ÖLÇÜM' })

# =====================================================================
#  SAYFA: DARBOĞAZ
# =====================================================================
$pg = New-ZPage 'bott'
$d1 = New-ZBtn 'Donanım Dengesi Analizi' $ZI.Play 'primary'
$dDur = New-ZCombo @('30 saniye', '60 saniye', '120 saniye', '300 saniye') 1 120
$d2 = New-ZBtn 'Oyun İçi Canlı Ölçüm' $ZI.Gauge 'purple'
$d3 = New-ZBtn 'Durdur' $ZI.Stop
$stCard = New-ZCard 'Donanım Dengesi (İşlemci ↔ Ekran Kartı)' $ZI.Bolt 'Top' 252
$cpuBar = New-ZScoreBar 'İşlemci' $ZC.Accent; $gpuBar = New-ZScoreBar 'Ekran kartı' $ZC.Purple
$verdict = New-ZLabel '«Donanım Dengesi Analizi» ile işlemci ve ekran kartınızın uyumunu görün.' $ZF.Bold $ZC.Text 'Top' 30
$notes = New-ZLabel '' $ZF.Small $ZC.Orange 'Top' 44 'TopLeft'
foreach ($x in $verdict, $notes) { $x.BackColor = $ZC.Surf }
Add-ZDock $stCard @($cpuBar, $gpuBar, $verdict, $notes)
$lvCard = New-ZCard 'Canlı Kullanım (oyun içi)' $ZI.Chart 'Fill'
$graph = New-ZGraph 200 'Fill'
$graph.Tag.Series = @(
    @{ Name = 'CPU (en yüklü çekirdek)'; Color = $ZC.Accent; Data = New-Object System.Collections.ArrayList },
    @{ Name = 'GPU'; Color = $ZC.Purple; Data = New-Object System.Collections.ArrayList },
    @{ Name = 'RAM'; Color = $ZC.Green; Data = New-Object System.Collections.ArrayList },
    @{ Name = 'Disk'; Color = $ZC.Orange; Data = New-Object System.Collections.ArrayList },
    @{ Name = 'VRAM'; Color = $ZC.Red; Data = New-Object System.Collections.ArrayList })
$graph.Tag.Points = 90
$liveRes = New-ZLabel 'Oyunu açın, «Oyun İçi Canlı Ölçüm»e basıp oyuna dönün. Süre sonunda darboğaz sonucu burada görünür.' $ZF.Bold $ZC.Text2 'Bottom' 72 'MiddleLeft'
$liveRes.BackColor = $ZC.Surf
Add-ZDock $lvCard @($graph, $liveRes)
Add-ZDock $pg @((New-ZBar @($d1, $dDur, $d2, $d3)), $stCard, (New-ZSpacer 12), $lvCard)
$Script:LiveJob = $null
$Script:OnStatic = {
    param($res)
    if (-not $res -or -not $res.R) { return }
    $s = $res.R; $Script:StaticBN = $s
    Set-ZScoreBar $cpuBar $s.CpuScore ("{0}  —  {1}/100" -f $s.CpuName, $s.CpuScore)
    Set-ZScoreBar $gpuBar $s.GpuScore ("{0}  —  {1}/100" -f $s.GpuName, $s.GpuScore)
    $verdict.Text = $s.Verdict; $verdict.ForeColor = $(if ($s.Verdict -match 'DENGELİ') { $ZC.Green } else { $ZC.Orange })
    $notes.Text = ((@($s.Notes) | ForEach-Object { '•  ' + $_ }) -join "`n")
    Update-ZFpsEstimate
}
$d1.Add_Click({ [void](Start-ZJob 'Darboğaz Analizi' { $r = Get-ZStaticBottleneck; [pscustomobject]@{ R = $r } } @{} $Script:OnStatic @($d1)) })
$d2.Add_Click({
        $sec = @(30, 60, 120, 300)[$dDur.SelectedIndex]
        foreach ($sr in $graph.Tag.Series) { $sr.Data.Clear() }
        $graph.Tag.Points = [int]($sec / 0.9)
        $liveRes.Text = ('Ölçüm sürüyor ({0} sn) — şimdi oyuna geçin.' -f $sec); $liveRes.ForeColor = $ZC.AccentHi
        $Script:LiveJob = Start-ZJob 'Canlı Darboğaz Ölçümü' { $r = Invoke-ZLiveBottleneck $JobParams.Sec; [pscustomobject]@{ R = $r } } @{ Sec = $sec } {
            param($res)
            $Script:LiveJob = $null
            if (-not $res -or -not $res.R) { $liveRes.Text = 'Ölçüm tamamlanamadı.'; return }
            $r = $res.R
            $liveRes.Text = ("{0}`nOrt. CPU %{1} (en yüklü çekirdek %{2}) • GPU %{3} • RAM %{4} • Disk %{5} • VRAM %{6}`n{7}" -f $r.Verdict, $r.Cpu, $r.CpuMax, $r.Gpu, $r.Ram, $r.Disk, $r.Vram, $r.Advice)
            $liveRes.ForeColor = $(switch ($r.Type) { 'GPU' { $ZC.Green } 'OK' { $ZC.Green } 'LIMIT' { $ZC.Blue } default { $ZC.Orange } })
            $liveRes.Height = 92
        } @($d2)
    })
$d3.Add_Click({ if ($Script:LiveJob) { $Script:LiveJob.Sync.Cancel = $true } })

# =====================================================================
#  SAYFA: SİSTEM PUANI
# =====================================================================
$pg = New-ZPage 'score'
$c1 = New-ZBtn 'Puanı Hesapla (Tam Tarama)' $ZI.Play 'primary'
$c2 = New-ZBtn 'WinSAT Performans Testi' $ZI.Star 'purple'
$UI.ScoreScanBtn = $c1
$ring2 = New-ZRing; $UI.ScoreRing2 = $ring2
$sbCard = New-ZCard 'Puan Dağılımı' $ZI.Chart 'Fill'
$sbO = New-ZScoreBar 'ZETX genel puanı' $ZC.Accent; $sbH = New-ZScoreBar 'Sistem sağlığı (arızalar, güvenlik, bütünlük)' $ZC.Green; $sbP = New-ZScoreBar 'Performans (WinSAT / donanım sınıfı)' $ZC.Purple
$gradeInfo = New-ZLabel 'Derece:  S ≥ 90   •   A ≥ 80   •   B ≥ 65   •   C ≥ 50   •   D < 50' $ZF.Small $ZC.Muted 'Top' 30; $gradeInfo.BackColor = $ZC.Surf
Add-ZDock $sbCard @($sbO, $sbH, $sbP, $gradeInfo)
$UI.ScoreBars = @{ Overall = $sbO; Health = $sbH; Perf = $sbP }
$scTop = New-ZCols @($ring2, $sbCard) @(-260, 100) 'Top' 236
$wsCard = New-ZCard 'Windows Deneyim Puanları (WinSAT, 1.0 – 9.9)' $ZI.Star 'Fill'
$wsCpu = New-ZScoreBar 'İşlemci hesaplama gücü' $ZC.Accent 9.9; $wsRam = New-ZScoreBar 'Bellek (RAM) hızı' $ZC.Green 9.9; $wsGfx = New-ZScoreBar 'Masaüstü grafik' $ZC.Blue 9.9
$wsD3d = New-ZScoreBar 'Oyun grafiği (Direct3D)' $ZC.Purple 9.9; $wsDisk = New-ZScoreBar 'Disk aktarım hızı' $ZC.Orange 9.9
Add-ZDock $wsCard @($wsCpu, $wsRam, $wsGfx, $wsD3d, $wsDisk)
Add-ZDock $pg @((New-ZBar @($c1, $c2)), $scTop, (New-ZSpacer 12), $wsCard)
function Set-ZWinSatUI { param($w)
    if (-not $w) { foreach ($b in $wsCpu, $wsRam, $wsGfx, $wsD3d, $wsDisk) { Set-ZScoreBar $b 0 'test yapılmadı' }; return }
    Set-ZScoreBar $wsCpu $w.Cpu ('{0:N1}' -f $w.Cpu); Set-ZScoreBar $wsRam $w.Ram ('{0:N1}' -f $w.Ram); Set-ZScoreBar $wsGfx $w.Graphics ('{0:N1}' -f $w.Graphics)
    Set-ZScoreBar $wsD3d $w.D3D ('{0:N1}' -f $w.D3D); Set-ZScoreBar $wsDisk $w.Disk ('{0:N1}' -f $w.Disk)
}
$c1.Add_Click({ Start-ZFullScan })
$c2.Add_Click({
        if (-not (Confirm-Z 'WinSAT testi 1–3 dakika sürer ve bu sürede bilgisayar yavaşlar. Diğer programları kapatın. Başlatılsın mı?')) { return }
        [void](Start-ZJob 'WinSAT Testi' { $w = Invoke-ZWinSat; [pscustomobject]@{ R = $w } } @{} { param($res) if ($res) { Set-ZWinSatUI $res.R } } @($c2))
    })

# =====================================================================
#  SAYFA: DOSYA ONARIMI
# =====================================================================
$pg = New-ZPage 'repair'
$tiles = New-Object System.Windows.Forms.FlowLayoutPanel; $tiles.Dock = 'Fill'; $tiles.AutoScroll = $true; $tiles.BackColor = $ZC.Bg
$repairList = @(
    @('FULL_REPAIR', 'Tam Onarım', 'Geri yükleme noktası + DISM + SFC + CHKDSK sırayla ve otomatik.', 'purple', $ZI.Repair),
    @('SFC', 'SFC /scannow', 'Bozuk veya değiştirilmiş Windows sistem dosyalarını bulur ve onarır.', 'primary', $ZI.Shield),
    @('DISM_CHECK', 'DISM Hızlı Kontrol', 'Windows görüntüsünde bozulma işareti olup olmadığını saniyeler içinde kontrol eder.', 'secondary', $ZI.Diag),
    @('DISM_SCAN', 'DISM Derin Tarama', 'Bileşen deposunu ayrıntılı tarar (5–15 dk).', 'secondary', $ZI.Scan),
    @('DISM_RESTORE', 'DISM Onarım', 'Bozuk Windows bileşenlerini Windows Update üzerinden indirip onarır.', 'primary', $ZI.Down),
    @('CHKDSK_SCAN', 'CHKDSK Tarama', 'Sistem diskindeki dosya sistemi hatalarını çevrimiçi tarar.', 'secondary', $ZI.Save),
    @('CHKDSK_SCHEDULE', 'CHKDSK /F /R', 'Bozuk sektörleri ve dosya sistemini yeniden başlatmada onarır.', 'danger', $ZI.Warn),
    @('WU_RESET', 'Windows Update Sıfırla', 'Takılan / hata veren güncellemeler için bileşenleri sıfırlar.', 'secondary', $ZI.Refresh),
    @('WMI_REPAIR', 'WMI Onarımı', 'Bozuk WMI deposunu doğrular ve kurtarır.', 'secondary', $ZI.Settings),
    @('DISM_CLEANUP', 'Bileşen Temizliği', 'Eski güncelleme bileşenlerini kaldırıp yer açar.', 'secondary', $ZI.Clean),
    @('ICON_CACHE', 'Simge Önbelleği', 'Bozuk / boş görünen simgeleri düzeltir.', 'secondary', $ZI.Home),
    @('STORE_RESET', 'Store Sıfırla', 'Microsoft Store açılmama / indirme sorunlarını giderir.', 'secondary', $ZI.Down),
    @('SPOOLER_RESET', 'Yazıcı Kuyruğu', 'Takılan yazdırma işlerini temizler.', 'secondary', $ZI.Doc),
    @('AUDIO_RESET', 'Ses Onarımı', 'Ses gelmemesi durumunda ses hizmetlerini yeniden başlatır.', 'secondary', $ZI.Settings),
    @('EXPLORER_RESTART', 'Gezgini Yenile', 'Görev çubuğu / masaüstü donmasını giderir.', 'secondary', $ZI.Refresh),
    @('TIME_SYNC', 'Saat Eşitle', 'Yanlış saat kaynaklı sertifika ve oturum hatalarını giderir.', 'secondary', $ZI.Clock),
    @('RESTORE_POINT', 'Geri Yükleme Noktası', 'Değişikliklerden önce sistem geri yükleme noktası oluşturur.', 'success', $ZI.Restore)
)
foreach ($r in $repairList) {
    $card = New-Object System.Windows.Forms.Panel; $card.Width = 300; $card.Height = 150; $card.BackColor = $ZC.Surf; $card.Margin = New-Object System.Windows.Forms.Padding(0, 0, 12, 12)
    $card.Padding = New-Object System.Windows.Forms.Padding(16, 16, 16, 14); $card.Tag = @{ Title = $r[1]; Desc = $r[2]; Icon = $r[4] }
    Set-ZDB $card
    $card.Add_Paint({
            param($s, $e) try {
            $g = $e.Graphics; $t = $s.Tag; $g.SmoothingMode = 'AntiAlias'
            $pn = New-Object System.Drawing.Pen($ZC.Border, 1); $g.DrawRectangle($pn, 0, 0, $s.Width - 1, $s.Height - 1); $pn.Dispose()
            $p = Get-ZRoundPath 16 16 34 34 8; $b = New-Object System.Drawing.SolidBrush($ZC.AccentDim); $g.FillPath($b, $p); $b.Dispose(); $p.Dispose()
            [System.Windows.Forms.TextRenderer]::DrawText($g, $t.Icon, $ZF.IconM, (New-Object System.Drawing.Rectangle(16, 16, 34, 34)), $ZC.AccentHi, [System.Windows.Forms.TextFormatFlags]'HorizontalCenter, VerticalCenter, SingleLine, NoPadding')
            [System.Windows.Forms.TextRenderer]::DrawText($g, $t.Title, $ZF.H3, (New-Object System.Drawing.Rectangle(62, 22, ($s.Width - 78), 22)), $ZC.Text, [System.Windows.Forms.TextFormatFlags]'Left, SingleLine, NoPadding, EndEllipsis')
            [System.Windows.Forms.TextRenderer]::DrawText($g, $t.Desc, $ZF.Small, (New-Object System.Drawing.Rectangle(16, 60, ($s.Width - 32), 40)), $ZC.Text2, [System.Windows.Forms.TextFormatFlags]'Left, WordBreak, NoPadding, EndEllipsis')
         } catch { } })
    $bb = New-ZBtn 'Çalıştır' $ZI.Play $r[3] 0 32; $bb.Dock = 'Bottom'; $bb.Tag.Fix = $r[0]
    $bb.Add_Click({ Invoke-ZUIFix (New-ZFinding 'BİLGİ' 'Onarım' (Get-ZFixTitle $this.Tag.Fix) '' '' $this.Tag.Fix) })
    $card.Controls.Add($bb)
    $tiles.Controls.Add($card)
}
$repNote = New-ZLabel 'İpucu: Mavi ekran, donma veya açılmayan programlarda önerilen sıra: DISM Onarım → SFC → CHKDSK. Tüm işlemler arka planda çalışır; ilerlemeyi sağ üstten ve İşlem Günlüğüʼnden izleyin.' $ZF.Small $ZC.Text2 'Top' 32
Add-ZDock $pg @($repNote, $tiles)

# =====================================================================
#  SAYFA: KAYIT DEFTERİ
# =====================================================================
$pg = New-ZPage 'reg'
$r1 = New-ZBtn 'Kayıt Defterini Tara' $ZI.Play 'primary'
$r2 = New-ZBtn 'Seçilenleri Temizle (Yedekli)' $ZI.Check 'purple'
$r3 = New-ZBtn 'Tümünü Seç / Kaldır' $ZI.List
$r4 = New-ZBtn 'Tam Yedek Al' $ZI.Save
$r5 = New-ZBtn 'Yedekten Geri Yükle' $ZI.Restore
$r6 = New-ZBtn 'Yedek Klasörü' $ZI.Folder
$regCard = New-ZCard 'Geçersiz / Yetim Kayıt Defteri Girdileri' $ZI.Reg 'Fill'
$regGrid = New-ZGrid @('Kategori:16', 'Anahtar:38', 'Değer:20', 'Bilgi:26') -CheckBox; $regCard.Controls.Add($regGrid)
$secCard = New-ZCard 'Ele Geçirme (Hijack) ve Güvenlik Kontrolü' $ZI.Shield 'Bottom' 250
$secGrid = New-ZFindingsGrid; $secCard.Controls.Add($secGrid)
Add-ZDock $pg @((New-ZBar @($r1, $r2, $r3, $r4, $r5, $r6)), $regCard, (New-ZSpacer 12), $secCard)
$r1.Add_Click({
        [void](Start-ZJob 'Kayıt Defteri Taraması' { $i = @(Get-ZRegistryIssues); $s = @(Test-ZSecurityTamper); [pscustomobject]@{ R = $i; Sec = $s } } @{} {
                param($res)
                if (-not $res) { return }
                $regGrid.Rows.Clear()
                foreach ($x in @($res.R)) { if ($x) { [void](Add-ZRow $regGrid @($true, $x.Kategori, $x.Anahtar, $x.Deger, $x.Bilgi) $x) } }
                Set-ZFindings $secGrid $res.Sec
                Set-ZCardRight $regCard ('{0} girdi — temizlemeden önce otomatik .reg yedeği alınır' -f $regGrid.Rows.Count)
            } @($r1, $r2))
    })
$r2.Add_Click({
        $sel = @(); foreach ($row in $regGrid.Rows) { if ($row.Cells['Sec'].Value -eq $true -and $row.Tag) { $sel += $row.Tag } }
        if ($sel.Count -eq 0) { Show-ZInfo 'Temizlenecek girdi seçilmedi. Önce tarama yapın.'; return }
        if (-not (Confirm-Z ("{0} kayıt defteri girdisi temizlenecek. Her anahtarın .reg yedeği alınacak. Devam edilsin mi?" -f $sel.Count))) { return }
        [void](Start-ZJob 'Kayıt Defteri Temizliği' { if ($JobParams.RP) { [void](New-ZRestorePoint) }; $r = Remove-ZRegistryIssues $JobParams.Items; [pscustomobject]@{ R = $r } } @{ Items = $sel; RP = $UI.RestoreCheck.Checked } { param($res) $r1.PerformClick() } @($r1, $r2))
    })
$r3.Add_Click({
        $all = $true; foreach ($row in $regGrid.Rows) { if ($row.Cells['Sec'].Value -ne $true) { $all = $false; break } }
        foreach ($row in $regGrid.Rows) { $row.Cells['Sec'].Value = (-not $all) }
    })
$r4.Add_Click({
        [void](Start-ZJob 'Kayıt Defteri Tam Yedek' {
                $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
                foreach ($h in @(@('HKCU', 'HKCU'), @('HKLM\SOFTWARE', 'HKLM-SOFTWARE'), @('HKLM\SYSTEM\CurrentControlSet', 'HKLM-SYSTEM'))) {
                    $file = Join-Path $Global:ZBackupDir ("TAM_{0}_{1}.reg" -f $stamp, $h[1])
                    Write-ZLog ("Yedekleniyor: {0} ..." -f $h[0])
                    & reg.exe export $h[0] "$file" /y 2>&1 | Out-Null
                    if (Test-Path $file) { Write-ZLog ("Kaydedildi: {0} ({1})" -f $file, (Format-ZSize (Get-Item $file).Length)) 'OK' } else { Write-ZLog ("Yedeklenemedi: {0}" -f $h[0]) 'ERR' }
                }
                [pscustomobject]@{ R = $true }
            } @{} $null @($r4))
    })
$r5.Add_Click({
        $od = New-Object System.Windows.Forms.OpenFileDialog; $od.InitialDirectory = $Global:ZBackupDir; $od.Filter = 'Kayıt dosyası (*.reg)|*.reg'; $od.Title = 'Geri yüklenecek yedeği seçin'
        if ($od.ShowDialog() -ne 'OK') { return }
        if (-not (Confirm-Z ("Bu yedek kayıt defterine geri yüklenecek:`n{0}`n`nDevam edilsin mi?" -f $od.FileName))) { return }
        [void](Start-ZJob 'Kayıt Defteri Geri Yükleme' { [void](Invoke-ZProcess 'reg.exe' ('import "{0}"' -f $JobParams.File)); [pscustomobject]@{ R = $true } } @{ File = $od.FileName })
    })
$r6.Add_Click({ Start-Process explorer.exe $Global:ZBackupDir })

# =====================================================================
#  SAYFA: TEMİZLİK & BAŞLANGIÇ
# =====================================================================
$pg = New-ZPage 'clean'
$cl1 = New-ZBtn 'Analiz Et' $ZI.Scan 'primary'
$cl2 = New-ZBtn 'Seçilenleri Temizle' $ZI.Clean 'purple'
$cl3 = New-ZBtn 'Yüksek Performans Güç Planı' $ZI.Bolt
$cl4 = New-ZBtn 'Nihai Performans Güç Planı' $ZI.Bolt
$cleanCard = New-ZCard 'Gereksiz Dosyalar' $ZI.Clean 'Fill'
$cleanGrid = New-ZGrid @('Hedef:64', 'Boyut:22') -CheckBox; $cleanCard.Controls.Add($cleanGrid)
foreach ($k in $Global:ZCleanTargets.Keys) { [void](Add-ZRow $cleanGrid @($true, $k, '—')) }
$stCard2 = New-ZCard 'Başlangıç Programları (açılış hızı)' $ZI.Play 'Fill'
$st1 = New-ZBtn 'Yenile' $ZI.Refresh 'secondary' 0 30; $st2 = New-ZBtn 'Devre Dışı Bırak' $ZI.Stop 'danger' 0 30; $st3 = New-ZBtn 'Etkinleştir' $ZI.Check 'success' 0 30
$stBar = New-ZBar @($st1, $st2, $st3) $ZC.Surf
$startGrid = New-ZGrid @('Ad:24', 'Komut:46', 'Kapsam:16', '@SEV:Durum:14')
Add-ZDock $stCard2 @($stBar, $startGrid)
$cleanCols = New-ZCols @($cleanCard, $stCard2) @(38, 62) 'Fill'
Add-ZDock $pg @((New-ZBar @($cl1, $cl2, $cl3, $cl4)), $cleanCols)
$cl1.Add_Click({
        [void](Start-ZJob 'Temizlik Analizi' {
                $o = @{}; $tot = 0
                foreach ($k in $Global:ZCleanTargets.Keys) { $s = Get-ZCleanSize $k; $o[$k] = $s; $tot += $s; Write-ZLog ("{0}: {1}" -f $k, (Format-ZSize $s)) }
                Write-ZLog ("Temizlenebilir toplam: {0}" -f (Format-ZSize $tot)) 'OK'
                [pscustomobject]@{ R = $o; Total = $tot }
            } @{} {
                param($res)
                if (-not $res) { return }
                foreach ($row in $cleanGrid.Rows) { $k = "$($row.Cells[1].Value)"; if ($res.R.ContainsKey($k)) { $row.Cells[2].Value = (Format-ZSize $res.R[$k]) } }
                Set-ZCardRight $cleanCard ('Toplam ' + (Format-ZSize $res.Total)) $ZC.Orange
            } @($cl1, $cl2))
    })
$cl2.Add_Click({
        $sel = @(); foreach ($row in $cleanGrid.Rows) { if ($row.Cells[0].Value -eq $true) { $sel += "$($row.Cells[1].Value)" } }
        if ($sel.Count -eq 0) { Show-ZInfo 'Temizlenecek öğe seçin.'; return }
        if (-not (Confirm-Z ("Seçilen {0} öğe kalıcı olarak silinecek. Devam edilsin mi?" -f $sel.Count))) { return }
        [void](Start-ZJob 'Temizlik' { $t = Invoke-ZClean $JobParams.Items; [pscustomobject]@{ R = $t } } @{ Items = $sel } { param($res) if ($res) { Show-ZInfo ('Temizlik tamamlandı. Kazanılan alan: ' + (Format-ZSize $res.R)); $cl1.PerformClick() } } @($cl1, $cl2))
    })
$cl3.Add_Click({ Invoke-ZUIFix (New-ZFinding 'BİLGİ' 'Performans' 'Güç planı' '' '' 'POWER_HIGH') -NoConfirm })
$cl4.Add_Click({ Invoke-ZUIFix (New-ZFinding 'BİLGİ' 'Performans' 'Güç planı' '' '' 'POWER_ULTIMATE') -NoConfirm })
function Update-ZStartupUI {
    $startGrid.Rows.Clear()
    $items = @(Get-ZStartupItems)
    foreach ($s in $items) { [void](Add-ZRow $startGrid @($s.Ad, $s.Komut, $s.Kapsam, $s.Durum) $s) }
    Set-ZCardRight $stCard2 ('{0} program  •  {1} etkin' -f $items.Count, @($items | Where-Object { $_.Durum -eq 'Etkin' }).Count)
}
$st1.Add_Click({ Update-ZStartupUI })
$st2.Add_Click({ if ($startGrid.SelectedRows.Count) { $s = $startGrid.SelectedRows[0].Tag; Set-ZStartupItem $s.Ad $s._Approved $false; Update-ZStartupUI } })
$st3.Add_Click({ if ($startGrid.SelectedRows.Count) { $s = $startGrid.SelectedRows[0].Tag; Set-ZStartupItem $s.Ad $s._Approved $true; Update-ZStartupUI } })

# =====================================================================
#  SAYFA: TAKİP & RAPOR
# =====================================================================
$pg = New-ZPage 'track'
$t1 = New-ZBtn 'HTML Rapor Oluştur' $ZI.Doc 'primary'
$t2 = New-ZBtn 'Rapor Klasörü' $ZI.Folder
$t3 = New-ZBtn 'Haftalık Otomatik Takibi Aç' $ZI.Clock 'purple'
$t4 = New-ZBtn 'Otomatik Takibi Kapat' $ZI.Stop
$trCard = New-ZCard 'Puan Geçmişi' $ZI.Chart 'Top' 250
$trGraph = New-ZGraph 180 'Fill'
$trGraph.Tag.Series = @(@{ Name = 'ZETX puanı'; Color = $ZC.Accent; Data = New-Object System.Collections.ArrayList }, @{ Name = 'Sağlık'; Color = $ZC.Green; Data = New-Object System.Collections.ArrayList })
$trGraph.Tag.Points = 20; $trCard.Controls.Add($trGraph)
$cmpLbl = New-ZLabel 'Takip için en az iki tarama gerekir.' $ZF.Bold $ZC.Text2 'Top' 52 'MiddleLeft'
$histCard = New-ZCard 'Tarama Geçmişi' $ZI.Hist 'Fill'
$histGrid = New-ZGrid @('Tarih:18', 'Puan:9', 'Derece:9', 'Sağlık:10', 'Performans:11', 'Kritik:9', 'Uyarı:9', 'Bilgi:9'); $histCard.Controls.Add($histGrid)
Add-ZDock $pg @((New-ZBar @($t1, $t2, $t3, $t4)), $trCard, $cmpLbl, $histCard)
function Update-ZHistoryUI {
    $h = @(Get-ZHistory)
    $histGrid.Rows.Clear()
    foreach ($sr in $trGraph.Tag.Series) { $sr.Data.Clear() }
    foreach ($x in ($h | Select-Object -Last 20)) { [void]$trGraph.Tag.Series[0].Data.Add((ConvertTo-ZInt $x.Puan)); [void]$trGraph.Tag.Series[1].Data.Add((ConvertTo-ZInt $x.Saglik)) }
    for ($i = $h.Count - 1; $i -ge 0; $i--) { $x = $h[$i]; [void](Add-ZRow $histGrid @($x.Tarih, $x.Puan, $x.Derece, $x.Saglik, $x.Performans, $x.Kritik, $x.Uyari, $x.Bilgi)) }
    $trGraph.Invalidate()
    $cmp = Compare-ZHistory
    if ($cmp) {
        $d = ConvertTo-ZInt $cmp.Delta; $sign = ''; if ($d -gt 0) { $sign = '+' }
        $txt = ("Son tarama: {0} puan ({1}{2})   •   Yeni sorunlar: {3}   •   Giderilen: {4}" -f $cmp.Current.Puan, $sign, $d, @($cmp.New).Count, @($cmp.Fixed).Count)
        if (@($cmp.New).Count) { $txt += "`nYeni: " + ((@($cmp.New) | Select-Object -First 3) -join '  |  ') }
        $cmpLbl.Text = $txt; $cmpLbl.ForeColor = $(if ($d -ge 0) { $ZC.Green } else { $ZC.Orange })
    }
}
$Script:TaskName = 'ZETX PC Ariza Takip - Haftalik Tarama'
$t1.Add_Click({ New-ZUIReport })
$t2.Add_Click({ Start-Process explorer.exe $Global:ZReportDir })
$t3.Add_Click({
        try {
            $self = [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
            if ($self -match '\\(powershell|pwsh)(_ise)?\.exe$') { $act = New-ScheduledTaskAction -Execute $self -Argument ('-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -ArkaPlanTarama' -f $PSCommandPath) }
            else { $act = New-ScheduledTaskAction -Execute $self -Argument '-ArkaPlanTarama' }
            $trg = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At ([datetime]::Today.AddHours(20))
            $prn = New-ScheduledTaskPrincipal -UserId ("{0}\{1}" -f $env:USERDOMAIN, $env:USERNAME) -LogonType Interactive -RunLevel Highest
            $set = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
            Register-ScheduledTask -TaskName $Script:TaskName -Action $act -Trigger $trg -Principal $prn -Settings $set -Force -ErrorAction Stop | Out-Null
            Write-ZActivity 'Haftalık otomatik takip açıldı: her Pazar 20:00 (bilgisayar kapalıysa ilk açılışta).'
            Show-ZInfo 'Haftalık otomatik takip açıldı. Her Pazar 20:00ʼde arka planda tarama yapılıp sonuç bildirim olarak gösterilecek.'
        } catch { Write-ZErrorLog $_ 'ScheduledTask'; Write-ZActivity ('Zamanlanmış görev oluşturulamadı: ' + $_.Exception.Message) }
    })
$t4.Add_Click({ try { Unregister-ScheduledTask -TaskName $Script:TaskName -Confirm:$false -ErrorAction Stop; Write-ZActivity 'Otomatik takip kapatıldı.' } catch { Write-ZActivity 'Otomatik takip zaten kapalı.' } })

# =====================================================================
#  SAYFA: HAKKINDA
# =====================================================================
$pg = New-ZPage 'about'
$apCard = New-ZCard 'Program' $ZI.Info 'Fill'
$aB = New-ZLabel $Global:ZETX.AppName $ZF.KpiS $ZC.Text 'Top' 40; $aB.BackColor = $ZC.Surf
$aC = New-ZLabel ("Sürüm {0}   •   {1}`nDonanım ve sistem arıza tespiti, onarım, sürücü/BIOS kontrolü, darboğaz analizi, FPS tahmini ve ölçümü.`nProgram tamamen ücretsizdir; tüm özellikler açıktır." -f $Global:ZETX.Version, $Global:ZETX.Edition) $ZF.Body $ZC.Text2 'Top' 76 'TopLeft'; $aC.BackColor = $ZC.Surf
$aFree = New-ZLabel ('✔  ' + $Global:ZETX.Edition.ToUpper()) $ZF.Bold $ZC.Green 'Top' 30; $aFree.BackColor = $ZC.Surf
Add-ZDock $apCard @($aB, $aC, $aFree)
$conCard = New-ZCard 'Geliştirici & İletişim' $ZI.Chat 'Fill'
$cB = New-ZLabel $Global:ZETX.Owner $ZF.KpiS $ZC.Text 'Top' 40; $cB.BackColor = $ZC.Surf
$cC = New-ZLabel ("Marka: {0}   •   YouTube: {1}`nDiscord: {2}`nE-posta: {3}" -f $Global:ZETX.Brand, $Global:ZETX.Channel, ($Global:ZETX.Discord -replace '^https://', ''), $Global:ZETX.Email) $ZF.Body $ZC.Text2 'Top' 76 'TopLeft'; $cC.BackColor = $ZC.Surf
$ck1 = New-ZBtn 'Discordʼa Katıl' $ZI.Chat 'purple'; $ck2 = New-ZBtn 'E-posta Gönder' $ZI.Mail
$cRow = New-ZBar @($ck1, $ck2) $ZC.Surf
Add-ZDock $conCard @($cB, $cC, $cRow)
$aboutTop = New-ZCols @($apCard, $conCard) @(52, 48) 'Top' 236
$dcCard = New-ZCard 'Topluluk' $ZI.Chat 'Top' 130
$dcL = New-ZLabel "Soru, öneri ve hata bildirimleri için Discord sunucumuza katılın. Yeni sürümler ve diğer ZETX programları (ZETX FPS Optimizer vb.) duyuruları da orada paylaşılır." $ZF.Body $ZC.Text 'Fill' 0 'TopLeft'; $dcL.BackColor = $ZC.Surf
$dcCard.Controls.Add($dcL)
$abFoot = New-ZLabel ("{0} v{1}  •  © {2} {3}. Tüm hakları saklıdır." -f $Global:ZETX.AppName, $Global:ZETX.Version, (Get-Date).Year, $Global:ZETX.Owner) $ZF.Small $ZC.Muted 'Top' 34
Add-ZDock $pg @($aboutTop, (New-ZSpacer 12), $dcCard, $abFoot)
$ck1.Add_Click({ Start-Process $Global:ZETX.Discord })
$ck2.Add_Click({ Start-Process ('mailto:{0}?subject={1}' -f $Global:ZETX.Email, [uri]::EscapeDataString('ZETX PC ARIZA TAKİP ONARIM')) })

# =====================================================================
#  SAYFA GEÇİŞİ
# =====================================================================
function Show-ZPage { param([string]$Key)
    try {
        foreach ($k in $UI.Pages.Keys) { $UI.Pages[$k].Visible = ($k -eq $Key) }
        foreach ($k in $UI.Nav.Keys) { $UI.Nav[$k].Tag.Active = ($k -eq $Key); $UI.Nav[$k].Invalidate() }
        $m = $UI.NavMeta[$Key]
        $UI.Header.Tag.Title = $m.Title; $UI.Header.Tag.Sub = $m.Sub; $UI.Header.Tag.Icon = $m.Icon; $UI.Header.Invalidate()
        if ($Key -eq 'track') { Update-ZHistoryUI }
        if ($Key -eq 'clean' -and $startGrid.Rows.Count -eq 0) { Update-ZStartupUI }
        if ($Key -eq 'score') { Set-ZWinSatUI (Get-ZWinSat) }
        if ($Key -eq 'fps') { if ($procCombo.Items.Count -eq 0) { Update-ZFpsProcs }; Update-ZFpsHistoryUI; if ($estGrid.Rows.Count -eq 0) { Update-ZFpsEstimate } }
        if ($Key -eq 'fix') { Update-ZBeforeAfter }
    } catch { Write-ZErrorLog $_ ('Show-ZPage ' + $Key) }
}

# ---- Yerleşim ----
$form.Controls.Add($content)
$form.Controls.Add($drawer)
$form.Controls.Add($header)
$form.Controls.Add($side)
$form.ResumeLayout($false)
$form.PerformLayout()

# ---- Zamanlayıcı ----
$jobTimer = New-Object System.Windows.Forms.Timer; $jobTimer.Interval = 250
$jobTimer.Add_Tick({
        try {
            Update-ZJobs
            if ($Script:MonJob) {
                $s = $null; $last = $null
                while ($Script:MonJob.Sync.Samples.TryDequeue([ref]$s)) { $last = $s }
                if ($last) {
                    Push-ZMeter $UI.Meters.Cpu (ConvertTo-ZNum $last.Cpu) ('En yüklü çekirdek %' + (ConvertTo-ZInt $last.CpuMax))
                    Push-ZMeter $UI.Meters.Gpu (ConvertTo-ZNum $last.Gpu) '3D yükü'
                    Push-ZMeter $UI.Meters.Ram (ConvertTo-ZNum $last.Ram) $Script:RamText
                    Push-ZMeter $UI.Meters.Disk (ConvertTo-ZNum $last.Disk) 'Etkin süre'
                }
            }
            if ($Script:LiveJob) {
                $s = $null; $got = $false
                while ($Script:LiveJob.Sync.Samples.TryDequeue([ref]$s)) {
                    $got = $true
                    [void]$graph.Tag.Series[0].Data.Add((ConvertTo-ZNum $s.CpuMax)); [void]$graph.Tag.Series[1].Data.Add((ConvertTo-ZNum $s.Gpu)); [void]$graph.Tag.Series[2].Data.Add((ConvertTo-ZNum $s.Ram))
                    [void]$graph.Tag.Series[3].Data.Add((ConvertTo-ZNum $s.Disk)); [void]$graph.Tag.Series[4].Data.Add((ConvertTo-ZNum $s.Vram))
                }
                if ($got) { $graph.Invalidate() }
            }
        } catch { Write-ZErrorLog $_ 'Timer' }
    })

$form.Add_Shown({
        & $Script:PlaceHeader
        Show-ZPage 'dash'
        $jobTimer.Start()
        Write-ZActivity ('Hoş geldiniz! ' + $Global:ZETX.AppName + ' — ' + $Global:ZETX.Edition)
        [void](Start-ZJob 'Sistem Bilgisi' {
                $s = Get-ZSystemInfo; $b = $null; try { $b = Get-ZStaticBottleneck } catch {}; $d = Get-ZDisplayInfo
                $rp = $null; try { $rp = Get-ZRestoreInfo } catch {}
                [pscustomobject]@{ R = $s; Static = $b; Display = $d; Restore = $rp }
            } @{} {
                param($res)
                if (-not $res -or -not $res.R) { return }
                $Script:SysInfo = $res.R; $Script:Display = $res.Display
                if ($res.Restore -and $res.Restore.Need) { $UI.RpBanner.Tag.Text = $res.Restore.Text; $UI.RpBanner.Visible = $true; $UI.RpBanner.Invalidate(); Write-ZActivity ('ⓘ ' + $res.Restore.Text) }
                $Script:RamText = ('{0} toplam' -f (Format-ZSize $res.R.RamBytes))
                $UI.InfoGrid.Rows.Clear()
                $map = [ordered]@{ 'Bilgisayar' = 'Bilgisayar'; 'İşletim sistemi' = 'Isletim'; 'İşlemci' = 'Islemci'; 'Ekran kartı' = 'EkranKarti'; 'Bellek' = 'Bellek'; 'Anakart' = 'Anakart'; 'BIOS' = 'BIOS'; 'Sistem diski' = 'SistemDiski'; 'Windows kurulumu' = 'KurulumTarihi'; 'Çalışma süresi' = 'CalismaSuresi' }
                foreach ($k in $map.Keys) { [void](Add-ZRow $UI.InfoGrid @($k, $res.R.($map[$k]))) }
                if ($res.Display) { $ix = [array]::IndexOf([string[]]@('1080p', '1440p', '4K'), "$($res.Display.Class)"); if ($ix -ge 0) { $fRes.SelectedIndex = $ix } }
                if ($res.Static) {
                    & $Script:OnStatic ([pscustomobject]@{ R = $res.Static })
                    if (-not $Script:LastScan) { Set-ZKpi $UI.Kpi.P ("$([int](($res.Static.CpuScore + $res.Static.GpuScore) / 2 + 15))") ("CPU {0} • GPU {1}" -f $res.Static.CpuScore, $res.Static.GpuScore) }
                }
            } @() -Quiet)
        $Script:MonJob = Start-ZJob 'Canlı İzleme' {
            while (-not $Sync.Cancel) {
                try { $Sync.Samples.Enqueue((Get-ZLiveSample)) } catch {}
                for ($i = 0; $i -lt 8 -and -not $Sync.Cancel; $i++) { Start-Sleep -Milliseconds 200 }
            }
            [pscustomobject]@{ R = $true }
        } @{} $null @() -Quiet
        $last = @(Get-ZHistory) | Select-Object -Last 1
        if ($last) {
            Set-ZRing $UI.Ring $last.Puan $last.Derece ('Son tarama: ' + $last.Tarih) 'SON TARAMA PUANI'
            Set-ZKpi $UI.Kpi.H ("$($last.Saglik)") '/ 100 sağlık puanı'; Set-ZKpi $UI.Kpi.C ("$($last.Kritik)") 'son taramada'; Set-ZKpi $UI.Kpi.W ("$($last.Uyari)") 'son taramada'
        }
    })

$form.Add_FormClosing({
        param($s, $e)
        $busy = @($Script:Jobs | Where-Object { -not $_.Quiet })
        if ($busy.Count -gt 0) {
            if (-not (Confirm-Z ("Devam eden işlem var: {0}`nYine de çıkılsın mı? (SFC/DISM gibi işlemler yarıda kalabilir)" -f (($busy | ForEach-Object { $_.Name }) -join ', ')))) { $e.Cancel = $true; return }
        }
        $jobTimer.Stop()
        foreach ($j in @($Script:Jobs)) { try { $j.Sync.Cancel = $true; [void]$j.PS.BeginStop($null, $null) } catch {} }
    })

[void]$form.ShowDialog()
try { $form.Dispose() } catch {}
[Environment]::Exit(0)
