param([switch]$Editor, [switch]$Fresh, [string]$Engine)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$enginePath = if ($Engine) { $Engine } else { Join-Path $projectRoot '.tools\godot\Godot_v4.7.2-stable_win64.exe' }
if (-not (Test-Path -LiteralPath $enginePath)) {
    throw 'Godot 4.7.2 is missing from .tools\godot. Open project.godot with your own Godot 4.7.2 installation.'
}
$logPath = Join-Path $projectRoot 'artifacts\resortis.log'
New-Item -ItemType Directory -Path (Join-Path $projectRoot 'artifacts') -Force | Out-Null
$launchArgs = @('--path', ('"' + $projectRoot + '"'), '--log-file', ('"' + $logPath + '"'))
if ($Editor) { $launchArgs += '--editor' }
$launchArgs += @('--', '--workspace-data')
if ($Fresh) { $launchArgs += '--fresh' }
Start-Process -FilePath $enginePath -ArgumentList $launchArgs -WorkingDirectory $projectRoot
