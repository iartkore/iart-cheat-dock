<#
  Iart Cheat Dock - always-on-top, edge-docked cheat sheet panel for Windows 10/11
  -------------------------------------------------------------------------
  Run:        double-click Start-CheatDock.cmd   (or: powershell -STA -File CheatDock.ps1)
  Autostart:  powershell -ExecutionPolicy Bypass -File CheatDock.ps1 -Install    (Start menu + Startup)
  Remove:     powershell -ExecutionPolicy Bypass -File CheatDock.ps1 -Uninstall

  Global hotkeys (defaults, change in cheatdock.settings.json):
    Ctrl+Alt+Space        expand / collapse the panel (focuses search)
    Ctrl+Alt+Shift+1..9   jump straight to tab 1..9
    Ctrl+Alt+Shift+H      hide / show the whole dock (strip included)
  In the panel:
    Ctrl+Tab / Ctrl+Shift+Tab  next / previous tab     Ctrl+1..9  tab N
    Ctrl+F  search all sheets   Esc  clear search, then collapse
    Click a row                 copies the shortcut / command to the clipboard

  Cheat sheets live in .\sheets\*.json (created on first run). Edit them, then press Reload.
  File name order = tab order. No compiler or install needed: Windows PowerShell 5.1 + WPF.
#>
param([switch]$Install, [switch]$Uninstall)

# ------------------------------------------------------------------ install / relaunch
$PsExe = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
$LaunchArgs = "-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""

if ($Install -or $Uninstall) {
    $ws = New-Object -ComObject WScript.Shell
    foreach ($dir in @([Environment]::GetFolderPath('Programs'), [Environment]::GetFolderPath('Startup'))) {
        $lnkPath = Join-Path $dir 'Iart Cheat Dock.lnk'
        if ($Uninstall) { Remove-Item $lnkPath -ErrorAction SilentlyContinue; continue }
        $lnk = $ws.CreateShortcut($lnkPath)
        $lnk.TargetPath = $PsExe
        $lnk.Arguments = $LaunchArgs
        $lnk.WorkingDirectory = $PSScriptRoot
        $lnk.WindowStyle = 7
        $lnk.Description = 'Iart Cheat Dock'
        $lnk.Save()
    }
    if ($Uninstall) { 'Iart Cheat Dock shortcuts removed.' } else { 'Iart Cheat Dock added to Start menu and Startup.' }
    return
}

if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    Start-Process $PsExe -ArgumentList $LaunchArgs
    return
}

# Single instance
$createdNew = $false
$Mutex = New-Object System.Threading.Mutex($true, 'Local\IartCheatDock_SingleInstance', [ref]$createdNew)
if (-not $createdNew) { return }

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing

# ------------------------------------------------------------------ settings
$Root      = $PSScriptRoot
$SheetsDir = Join-Path $Root 'sheets'
$StateFile = Join-Path $Root 'cheatdock.settings.json'

$Cfg = [ordered]@{
    Side           = 'Right'              # Right | Left
    Monitor        = 0                    # 0 = primary, 1..N = specific monitor
    PanelWidth     = 440
    StripWidth     = 36
    KeyColumnWidth = 165
    FontSize       = 12.5
    Opacity        = 0.97
    AutoCollapse   = $true                # collapse when you click into another app (unless pinned)
    Pinned         = $false
    LastTab        = 0
    HotkeyToggle   = 'Ctrl+Alt+Space'
    HotkeyHide     = 'Ctrl+Alt+Shift+H'
    HotkeyTabs     = 'Ctrl+Alt+Shift'     # + 1..9
}
if (Test-Path $StateFile) {
    try {
        $saved = [IO.File]::ReadAllText($StateFile) | ConvertFrom-Json
        foreach ($p in $saved.PSObject.Properties) { if ($Cfg.Contains($p.Name)) { $Cfg[$p.Name] = $p.Value } }
    } catch { }
}
function Save-State {
    try { [IO.File]::WriteAllText($StateFile, ($Cfg | ConvertTo-Json), (New-Object Text.UTF8Encoding $false)) } catch { }
}

# ------------------------------------------------------------------ default cheat sheets
function Sec([string]$name, [string[]]$lines) {
    $items = foreach ($l in $lines) {
        $p = $l -split '\s=>\s', 2
        [ordered]@{ k = $p[0].Trim(); d = $(if ($p.Count -gt 1) { $p[1].Trim() } else { '' }) }
    }
    [ordered]@{ name = $name; items = @($items) }
}

