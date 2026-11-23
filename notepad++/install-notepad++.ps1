# Installs Abaqus .msg support for Notepad++ 8 or newer (current Windows user).
#
#   Close Notepad++ first, then double-click install-notepad++.bat, or:
#     powershell -ExecutionPolicy Bypass -File install-notepad++.ps1 [-Dark] [-ConfigDir <path>] [-Uninstall]
#
#   -Dark        use the dark-background colours
#   -ConfigDir   Notepad++ settings folder, for portable installs (default: %AppData%\Notepad++)

param([switch]$Dark, [string]$ConfigDir = "$env:APPDATA\Notepad++", [switch]$Uninstall)
$ErrorActionPreference = 'Stop'
$src = $PSScriptRoot

if (Get-Process notepad++ -ErrorAction SilentlyContinue) {
    Write-Warning 'Notepad++ is running. Close it first, or the changes may be lost.'
}
if (-not (Test-Path $ConfigDir)) {
    throw "Notepad++ settings folder not found: $ConfigDir  (portable install? pass -ConfigDir <folder with config.xml>)"
}

$udlDir = Join-Path $ConfigDir 'userDefineLangs'
$flDir  = Join-Path $ConfigDir 'functionList'
$map    = Join-Path $flDir 'overrideMap.xml'
New-Item -ItemType Directory -Force $udlDir, $flDir | Out-Null

# remove any previous variant
Remove-Item (Join-Path $udlDir 'AbaqusMsg_*.xml') -ErrorAction SilentlyContinue
Remove-Item (Join-Path $flDir 'abaqusmsg.xml') -ErrorAction SilentlyContinue

# overrideMap.xml tells the Function List which parser belongs to the UDL
function Get-Map {
    if (-not (Test-Path $map)) {
        $shipped = Join-Path $env:ProgramFiles 'Notepad++\functionList\overrideMap.xml'
        if (Test-Path $shipped) { Copy-Item $shipped $map }
        else {
            Set-Content -Encoding UTF8 $map @'
<?xml version="1.0" encoding="UTF-8" ?>
<NotepadPlus>
	<functionList>
		<associationMap>
		</associationMap>
	</functionList>
</NotepadPlus>
'@
        }
    }
    [xml](Get-Content -Raw -Encoding UTF8 $map)
}
$xml = Get-Map
$amap = $xml.SelectSingleNode('//associationMap')
$old = $amap.SelectNodes("association[@userDefinedLangName='Abaqus msg']")
foreach ($n in $old) { [void]$amap.RemoveChild($n) }

if ($Uninstall) {
    $xml.Save($map)
    Write-Host 'Removed Abaqus msg support from Notepad++.'
    return
}

$variant = if ($Dark) { 'dark' } else { 'light' }
Copy-Item (Join-Path $src "AbaqusMsg_$variant.xml") $udlDir
Copy-Item (Join-Path $src 'functionList\abaqusmsg.xml') $flDir

Copy-Item $map "$map.bak" -Force
$e = $xml.CreateElement('association')
$e.SetAttribute('id', 'abaqusmsg.xml')
$e.SetAttribute('userDefinedLangName', 'Abaqus msg')
[void]$amap.AppendChild($e)
$xml.Save($map)

Write-Host "Installed ($variant colours) into $ConfigDir"
Write-Host 'Start Notepad++ and open a .msg file. View > Function List shows the increments.'
