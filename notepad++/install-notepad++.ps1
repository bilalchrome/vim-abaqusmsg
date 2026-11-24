# Installs Abaqus .msg support for Notepad++ 8 or newer (current Windows user).
#
#   Close Notepad++ first, then double-click install-notepad++.bat, or:
#     powershell -ExecutionPolicy Bypass -File install-notepad++.ps1 [-ConfigDir <path>] [-Uninstall]
#
#   Installs a light and a dark variant; Notepad++ uses the dark one while its dark mode is on.
#
#   -ConfigDir   Notepad++ settings folder, for portable installs (default: %AppData%\Notepad++)

param([string]$ConfigDir = "$env:APPDATA\Notepad++", [switch]$Uninstall)
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
$names = 'Abaqus msg', 'Abaqus msg (dark mode)'
$old = $amap.SelectNodes("association[starts-with(@userDefinedLangName,'Abaqus msg')]")
foreach ($n in $old) { [void]$amap.RemoveChild($n) }

if ($Uninstall) {
    $xml.Save($map)
    Write-Host 'Removed Abaqus msg support from Notepad++.'
    return
}

Copy-Item (Join-Path $src 'AbaqusMsg_light.xml'), (Join-Path $src 'AbaqusMsg_dark.xml') $udlDir
Copy-Item (Join-Path $src 'functionList\abaqusmsg.xml') $flDir

Copy-Item $map "$map.bak" -Force
foreach ($n in $names) {
    $e = $xml.CreateElement('association')
    $e.SetAttribute('id', 'abaqusmsg.xml')
    $e.SetAttribute('userDefinedLangName', $n)
    [void]$amap.AppendChild($e)
}
$xml.Save($map)

Write-Host "Installed into $ConfigDir (light and dark mode colours)"
Write-Host 'Start Notepad++ and open a .msg file. View > Function List shows the increments.'