function Get-DefaultSheets {
    @(
        [ordered]@{ title = 'Claude Code'; short = 'CC'; sections = @(
            (Sec 'Essential keys' @(
                'Esc => Interrupt Claude (keeps work done so far) / close dialog'
                'Esc Esc => Empty prompt: rewind menu. With text: clear draft'
                'Shift+Tab => Cycle permission modes: Manual, acceptEdits, plan, auto'
                'Alt+M => Same as Shift+Tab on some Windows terminals'
                'Ctrl+C => Interrupt, or clear input; again to exit'
                'Ctrl+D => Exit session (press twice)'
                'Alt+P => Switch model without clearing prompt'
                'Alt+T => Toggle extended thinking'
                'Alt+O => Toggle fast mode'
                'Ctrl+O => Transcript viewer (tool calls in detail)'
                'Ctrl+R => Reverse search prompt history'
                'Ctrl+B => Move running Bash / agent to background'
                'Ctrl+T => Show / hide task checklist'
                'Ctrl+S => Stash / restore current prompt'
                'Ctrl+G => Edit prompt in external editor'
                'Ctrl+V / Alt+V => Paste image from clipboard'
                'Ctrl+Enter => Send queued messages now'
                'Ctrl+L => Redraw screen'
                'Up / Down => Prompt history'
                '? => Shortcut help (on empty input)'
            ))
            (Sec 'Input prefixes' @(
                '/ => Command or skill (type to filter)'
                '! => Shell mode: run a command, Claude sees the output'
                '@ => Mention a file path (autocomplete)'
            ))
            (Sec 'Multiline input' @(
                'Shift+Enter => New line (Windows Terminal)'
                '\ + Enter => New line (any terminal)'
                'Ctrl+J => New line (any terminal)'
            ))
            (Sec 'Prompt editing' @(
                'Ctrl+A / Ctrl+E => Start / end of line'
                'Ctrl+K => Delete to end of line'
                'Ctrl+U => Delete to start of line'
                'Ctrl+W => Delete back to previous space'
                'Ctrl+Backspace => Delete previous word (Windows)'
                'Ctrl+Y => Paste last deleted text'
                'Alt+B / Alt+F => Word back / forward'
                'Ctrl+_ => Undo last input edit'
            ))
            (Sec 'Slash commands' @(
                '/help => List commands'
                '/clear => Start fresh (old session stays resumable)'
                '/compact [focus] => Summarize context to free space'
                '/context => Show context window usage'
                '/init => Create CLAUDE.md for this project'
                '/memory => Edit CLAUDE.md memory files'
                '/model => Change model'
                '/effort => Change effort level'
                '/fast => Toggle fast mode'
                '/config => Settings'
                '/permissions => Allow / deny rules'
                '/resume => Resume a previous session'
                '/rewind => Restore code / conversation checkpoint'
                '/diff => Review uncommitted changes'
                '/btw <question> => Side question, not added to history'
                '/tasks => Running shells and subagents'
                '/agents => Manage subagents'
                '/mcp => Manage MCP servers'
                '/hooks => Configure hooks'
                '/plugin => Manage plugins'
                '/recap => One-line summary of the session'
                '/doctor => Check the installation'
            ))
            (Sec 'CLI' @(
                'claude => Start interactive session'
                'claude "task" => Start with a first prompt'
                'claude -p "query" => Print mode (non-interactive, scripts)'
                'claude -c => Continue the most recent conversation'
                'claude -r => Resume a session (picker)'
                'claude --model <name> => Start with a specific model'
                'claude --permission-mode plan => Start in plan mode'
                'claude --add-dir <path> => Give access to another folder'
                'claude mcp add <name> ... => Register an MCP server'
                'claude update => Update Claude Code'
                'claude --debug => Debug logging'
            ))
            (Sec 'Files' @(
                'CLAUDE.md => Project instructions, loaded every session'
                '.claude/settings.json => Project settings (permissions, hooks)'
                '.claude/settings.local.json => Your local, uncommitted overrides'
                '~/.claude/settings.json => User-wide settings'
                '.claude/skills/<name>/SKILL.md => Project skill'
            ))
        )}

        [ordered]@{ title = 'Windows'; short = 'WIN'; sections = @(
            (Sec 'Everyday' @(
                'Win+V => Clipboard history'
                'Win+Shift+S => Snip a screenshot region'
                'Win+PrtScn => Full screenshot to Pictures\Screenshots'
                'Win+. => Emoji and symbols panel'
                'Win+H => Voice typing'
                'Win+E => File Explorer'
                'Win+R => Run dialog'
                'Win+I => Settings'
                'Win+X => Power user menu'
                'Win+L => Lock PC'
                'Ctrl+Shift+Esc => Task Manager'
                'Win+Ctrl+Shift+B => Restart graphics driver'
            ))
            (Sec 'Windows and desktops' @(
                'Alt+Tab => Switch apps'
                'Win+Tab => Task view'
                'Win+D => Show desktop / restore'
                'Win+M / Win+Shift+M => Minimize all / restore'
                'Win+Up / Win+Down => Maximize / restore-minimize'
                'Win+Left / Win+Right => Snap left / right'
                'Win+Z => Snap layouts'
                'Win+Shift+Left/Right => Move window to other monitor'
                'Win+1..9 => Open / switch to taskbar app N'
                'Win+Ctrl+D => New virtual desktop'
                'Win+Ctrl+Left/Right => Switch virtual desktop'
                'Win+Ctrl+F4 => Close current virtual desktop'
                'Win+P => Projection / display mode'
                'Alt+F4 => Close app'
            ))
            (Sec 'File Explorer' @(
                'F2 => Rename'
                'Alt+Enter => Properties'
                'Ctrl+Shift+N => New folder'
                'Alt+Up => Parent folder'
                'Alt+Left / Alt+Right => Back / forward'
                'Alt+D / Ctrl+L => Address bar (type cmd / wt to open terminal here)'
                'Ctrl+Shift+C => Copy as path'
                'Shift+Delete => Delete permanently'
            ))
            (Sec 'Run dialog (Win+R)' @(
                'appwiz.cpl => Programs and features'
                'devmgmt.msc => Device Manager'
                'diskmgmt.msc => Disk Management'
                'services.msc => Services'
                'taskschd.msc => Task Scheduler'
                'eventvwr => Event Viewer'
                'sysdm.cpl => System properties / environment variables'
                'ncpa.cpl => Network adapters'
                'regedit => Registry Editor'
                'msconfig => System configuration'
                '%temp% => Temp folder'
                'shell:startup => Startup folder'
                'winver => Windows version'
            ))
            (Sec 'Terminal' @(
                'ipconfig /all => Network configuration'
                'ipconfig /flushdns => Clear DNS cache'
                'netstat -ano => Ports and owning PIDs'
                'tasklist / taskkill /PID n /F => List / kill processes'
                'sfc /scannow => Repair system files (admin)'
                'DISM /Online /Cleanup-Image /RestoreHealth => Repair Windows image (admin)'
                'winget upgrade --all => Update all apps'
                'winget install <id> => Install an app'
                'chkdsk C: /f => Check disk (admin, on reboot)'
                'shutdown /r /t 0 => Restart now'
                'powercfg /batteryreport => Battery report'
                'where.exe <name> => Find an executable on PATH'
            ))
        )}

        [ordered]@{ title = 'Revit'; short = 'RVT'; sections = @(
            (Sec 'Navigation' @(
                'ZF / ZE => Zoom to fit'
                'ZA => Zoom all windows to fit'
                'ZR => Zoom in region'
                'ZO => Zoom out 2x'
                'ZP => Previous pan / zoom'
                'ZS => Zoom sheet size'
                'Wheel / wheel-drag => Zoom / pan'
                'Shift + wheel-drag => Orbit (3D)'
                'Double-click wheel => Zoom to fit'
                'Ctrl+Tab => Cycle open views'
            ))
            (Sec 'Visibility' @(
                'VV / VG => Visibility / Graphics'
                'HH => Temporary hide element'
                'HI => Temporary isolate element'
                'HC => Temporary hide category'
                'IC => Temporary isolate category'
                'HR => Reset temporary hide / isolate'
                'EH => Hide element in view'
                'VH => Hide category in view'
                'EU / VU => Unhide element / category'
                'RH => Reveal hidden elements'
                'WF / HL / SD => Wireframe / hidden line / shaded'
                'TL => Thin lines'
                'GD => Graphic display options'
            ))
            (Sec 'Modify' @(
                'MV => Move'
                'CO / CC => Copy'
                'RO => Rotate'
                'MM => Mirror, pick axis'
                'DM => Mirror, draw axis'
                'AR => Array'
                'RE => Scale'
                'AL => Align'
                'TR => Trim / extend to corner'
                'SL => Split element'
                'OF => Offset'
                'PN / UP => Pin / unpin'
                'DE => Delete'
                'MA => Match type properties'
                'PT => Paint'
                'LW => Linework'
                'CS => Create similar'
                'GP / UG => Group / ungroup'
                'PP / Ctrl+1 => Properties palette'
                'MD => Modify (end command)'
            ))
            (Sec 'Create' @(
                'CL => Structural column'
                'BM => Beam'
                'BR => Brace'
                'BS => Beam system'
                'SB => Floor'
                'WA => Wall'
                'DR / WN => Door / window'
                'CM => Place component'
                'LL => Level'
                'GR => Grid'
                'RP => Reference plane'
                'RM / RT => Room / room tag'
                'DI => Aligned dimension'
                'EL => Spot elevation'
                'TX => Text'
                'TG => Tag by category'
                'DL / LI => Detail line / model line'
            ))
            (Sec 'Snaps (during a command)' @(
                'SE => Endpoints'
                'SM => Midpoints'
                'SN => Nearest'
                'SI => Intersections'
                'SC => Centers'
                'SP => Perpendicular'
                'SO => Snaps off'
            ))
            (Sec 'Selection and general' @(
                'Tab => Cycle overlapping elements / chains'
                'Ctrl + click => Add to selection'
                'Shift + click => Remove from selection'
                'Drag left to right => Select fully enclosed only'
                'Drag right to left => Select crossing'
                'Enter / RC => Repeat last command'
                'Space => Flip / rotate element while placing'
                'Esc Esc => Cancel command'
                'KS => Keyboard shortcuts editor'
                'UN => Project units'
                'Ctrl+Z / Ctrl+Y => Undo / redo'
            ))
        )}

        [ordered]@{ title = 'Excel'; short = 'XLS'; sections = @(
            (Sec 'Navigate and select' @(
                'Ctrl+Arrow => Jump to edge of data'
                'Ctrl+Shift+Arrow => Select to edge of data'
                'Ctrl+Home / Ctrl+End => First / last used cell'
                'Ctrl+Space / Shift+Space => Select column / row'
                'Ctrl+A => Select region, again for sheet'
                'Ctrl+G / F5 => Go to (Special: blanks, formulas...)'
                'Ctrl+PgUp / Ctrl+PgDn => Previous / next sheet'
                'Ctrl+[ => Go to precedents'
            ))
            (Sec 'Edit' @(
                'F2 => Edit cell'
                'Alt+Enter => New line inside cell'
                'Ctrl+Enter => Fill selection with entry'
                'Ctrl+D / Ctrl+R => Fill down / right'
                'Ctrl+E => Flash fill'
                'Ctrl+; / Ctrl+Shift+; => Insert date / time'
                'Ctrl++ / Ctrl+- => Insert / delete cells'
                'Ctrl+Alt+V => Paste special'
                'Ctrl+K => Hyperlink'
                'F4 => Toggle $ references / repeat last action'
            ))
            (Sec 'Formulas' @(
                'Alt+= => AutoSum'
                'Shift+F3 => Insert function'
                'Ctrl+F3 / F3 => Name manager / paste name'
                'Ctrl+` => Show formulas'
                'Ctrl+Shift+U => Expand formula bar'
                'F9 => Calculate (or evaluate selected part in edit)'
                'Ctrl+Alt+F9 => Full recalculation'
            ))
            (Sec 'Format' @(
                'Ctrl+1 => Format cells'
                'Ctrl+B / I / U => Bold / italic / underline'
                'Ctrl+Shift+1 => Number, 2 decimals'
                'Ctrl+Shift+4 => Currency'
                'Ctrl+Shift+5 => Percent'
                'Ctrl+Shift+7 => Outline border'
                'Ctrl+9 / Ctrl+0 => Hide rows / columns'
                'Ctrl+Shift+9 => Unhide rows'
                'Alt H O I => Autofit column width'
            ))
            (Sec 'Data and tables' @(
                'Ctrl+T => Create table'
                'Ctrl+Shift+L => Toggle filters'
                'Alt A M => Remove duplicates'
                'Alt N V => PivotTable'
                'Alt W F F => Freeze panes'
                'Alt+F1 / F11 => Chart here / chart sheet'
                'Shift+F11 => New sheet'
                'Alt+F11 / Alt+F8 => VBA editor / macros'
            ))
            (Sec 'Useful functions' @(
                'XLOOKUP(v, look, ret, [nf]) => Modern lookup, replaces VLOOKUP'
                'FILTER(arr, cond) => Rows that meet a condition'
                'SORT / SORTBY / UNIQUE => Dynamic array helpers'
                'LET(n, val, calc) => Name intermediate results'
                'LAMBDA(x, calc) => Custom reusable function (Name Manager)'
                'SUMIFS / COUNTIFS => Conditional sums / counts'
                'INDEX(r, MATCH(v, l, 0)) => Classic two-way lookup'
                'IFERROR(x, alt) => Fallback on error'
                'TEXTJOIN / TEXTSPLIT => Join / split text'
                'VSTACK / HSTACK / TAKE / DROP => Reshape arrays'
                'ROUNDUP / MROUND / CEILING => Engineering rounding'
            ))
        )}
    )
}

