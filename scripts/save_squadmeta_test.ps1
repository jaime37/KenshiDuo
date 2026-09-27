<#
.SYNOPSIS
  Two-stage full-restart squad-meta persistence proof (issue #74-F1).

.DESCRIPTION
  Stage 1 (scenario save_squadmeta_stage1, save squad2): each client mutates
  its OWN squad - the host renames platoons[0] 'MP-Host-Squad' and enqueues a
  JOB_MEDIC permajob, the join renames platoons[1] 'MP-Join-Squad', sets the
  faction name 'MP-Join-Faction' and enqueues its own JOB_MEDIC (the issue's
  "what the host sets persists, what the joiner sets is wiped" asymmetry,
  verbatim). One coordinated save 'coopresume' then bakes whatever the
  authority holds (the save_sync oracle gates the transfer round trip; the
  save_squadmeta oracle gates the setup legs).

  Stage 2 (scenario save_squadmeta, save coopresume): both clients RELAUNCH on
  the save the stage-1 transfer delivered - deliberately NO -Sync, the join
  loads what the TRANSFER wrote. The verdict checks names and permajob queues
  against the KNOWN stage-1 constants (self-contained: the pre-save values are
  baked into the scenario, so no cross-run parsing is needed) and the
  save_squadmeta oracle adds host==join final-census parity.

  NOTE (loopback): same shared %LOCALAPPDATA%\kenshi\save caveat as
  resume_test.ps1. The plugin DLL must already be built+deployed to both
  installs (this wrapper mirrors resume_test.ps1: it does not build).

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\save_squadmeta_test.ps1
#>
[CmdletBinding()]
param(
    [string]$OutDir = "",
    [int]$Port = 27800,
    # Install dirs. Empty -> KENSHICOOP_KENSHI_DIR / KENSHICOOP_KENSHI_JOIN_DIR
    # env override, else the harness defaults (CoopHarness.psm1).
    [string]$HostDir = "",
    [string]$JoinDir = "",
    # Seconds to let the freshly-committed save settle on disk between stages.
    [int]$InterStageSec = 5,
    [switch]$SkipStage1
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot  = Split-Path -Parent $scriptDir

Import-Module (Join-Path $scriptDir "CoopHarness.psm1") -Force
if ($HostDir -eq "") { $HostDir = Get-CoopKenshiDir }
if ($JoinDir -eq "") { $JoinDir = Get-CoopKenshiJoinDir }

if ($OutDir -eq "") {
    $stamp  = Get-Date -Format "yyyyMMdd_HHmmss"
    $OutDir = Join-Path $repoRoot "tools\test-runs\squadmeta_$stamp"
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$stage1Dir = Join-Path $OutDir "stage1"
$stage2Dir = Join-Path $OutDir "stage2"

$runTest  = Join-Path $scriptDir "run_test.ps1"
$saveRoot = Join-Path $env:LOCALAPPDATA "kenshi\save"
$common = @(
    "-Port", "$Port",
    "-HostDir", $HostDir,
    "-JoinDir", $JoinDir
)

Write-Host "== Full-restart squad-meta persistence proof (issue #74-F1) =="
Write-Host "  out dir: $OutDir"
Write-Host ""

# ---- Stage 1: own-squad mutations + coordinated save + transfer -------------------
$stage1Pass = $true
if (-not $SkipStage1) {
    Write-Host "== STAGE 1: save_squadmeta_stage1 (own-squad mutations -> coordinated save -> transfer) =="
    & powershell -NoProfile -ExecutionPolicy Bypass -File $runTest `
        -Scenario save_squadmeta_stage1 -OutDir $stage1Dir @common
    $stage1Pass = ($LASTEXITCODE -eq 0)
    Write-Host ""
    Write-Host ("STAGE 1: " + $(if ($stage1Pass) { "PASS" } else { "FAIL" }))
    if (-not $stage1Pass) {
        Write-Host "Stage 1 failed; not running stage 2 (nothing trustworthy to resume)."
        Write-Host "SAVE-SQUADMETA-TEST RESULT: FAIL"
        exit 1
    }
} else {
    Write-Host "== STAGE 1 skipped (-SkipStage1): resuming the existing 'coopresume' =="
}

# The save the restart rides on must exist before relaunching (run_test's own
# fail-fast would also catch it, but this names the actual failure).
if (-not (Test-Path (Join-Path $saveRoot "coopresume"))) {
    Write-Host "ERROR: '$saveRoot\coopresume' does not exist after stage 1."
    Write-Host "SAVE-SQUADMETA-TEST RESULT: FAIL"
    exit 1
}

Start-Sleep -Seconds $InterStageSec

# ---- Stage 2: relaunch both on the transferred save + squad-meta gates ------------
Write-Host ""
Write-Host "== STAGE 2: save_squadmeta (both relaunch on 'coopresume', squad-meta gates) =="
& powershell -NoProfile -ExecutionPolicy Bypass -File $runTest `
    -Scenario save_squadmeta -OutDir $stage2Dir @common
$stage2Pass = ($LASTEXITCODE -eq 0)

Write-Host ""
Write-Host "== Save-squadmeta summary =="
Write-Host ("  stage 1 (own-squad mutations + save + transfer): " + $(if ($SkipStage1) { "SKIPPED" } elseif ($stage1Pass) { "PASS" } else { "FAIL" }))
Write-Host ("  stage 2 (squad-meta gates after full restart):   " + $(if ($stage2Pass) { "PASS" } else { "FAIL" }))
Write-Host "  stage 1 verdict: $stage1Dir\verdict.json"
Write-Host "  stage 2 verdict: $stage2Dir\verdict.json"

$pass = $stage1Pass -and $stage2Pass
Write-Host ""
Write-Host ("SAVE-SQUADMETA-TEST RESULT: " + $(if ($pass) { "PASS" } else { "FAIL" }))
if ($pass) { exit 0 } else { exit 1 }
