param([string]$Engine, [switch]$PendingReview)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
New-Item -ItemType Directory -Path (Join-Path $projectRoot 'artifacts') -Force | Out-Null
if (-not $Engine) { $Engine = Join-Path $projectRoot '.tools\godot\Godot_v4.7.2-stable_win64_console.exe' }
function Invoke-AssetCheck([string]$CheckName, [string[]]$Arguments) {
    $logPath = Join-Path $projectRoot ('artifacts\' + $CheckName + '.log')
    $result = & $Engine --path $projectRoot --log-file $logPath @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $failures = if (Test-Path -LiteralPath $logPath) { Select-String -LiteralPath $logPath -Pattern 'SCRIPT ERROR:|ERROR:' } else { @() }
    if ($exitCode -ne 0 -or $failures.Count -gt 0) {
        $result | Write-Output
        throw ('Asset check failed: ' + $CheckName)
    }
    $result | Where-Object { $_ -match 'CHECKS|CAPTURE|REVIEW' } | Write-Output
}
Invoke-AssetCheck 'asset-gate-import' @('--headless','--editor','--import')
Invoke-AssetCheck 'asset-gate-alignment' @('--headless','--script','tests/asset_alignment_checks.gd')
Invoke-AssetCheck 'asset-gate-structures' @('--headless','--script','tests/structure_geometry_checks.gd')
if (-not $PendingReview) { Invoke-AssetCheck 'asset-gate-reviewed' @('--headless','--script','tests/reviewed_asset_checks.gd') }
Invoke-AssetCheck 'asset-gate-layout' @('--headless','--script','tests/layout_checks.gd')
Invoke-AssetCheck 'asset-gate-stay' @('--headless','--script','tests/guest_stay_checks.gd','--','--fresh')
Invoke-AssetCheck 'asset-gate-couples' @('--headless','--script','tests/couple_stay_checks.gd','--','--fresh')
Invoke-AssetCheck 'asset-gate-illustrated' @('--headless','--script','tests/illustrated_skin_checks.gd')
Invoke-AssetCheck 'asset-gate-scene' @('--headless','--script','tests/scene_checks.gd','--','--fresh')
Invoke-AssetCheck 'asset-gate-population' @('--headless','--script','tests/population_checks.gd')
Invoke-AssetCheck 'asset-gate-arrival-waits' @('--headless','--script','tests/arrival_wait_checks.gd')
Invoke-AssetCheck 'asset-gate-decisions' @('--headless','--script','tests/guest_decision_checks.gd')
Invoke-AssetCheck 'asset-gate-facilities' @('--headless','--script','tests/facility_session_checks.gd')
Invoke-AssetCheck 'asset-gate-volleyball-arrivals' @('--headless','--script','tests/volleyball_arrival_checks.gd')
Invoke-AssetCheck 'asset-gate-volleyball-hits' @('--headless','--script','tests/volleyball_hit_animation_checks.gd')
Invoke-AssetCheck 'asset-gate-volleyball-traffic' @('--headless','--script','tools/probe_volleyball_traffic.gd')
Invoke-AssetCheck 'asset-gate-pose-registration' @('--headless','--script','tests/guest_pose_alignment_checks.gd')
Invoke-AssetCheck 'asset-gate-cleanliness' @('--headless','--script','tests/cleanliness_checks.gd')
Invoke-AssetCheck 'asset-gate-cleanliness-view' @('--headless','--script','tests/cleanliness_view_checks.gd')
Invoke-AssetCheck 'asset-gate-management' @('--headless','--script','tests/management_checks.gd')
Invoke-AssetCheck 'asset-gate-staff-art' @('--headless','--script','tests/staff_art_checks.gd','--','--baked')
Invoke-AssetCheck 'asset-gate-living-saves' @('--headless','--script','tests/living_save_checks.gd')
Invoke-AssetCheck 'asset-gate-living-mood' @('--headless','--script','tests/living_mood_checks.gd')
Invoke-AssetCheck 'asset-gate-living-independent' @('--headless','--script','tests/living_resort_checks.gd')
Invoke-AssetCheck 'asset-gate-occlusion' @('--script','tests/guest_occlusion_checks.gd')
Invoke-AssetCheck 'asset-gate-cabin-occlusion' @('--script','tests/cabin_occlusion_checks.gd')
Invoke-AssetCheck 'asset-gate-catalogue' @('--script','tools/capture_asset_review.gd')
Invoke-AssetCheck 'asset-gate-frames' @('--script','tools/capture_asset_review.gd','--','--walks')
Write-Output 'Asset checks passed. Inspect the rendered catalogue, frames and clipping images before recording source approval.'