function Initialize-Sheets {
    if (-not (Test-Path $SheetsDir)) { New-Item -ItemType Directory -Path $SheetsDir | Out-Null }
    if (@(Get-ChildItem $SheetsDir -Filter *.json -ErrorAction SilentlyContinue).Count -gt 0) { return }
    $n = 1
    foreach ($s in Get-DefaultSheets) {
        $slug = ($s.title.ToLower() -replace '[^a-z0-9]+', '-').Trim('-')
        $json = ($s | ConvertTo-Json -Depth 10) -replace '\\u0027', "'" -replace '\\u003c', '<' -replace '\\u003e', '>' -replace '\\u0026', '&'
        [IO.File]::WriteAllText((Join-Path $SheetsDir ('{0:D2}-{1}.json' -f $n, $slug)), $json, (New-Object Text.UTF8Encoding $false))
        $n++
    }
}

function Import-Sheets {
    $script:Sheets = @()
    $bad = @()
    foreach ($f in (Get-ChildItem $SheetsDir -Filter *.json | Sort-Object Name)) {
        try { $script:Sheets += ([IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8) | ConvertFrom-Json) }
        catch { $bad += $f.Name }
    }
    if ($bad.Count) { $script:LoadWarning = 'Could not read: ' + ($bad -join ', ') } else { $script:LoadWarning = '' }
}

