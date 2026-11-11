
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
    foreach ($j in $Script:Jobs) { if ($j.Name -eq $Name) { if (-not $Quiet) { Show-ZInfo ('“{0}” işlemi zaten çalışıyor.' -f $Name) }; return $null } }
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
        $q = $Script:ConfirmFix[$id]; if (-not $q) { $q = ('“{0}” için “{1}” uygulansın mı?' -f $Finding.Title, $title) }
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
            if ($res -and $res.Id -eq 'RESTORE_POINT') { if ($res.R) { Show-ZInfo 'Sistem geri yükleme noktası oluşturuldu.' } else { Show-ZInfo 'Geri yükleme noktası oluşturulamadı. Ayrıntılar İşlem Günlüğü’nde.' 'Warning' } }
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
    if (-not $res -or -not $res.R) { Show-ZInfo 'Tarama tamamlanamadı. Ayrıntılar İşlem Günlüğü’nde ve Belgeler\ZETX PC Ariza Takip\Kayitlar\hata-kaydi.log dosyasında.' 'Warning'; return }
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
Set-ZFindings $fixGrid @((New-ZFinding 'BİLGİ' '—' 'Henüz tarama yapılmadı' '' '“Tam Tarama” ile donanım, sistem, sürücü, güvenlik ve kayıt defterini birlikte tarayın.'))

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
        if (-not $fnd -or -not $fnd.FixId) { Show-ZInfo 'Bu bulgu için otomatik onarım yok. “Öneri” sütunundaki adımları uygulayın.'; return }
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
$v2 = New-ZBtn 'Windows Update’i Yeniden Sorgula' $ZI.Down
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
$wuCard = New-ZCard 'Windows Update’te Bekleyen Sürücü Güncellemeleri' $ZI.Down 'Bottom' 160
$wuGrid = New-ZGrid @('Güncelleme:50', 'Üretici:18', 'Sınıf:14', 'Tarih:18'); $wuCard.Controls.Add($wuGrid)
[void](Add-ZRow $wuGrid @('“Sürücü ve BIOS Sürümlerini Tara” ile Windows Update’te bu bilgisayar için yayınlanmış gerçek sürücü güncellemeleri denetlenir.', '', '', ''))
[void](Add-ZRow $biosGrid @('Durum', '“Sürücü ve BIOS Sürümlerini Tara” düğmesine basın.'))
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
                if ($wuGrid.Rows.Count -eq 0) { if ($res.WUOk) { [void](Add-ZRow $wuGrid @('Windows Update’te bu bilgisayar için bekleyen sürücü güncellemesi yok.', '', '', '')) } else { [void](Add-ZRow $wuGrid @('Windows Update’e ulaşılamadı (internet / Windows Update hizmeti kapalı olabilir).', '', '', '')) } }
                else { Set-ZCardRight $wuCard ('{0} güncelleme — “Güncelle” ile İsteğe Bağlı Güncellemeler açılır' -f $wuGrid.Rows.Count) $ZC.Orange }
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
    if ($procCombo.Items.Count) { $procCombo.SelectedIndex = 0 } else { $procCombo.Text = 'oyun.exe — oyunu açıp Yenile’ye basın' }
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
    if (-not $game) { Show-ZInfo 'Önce oyunu açın, “Yenile”ye basın ve listeden seçin.'; return }
    $sec = @(30, 60, 90)[$mDur.SelectedIndex]
    if (-not (Test-Path $Global:ZPresentMon)) {
        if (-not (Confirm-Z ("Gerçek FPS ölçümü için Intel PresentMon (açık kaynak) bir kez indirilecek:`n{0}`n`nİndirilsin mi?" -f $Global:ZPresentMonUrl))) { return }
    }
    Show-ZInfo ("{0} ölçümü 5 saniye sonra başlayacak ve {1} saniye sürecek.`nTamam’a basıp hemen oyuna geçin ve normal oynayın." -f $Label, $sec)
    [void](Start-ZJob ('FPS Ölçümü (' + $Label + ')') {
            Write-ZLog '5 saniye içinde oyuna geçin...'; Start-Sleep -Seconds 5
            $r = Measure-ZFps $JobParams.Game $JobParams.Sec $JobParams.Label
            [pscustomobject]@{ R = $r }
        } @{ Game = $game; Sec = $sec; Label = $Label } {
            param($res)
            try { $form.Activate() } catch {}
            if (-not $res -or -not $res.R) { Show-ZInfo 'FPS ölçümü yapılamadı. Oyunun açık olduğundan ve ekranda çalıştığından emin olun. Ayrıntılar İşlem Günlüğü’nde.' 'Warning'; return }
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
    $sub = New-ZLabel 'Oyunun ağırlığını seçin. Bu sistemde aldığınız FPS’i biliyorsanız girin; tahmin o değere göre ayarlanır.' $ZF.Small $ZC.Text2 'Top' 36 'TopLeft'
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
        if (-not (Confirm-Z ('“{0}” listeden silinsin mi?' -f $e.Oyun))) { return }
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
$verdict = New-ZLabel '“Donanım Dengesi Analizi” ile işlemci ve ekran kartınızın uyumunu görün.' $ZF.Bold $ZC.Text 'Top' 30
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
$liveRes = New-ZLabel 'Oyunu açın, “Oyun İçi Canlı Ölçüm”e basıp oyuna dönün. Süre sonunda darboğaz sonucu burada görünür.' $ZF.Bold $ZC.Text2 'Bottom' 72 'MiddleLeft'
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
$repNote = New-ZLabel 'İpucu: Mavi ekran, donma veya açılmayan programlarda önerilen sıra: DISM Onarım → SFC → CHKDSK. Tüm işlemler arka planda çalışır; ilerlemeyi sağ üstten ve İşlem Günlüğü’nden izleyin.' $ZF.Small $ZC.Text2 'Top' 32
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
            Show-ZInfo 'Haftalık otomatik takip açıldı. Her Pazar 20:00’de arka planda tarama yapılıp sonuç bildirim olarak gösterilecek.'
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
$ck1 = New-ZBtn 'Discord’a Katıl' $ZI.Chat 'purple'; $ck2 = New-ZBtn 'E-posta Gönder' $ZI.Mail
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
