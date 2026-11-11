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