# ------------------------------------------------------------------ global hotkeys (Win32)
if (-not ('CheatDockHotKeys' -as [type])) {
    Add-Type -ReferencedAssemblies ([System.Windows.Interop.HwndSource].Assembly.Location), ([System.Windows.Threading.Dispatcher].Assembly.Location) -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Windows.Interop;
public static class CheatDockHotKeys {
    [DllImport("user32.dll", SetLastError = true)] private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);
    [DllImport("user32.dll", SetLastError = true)] private static extern bool UnregisterHotKey(IntPtr hWnd, int id);
    public static Action<int> Callback;
    private static HwndSource _src;
    public static void Attach(IntPtr hwnd) { _src = HwndSource.FromHwnd(hwnd); _src.AddHook(WndProc); }
    public static bool Register(IntPtr hwnd, int id, uint mods, uint vk) { return RegisterHotKey(hwnd, id, mods, vk); }
    public static void Unregister(IntPtr hwnd, int id) { UnregisterHotKey(hwnd, id); }
    private static IntPtr WndProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled) {
        Action<int> cb = Callback;
        if (cb == null) return IntPtr.Zero;
        try {
            if (msg == 0x0312) { handled = true; cb(wParam.ToInt32()); }                        // WM_HOTKEY
            else if (msg == 0x007E || (msg == 0x001A && wParam.ToInt32() == 0x002F)) { cb(-1); } // display / work area changed
        } catch { }
        return IntPtr.Zero;
    }
}
'@
}

function ConvertTo-HotKey([string]$s) {
    $mods = 0x4000; $vk = 0   # MOD_NOREPEAT
    foreach ($p in ($s -split '\+')) {
        $t = $p.Trim().ToUpper()
        switch ($t) {
            'CTRL'    { $mods = $mods -bor 2 }
            'CONTROL' { $mods = $mods -bor 2 }
            'ALT'     { $mods = $mods -bor 1 }
            'SHIFT'   { $mods = $mods -bor 4 }
            'WIN'     { $mods = $mods -bor 8 }
            'SPACE'   { $vk = 0x20 }
            default {
                if ($t -match '^F([1-9]|1[0-9]|2[0-4])$') { $vk = 0x6F + [int]$Matches[1] }
                elseif ($t.Length -eq 1) { $vk = [int][char]$t }
            }
        }
    }
    return @($mods, $vk)
}

