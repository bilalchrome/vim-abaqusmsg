# Installs vim-abaqusmsg for Vim/gVim on Windows (no Git needed).
#
#   Right-click install.bat > Run, or from PowerShell:
#     powershell -ExecutionPolicy Bypass -File install.ps1
#     powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall

param([switch]$Uninstall)
$ErrorActionPreference = 'Stop'

$src  = $PSScriptRoot
$dest = Join-Path $env:USERPROFILE 'vimfiles\pack\abaqus\start\vim-abaqusmsg'

if ($Uninstall) {
    if (Test-Path $dest) { Remove-Item -Recurse -Force $dest; Write-Host "Removed $dest" }
    else { Write-Host "Not installed ($dest does not exist)." }
    return
}

# 1. copy the plugin folders (replaces an older install)
if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
New-Item -ItemType Directory -Force $dest | Out-Null
foreach ($d in 'autoload', 'doc', 'ftdetect', 'ftplugin', 'syntax') {
    Copy-Item -Recurse -Force (Join-Path $src $d) $dest
}
Write-Host "Installed to $dest"

# 2. help tags, so :help abaqusmsg works
$vim = Get-Command vim.exe -ErrorAction SilentlyContinue
if (-not $vim) {
    $vim = Get-ChildItem "$env:ProgramFiles\Vim\vim*\vim.exe", "${env:ProgramFiles(x86)}\Vim\vim*\vim.exe" `
               -ErrorAction SilentlyContinue | Select-Object -Last 1
}
if ($vim) {
    $vimexe = if ($vim -is [System.Management.Automation.CommandInfo]) { $vim.Source } else { $vim.FullName }
    & $vimexe -u NONE -i NONE -es -c "helptags $dest\doc" -c 'qa!' | Out-Null
    Write-Host 'Help tags generated (:help abaqusmsg).'
} else {
    Write-Host 'Could not find vim.exe: run  :helptags ALL  once inside gVim.'
}

# 3. warn about settings that would override the plugin
$rcs = "$env:USERPROFILE\_vimrc", "$env:USERPROFILE\.vimrc", "$env:USERPROFILE\vimfiles\vimrc"
foreach ($rc in $rcs) {
    if (Test-Path $rc) {
        $hits = Select-String -Path $rc -Pattern '\*\.msg'
        if ($hits) {
            Write-Warning "$rc has lines for *.msg files. Remove lines that set the filetype or strip ^M,"
            Write-Warning "otherwise they override the plugin:"
            $hits | ForEach-Object { Write-Host ("    line {0}: {1}" -f $_.LineNumber, $_.Line.Trim()) }
        }
    }
}
$old = Get-ChildItem "$env:USERPROFILE\vimfiles\syntax\abaqusmsg.vim", "$env:USERPROFILE\vimfiles\ftdetect\*msg*.vim" `
           -ErrorAction SilentlyContinue
foreach ($f in $old) { Write-Warning "Older file found, it loads before the plugin: $($f.FullName)" }

Write-Host ''
Write-Host 'Done. Make sure your _vimrc has   filetype plugin on   and   syntax on,'
Write-Host 'then restart gVim and open a .msg file. Try sample\example.msg first.'