# ------------------------------------------------------------------ UI
[xml]$Xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Iart Cheat Dock" WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        Topmost="True" ShowInTaskbar="False" ResizeMode="NoResize" WindowStartupLocation="Manual"
        FontFamily="Segoe UI" UseLayoutRounding="True" TextOptions.TextFormattingMode="Display">
  <Window.Resources>
    <Style x:Key="Flat" TargetType="Button">
      <Setter Property="Foreground" Value="#E3E6EA"/>
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Focusable" Value="False"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="b" Background="{TemplateBinding Background}" CornerRadius="5" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="b" Property="Background" Value="#38FFFFFF"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="Icon" TargetType="Button" BasedOn="{StaticResource Flat}">
      <Setter Property="FontFamily" Value="Segoe MDL2 Assets"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="Width" Value="28"/>
      <Setter Property="Height" Value="26"/>
      <Setter Property="Margin" Value="1,0,0,0"/>
    </Style>
    <Style TargetType="ScrollBar">
      <Setter Property="Width" Value="8"/>
      <Setter Property="MinWidth" Value="8"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ScrollBar">
            <Track x:Name="PART_Track" IsDirectionReversed="True" Orientation="{TemplateBinding Orientation}">
              <Track.Thumb>
                <Thumb>
                  <Thumb.Template>
                    <ControlTemplate TargetType="Thumb">
                      <Border Background="#50FFFFFF" CornerRadius="4"/>
                    </ControlTemplate>
                  </Thumb.Template>
                </Thumb>
              </Track.Thumb>
            </Track>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>

  <Grid x:Name="RootGrid">
    <Grid.ColumnDefinitions>
      <ColumnDefinition Width="Auto"/>
      <ColumnDefinition Width="Auto"/>
    </Grid.ColumnDefinitions>

    <Border x:Name="Strip" Grid.Column="0" VerticalAlignment="Center" Background="#F21B1D23"
            BorderBrush="#30FFFFFF" BorderThickness="1" Padding="3,6">
      <StackPanel>
        <Button x:Name="BtnToggle" Style="{StaticResource Flat}" Height="28" FontFamily="Segoe MDL2 Assets" FontSize="12"
                ToolTip="Expand / collapse"/>
        <Border Height="1" Background="#30FFFFFF" Margin="2,4"/>
        <StackPanel x:Name="StripTabs"/>
      </StackPanel>
    </Border>

    <Border x:Name="Panel" Grid.Column="1" Background="#F4202228" BorderBrush="#30FFFFFF" BorderThickness="1">
      <DockPanel Margin="10,8,4,8">
        <Grid DockPanel.Dock="Top" Margin="0,0,6,8">
          <TextBlock Text="Iart Cheat Dock" Foreground="#E6E8EB" FontSize="14" FontWeight="SemiBold" VerticalAlignment="Center"/>
          <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
            <Button x:Name="BtnPin"     Style="{StaticResource Icon}" Content="&#xE718;" ToolTip="Pin open (do not auto-collapse)"/>
            <Button x:Name="BtnOpacity" Style="{StaticResource Icon}" Content="&#xE706;" ToolTip="Cycle transparency"/>
            <Button x:Name="BtnSide"    Style="{StaticResource Icon}" Content="&#xE8AB;" ToolTip="Dock to other side"/>
            <Button x:Name="BtnMonitor" Style="{StaticResource Icon}" Content="&#xE7F4;" ToolTip="Move to next monitor"/>
            <Button x:Name="BtnFolder"  Style="{StaticResource Icon}" Content="&#xE838;" ToolTip="Open sheets folder (edit JSON)"/>
            <Button x:Name="BtnReload"  Style="{StaticResource Icon}" Content="&#xE72C;" ToolTip="Reload sheets"/>
            <Button x:Name="BtnClose"   Style="{StaticResource Icon}" Content="&#xE711;" ToolTip="Exit Iart Cheat Dock"/>
          </StackPanel>
        </Grid>
        <WrapPanel x:Name="TabBar" DockPanel.Dock="Top" Margin="0,0,6,4"/>
        <Grid DockPanel.Dock="Top" Margin="0,2,10,8">
          <TextBox x:Name="Search" Background="#FF15161A" Foreground="#E6E8EB" CaretBrush="#E6E8EB"
                   BorderBrush="#40FFFFFF" Padding="6,4" FontSize="13"/>
          <TextBlock x:Name="SearchHint" Text="Search all sheets   (Ctrl+F)" Foreground="#70FFFFFF"
                     Margin="10,0,0,0" VerticalAlignment="Center" IsHitTestVisible="False"/>
        </Grid>
        <TextBlock x:Name="Status" DockPanel.Dock="Bottom" Foreground="#80FFFFFF" FontSize="11"
                   Margin="0,6,8,0" TextWrapping="Wrap"/>
        <ScrollViewer x:Name="Scroller" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
          <StackPanel x:Name="Content" Margin="0,0,8,0"/>
        </ScrollViewer>
      </DockPanel>
    </Border>
  </Grid>
</Window>
'@

$win = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $Xaml))
foreach ($n in 'RootGrid','Strip','StripTabs','BtnToggle','Panel','BtnPin','BtnOpacity','BtnSide','BtnMonitor','BtnFolder',
               'BtnReload','BtnClose','TabBar','Search','SearchHint','Status','Scroller','Content') {
    Set-Variable -Name $n -Value $win.FindName($n) -Scope Script
}
$FlatStyle = $win.FindResource('Flat')

$BC = New-Object System.Windows.Media.BrushConverter
function Brush([string]$hex) { $BC.ConvertFromString($hex) }
function Th($l, $t, $r, $b) { New-Object System.Windows.Thickness($l, $t, $r, $b) }

$BrAccent = Brush '#FF3D7EEA'
$BrNone   = [System.Windows.Media.Brushes]::Transparent
$BrHover  = Brush '#22FFFFFF'
$BrChip   = Brush '#FF2E323B'
$BrKey    = Brush '#FFFFD27A'
$BrDesc   = Brush '#FFD6D9DE'
$BrHead   = Brush '#FF7FB0FF'
$Mono     = New-Object System.Windows.Media.FontFamily('Consolas')

$script:Expanded = $false
$script:Cur      = 0
$script:Dpi      = 1.0
$script:Hwnd     = [IntPtr]::Zero
$script:HotkeyWarning = ''
$script:LoadWarning   = ''

function Set-Status([string]$msg) {
    if (-not $msg) {
        $msg = "$($Cfg.HotkeyToggle): show/hide  |  $($Cfg.HotkeyTabs)+1..9: tab  |  Ctrl+Tab, Ctrl+F, Esc  |  click a row to copy"
        foreach ($w in $script:HotkeyWarning, $script:LoadWarning) { if ($w) { $msg = "$w`n$msg" } }
    }
    $Status.Text = $msg
}

function Copy-Text([string]$t) {
    try { [System.Windows.Clipboard]::SetText($t); Set-Status "Copied:  $t" } catch { Set-Status 'Clipboard busy, try again' }
}

function New-Row([string]$k, [string]$d) {
    $row = New-Object System.Windows.Controls.Border
    $row.Padding = Th 4 3 4 3
    $row.CornerRadius = New-Object System.Windows.CornerRadius(4)
    $row.Background = $BrNone
    $row.Cursor = [System.Windows.Input.Cursors]::Hand
    $row.Tag = $k

    $g = New-Object System.Windows.Controls.Grid
    $c1 = New-Object System.Windows.Controls.ColumnDefinition
    $c1.Width = New-Object System.Windows.GridLength([double]$Cfg.KeyColumnWidth)
    $c2 = New-Object System.Windows.Controls.ColumnDefinition
    $g.ColumnDefinitions.Add($c1); $g.ColumnDefinitions.Add($c2)

    $chip = New-Object System.Windows.Controls.Border
    $chip.Background = $BrChip
    $chip.CornerRadius = New-Object System.Windows.CornerRadius(3)
    $chip.Padding = Th 5 1 5 1
    $chip.Margin = Th 0 0 8 0
    $chip.HorizontalAlignment = 'Left'
    $chip.VerticalAlignment = 'Top'
    $kt = New-Object System.Windows.Controls.TextBlock
    $kt.Text = $k; $kt.FontFamily = $Mono; $kt.Foreground = $BrKey; $kt.TextWrapping = 'Wrap'
    $kt.FontSize = [double]$Cfg.FontSize
    $chip.Child = $kt

    $dt = New-Object System.Windows.Controls.TextBlock
    $dt.Text = $d; $dt.Foreground = $BrDesc; $dt.TextWrapping = 'Wrap'; $dt.FontSize = [double]$Cfg.FontSize
    $dt.VerticalAlignment = 'Center'
    [System.Windows.Controls.Grid]::SetColumn($dt, 1)

    [void]$g.Children.Add($chip); [void]$g.Children.Add($dt)
    $row.Child = $g
    $row.Add_MouseEnter({ $this.Background = $BrHover })
    $row.Add_MouseLeave({ $this.Background = $BrNone })
    $row.Add_MouseLeftButtonUp({ Copy-Text ([string]$this.Tag) })
    return $row
}

function Show-Content {
    $Content.Children.Clear()
    $q = $Search.Text.Trim()
    $SearchHint.Visibility = $(if ($q) { 'Collapsed' } else { 'Visible' })
    if ($script:Sheets.Count -eq 0) { Set-Status 'No sheets found. Add .json files to the sheets folder.'; return }

    $targets = if ($q) { 0..($script:Sheets.Count - 1) } else { @($script:Cur) }
    $count = 0
    foreach ($si in $targets) {
        $sheet = $script:Sheets[$si]
        foreach ($sec in $sheet.sections) {
            $items = @($sec.items | Where-Object {
                -not $q -or ("$($_.k) $($_.d)").IndexOf($q, [StringComparison]::OrdinalIgnoreCase) -ge 0 })
            if ($items.Count -eq 0) { continue }
            $h = New-Object System.Windows.Controls.TextBlock
            $h.Text = $(if ($q) { "$($sheet.title)  /  $($sec.name)" } else { [string]$sec.name }).ToUpper()
            $h.Foreground = $BrHead; $h.FontSize = 11; $h.FontWeight = 'SemiBold'
            $h.Margin = Th 2 $(if ($Content.Children.Count) { 12 } else { 2 }) 0 4
            [void]$Content.Children.Add($h)
            foreach ($it in $items) { [void]$Content.Children.Add((New-Row ([string]$it.k) ([string]$it.d))); $count++ }
        }
    }
    if ($count -eq 0) {
        $none = New-Object System.Windows.Controls.TextBlock
        $none.Text = 'No matches.'; $none.Foreground = $BrDesc; $none.Margin = Th 2 8 0 0
        [void]$Content.Children.Add($none)
    }
    $Scroller.ScrollToTop()
    if ($q) { Set-Status "$count matches across all sheets" } else { Set-Status '' }
}

function Update-TabHighlight {
    foreach ($b in @($TabBar.Children) + @($StripTabs.Children)) {
        $b.Background = $(if ([int]$b.Tag -eq $script:Cur) { $BrAccent } else { $BrNone })
    }
}

function Show-Tab([int]$i) {
    if ($script:Sheets.Count -eq 0) { return }
    $script:Cur = [Math]::Max(0, [Math]::Min($i, $script:Sheets.Count - 1))
    $Cfg.LastTab = $script:Cur
    Update-TabHighlight
    if ($Search.Text) { $Search.Text = '' } else { Show-Content }   # clearing text re-renders via TextChanged
    Save-State
}

function Build-Tabs {
    $TabBar.Children.Clear(); $StripTabs.Children.Clear()
    for ($i = 0; $i -lt $script:Sheets.Count; $i++) {
        $s = $script:Sheets[$i]
        $short = if ($s.short) { [string]$s.short } else { ([string]$s.title).Substring(0, [Math]::Min(3, ([string]$s.title).Length)).ToUpper() }
        $tip = "$($s.title)   ($($Cfg.HotkeyTabs)+$($i + 1))"

        $b = New-Object System.Windows.Controls.Button
        $b.Style = $FlatStyle; $b.Content = [string]$s.title; $b.Tag = $i; $b.ToolTip = $tip
        $b.Padding = Th 11 4 11 4; $b.Margin = Th 0 0 4 4; $b.FontSize = 12.5
        $b.Add_Click({ Show-Tab ([int]$this.Tag) })
        [void]$TabBar.Children.Add($b)

        $sb = New-Object System.Windows.Controls.Button
        $sb.Style = $FlatStyle; $sb.Content = $short; $sb.Tag = $i; $sb.ToolTip = $tip
        $sb.Height = 32; $sb.Margin = Th 0 1 0 1; $sb.FontSize = 9.5; $sb.FontWeight = 'Bold'
        $sb.Add_Click({
            $t = [int]$this.Tag
            if ($script:Expanded -and $script:Cur -eq $t) { Set-Expanded $false } else { Show-Tab $t; Set-Expanded $true }
        })
        [void]$StripTabs.Children.Add($sb)
    }
}

function Update-ToggleGlyph {
    $edgeIsRight = ($Cfg.Side -ne 'Left')
    $pointRight = if ($script:Expanded) { $edgeIsRight } else { -not $edgeIsRight }
    $BtnToggle.Content = [string][char]$(if ($pointRight) { 0xE76C } else { 0xE76B })
}

function Set-Placement {
    $screens = [System.Windows.Forms.Screen]::AllScreens
    $m = [int]$Cfg.Monitor
    $scr = if ($m -ge 1 -and $m -le $screens.Count) { $screens[$m - 1] } else { [System.Windows.Forms.Screen]::PrimaryScreen }
    $wa = $scr.WorkingArea
    $k = $script:Dpi
    $w = if ($script:Expanded) { [double]$Cfg.StripWidth + [double]$Cfg.PanelWidth } else { [double]$Cfg.StripWidth }
    $win.Width  = $w
    $win.Height = $wa.Height / $k
    $win.Top    = $wa.Top / $k
    $win.Left   = $(if ($Cfg.Side -eq 'Left') { $wa.Left / $k } else { $wa.Right / $k - $w })
    $win.Topmost = $false; $win.Topmost = $true   # re-assert after fullscreen apps
}

function Set-Side {
    $G = [System.Windows.Controls.Grid]
    if ($Cfg.Side -eq 'Left') {
        $G::SetColumn($Panel, 0); $G::SetColumn($Strip, 1)
        $Strip.CornerRadius = New-Object System.Windows.CornerRadius(0, 8, 8, 0)
    } else {
        $G::SetColumn($Strip, 0); $G::SetColumn($Panel, 1)
        $Strip.CornerRadius = New-Object System.Windows.CornerRadius(8, 0, 0, 8)
    }
    Update-ToggleGlyph
}

function Set-Expanded([bool]$e) {
    $script:Expanded = $e
    $Panel.Visibility = $(if ($e) { 'Visible' } else { 'Collapsed' })
    Update-ToggleGlyph
    Set-Placement
    if ($e) { [void]$win.Activate(); [void]$Search.Focus(); $Search.SelectAll() }
}

function Switch-Dock {
    if (-not $win.IsVisible) { $win.Show(); Set-Expanded $true; return }
    Set-Expanded (-not $script:Expanded)
}

function Switch-Visible {
    if ($win.IsVisible) { $win.Hide() } else { $win.Show(); Set-Placement }
}

function Update-PinButton { $BtnPin.Background = $(if ($Cfg.Pinned) { $BrAccent } else { $BrNone }) }

function Reload-Sheets {
    Import-Sheets; Build-Tabs; Show-Tab $script:Cur
}

function Move-NextMonitor {
    $count = [System.Windows.Forms.Screen]::AllScreens.Count
    $Cfg.Monitor = ([int]$Cfg.Monitor % $count) + 1
    Set-Placement; Save-State
}

function Exit-Dock { $win.Close() }

# ------------------------------------------------------------------ events
$BtnToggle.Add_Click({ Set-Expanded (-not $script:Expanded) })
$BtnPin.Add_Click({ $Cfg.Pinned = -not $Cfg.Pinned; Update-PinButton; Save-State })
$BtnOpacity.Add_Click({
    $steps = @(1.0, 0.9, 0.8, 0.7)
    $idx = [Array]::IndexOf($steps, [double]$Cfg.Opacity)
    $Cfg.Opacity = $steps[($idx + 1) % $steps.Count]
    $win.Opacity = $Cfg.Opacity; Save-State
})
$BtnSide.Add_Click({ $Cfg.Side = $(if ($Cfg.Side -eq 'Left') { 'Right' } else { 'Left' }); Set-Side; Set-Placement; Save-State })
$BtnMonitor.Add_Click({ Move-NextMonitor })
$BtnFolder.Add_Click({ Start-Process explorer.exe $SheetsDir })
$BtnReload.Add_Click({ Reload-Sheets; Set-Status 'Sheets reloaded' })
$BtnClose.Add_Click({ Exit-Dock })
$Search.Add_TextChanged({ Show-Content })

$win.Add_Deactivated({
    if ($Cfg.AutoCollapse -and -not $Cfg.Pinned -and $script:Expanded) { Set-Expanded $false }
})

$win.Add_PreviewKeyDown({
    $e = $_
    $mods = [System.Windows.Input.Keyboard]::Modifiers
    $ctrl  = $mods.HasFlag([System.Windows.Input.ModifierKeys]::Control)
    $shift = $mods.HasFlag([System.Windows.Input.ModifierKeys]::Shift)
    $n = $script:Sheets.Count
    if ($e.Key -eq 'Escape') {
        if ($Search.Text) { $Search.Text = '' } else { Set-Expanded $false }
        $e.Handled = $true
    } elseif ($ctrl -and $e.Key -eq 'Tab' -and $n) {
        Show-Tab ((($script:Cur + $(if ($shift) { -1 } else { 1 })) % $n + $n) % $n)
        $e.Handled = $true
    } elseif ($ctrl -and $e.Key -eq 'F') {
        [void]$Search.Focus(); $Search.SelectAll(); $e.Handled = $true
    } elseif ($ctrl -and $e.Key -ge [System.Windows.Input.Key]::D1 -and $e.Key -le [System.Windows.Input.Key]::D9) {
        $t = [int]$e.Key - [int][System.Windows.Input.Key]::D1
        if ($t -lt $n) { Show-Tab $t }
        $e.Handled = $true
    }
})

$win.Add_SourceInitialized({
    $script:Hwnd = (New-Object System.Windows.Interop.WindowInteropHelper $win).Handle
    try { $script:Dpi = [System.Windows.PresentationSource]::FromVisual($win).CompositionTarget.TransformToDevice.M11 } catch { }
    [CheatDockHotKeys]::Attach($script:Hwnd)
    $fail = @()
    $hk = ConvertTo-HotKey $Cfg.HotkeyToggle
    if (-not [CheatDockHotKeys]::Register($script:Hwnd, 1, $hk[0], $hk[1])) { $fail += $Cfg.HotkeyToggle }
    $hk = ConvertTo-HotKey $Cfg.HotkeyHide
    if (-not [CheatDockHotKeys]::Register($script:Hwnd, 2, $hk[0], $hk[1])) { $fail += $Cfg.HotkeyHide }
    for ($i = 1; $i -le 9; $i++) {
        $hk = ConvertTo-HotKey "$($Cfg.HotkeyTabs)+$i"
        if (-not [CheatDockHotKeys]::Register($script:Hwnd, 10 + $i, $hk[0], $hk[1]) -and $i -le $script:Sheets.Count) {
            $fail += "$($Cfg.HotkeyTabs)+$i"
        }
    }
    if ($fail.Count) { $script:HotkeyWarning = 'Hotkey taken by another app: ' + ($fail -join ', ') }
    Set-Placement
    Set-Status ''
})

[CheatDockHotKeys]::Callback = [Action[int]] {
    param($id)
    try {
        if ($id -eq -1) { Set-Placement }
        elseif ($id -eq 1) { Switch-Dock }
        elseif ($id -eq 2) { Switch-Visible }
        elseif ($id -ge 11 -and $id -le 19) {
            $t = $id - 11
            if ($t -lt $script:Sheets.Count) {
                if (-not $win.IsVisible) { $win.Show() }
                Show-Tab $t; Set-Expanded $true
            }
        }
    } catch { }
}

# ------------------------------------------------------------------ tray icon
$Tray = New-Object System.Windows.Forms.NotifyIcon
$Tray.Icon = [System.Drawing.SystemIcons]::Information
$Tray.Text = 'Iart Cheat Dock'
$Menu = New-Object System.Windows.Forms.ContextMenuStrip
[void]$Menu.Items.Add('Expand / collapse', $null, { Switch-Dock })
[void]$Menu.Items.Add('Show / hide dock', $null, { Switch-Visible })
[void]$Menu.Items.Add('Dock to other side', $null, { $BtnSide.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent))) })
[void]$Menu.Items.Add('Next monitor', $null, { Move-NextMonitor })
[void]$Menu.Items.Add('Open sheets folder', $null, { Start-Process explorer.exe $SheetsDir })
[void]$Menu.Items.Add('Reload sheets', $null, { Reload-Sheets })
[void]$Menu.Items.Add('-')
[void]$Menu.Items.Add('Exit', $null, { Exit-Dock })
$Tray.ContextMenuStrip = $Menu
$Tray.Add_MouseClick({ if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) { Switch-Dock } })
$Tray.Visible = $true

$win.Add_Closed({
    if ($script:Hwnd -ne [IntPtr]::Zero) {
        foreach ($id in @(1, 2) + (11..19)) { [CheatDockHotKeys]::Unregister($script:Hwnd, $id) }
    }
    [CheatDockHotKeys]::Callback = $null
    $Tray.Visible = $false; $Tray.Dispose()
    Save-State
    try { $Mutex.ReleaseMutex() } catch { }
    [System.Windows.Application]::Current.Shutdown()
})

# ------------------------------------------------------------------ start
Initialize-Sheets
Import-Sheets
$Panel.Width = [double]$Cfg.PanelWidth
$Strip.Width = [double]$Cfg.StripWidth
$win.Opacity = [double]$Cfg.Opacity
Build-Tabs
Set-Side
Update-PinButton
$script:Cur = [Math]::Min([int]$Cfg.LastTab, [Math]::Max(0, $script:Sheets.Count - 1))
Update-TabHighlight
Show-Content
$Panel.Visibility = 'Collapsed'
Set-Placement

$App = New-Object System.Windows.Application
$App.ShutdownMode = 'OnExplicitShutdown'
[void]$App.Run($win)
