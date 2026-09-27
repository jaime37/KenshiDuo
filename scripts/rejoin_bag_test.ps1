<#
.SYNOPSIS
  Two-stage full-restart bag-persistence proof (issue #61).

.DESCRIPTION
  Stage 1 (scenario rejoin_bag_stage1, save squad2): the inv_nested_bag script -
  the host places known quantities INSIDE a worn bag and both clients converge on
  the per-bag distribution (the nested_bag oracle gates it unchanged) - then one
  coordinated save 'coopresume' bakes the bag AND its contents into the shared
  save (the save_sync oracle gates the transfer round trip).

  Stage 2 (scenario rejoin_bag, save coopresume): both clients RELAUNCH on the
  save the stage-1 transfer delivered - deliberately NO -Sync, the join loads
  what the TRANSFER wrote. The rejoin_bag oracle gates presence on both sides,
  host==join parity (parity IS the no-loss/no-dupe proof) and the top-level
  churn check.

  The wrapper adds the one cross-run leg: the host's stage-1 inBags distribution
  (what was saved) must equal its stage-2 inBags distribution (what came back) -
  persistence on the authority across the full restart.

  NOTE (loopback): same shared %LOCALAPPDATA%\kenshi\save caveat as
  resume_test.ps1. The plugin DLL must already be built+deployed to both
  installs (this wrapper mirrors resume_test.ps1: it does not build).

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\rejoin_bag_test.ps1
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
    $OutDir = Join-Path $repoRoot "tools\test-runs\rejoinbag_$stamp"
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

# The last per-bag distribution a verdict line reports, SORTED (bag order may
# differ across a reload; the multiset is what persists).
function Get-VerdictInBags {
    param([string]$LogFile, [string]$Pattern)
    $m = Select-String -Path $LogFile -Pattern $Pattern -ErrorAction SilentlyContinue |
         Select-Object -Last 1
    if ($null -eq $m) { return $null }
    return (@($m.Matches[0].Groups[1].Value -split ',' | ForEach-Object { [int]$_ } | Sort-Object) -join ',')
}

Write-Host "== Full-restart bag-persistence proof (issue #61) =="
Write-Host "  out dir: $OutDir"
Write-Host ""

# ---- Stage 1: nested-bag convergence + coordinated save + transfer ----------------
$stage1Pass = $true
$stage1InBags = $null
if (-not $SkipStage1) {
    Write-Host "== STAGE 1: rejoin_bag_stage1 (nested add -> coordinated save -> transfer) =="
    & powershell -NoProfile -ExecutionPolicy Bypass -File $runTest `
        -Scenario rejoin_bag_stage1 -OutDir $stage1Dir @common
    $stage1Pass = ($LASTEXITCODE -eq 0)
    Write-Host ""
    Write-Host ("STAGE 1: " + $(if ($stage1Pass) { "PASS" } else { "FAIL" }))
    if (-not $stage1Pass) {
        Write-Host "Stage 1 failed; not running stage 2 (nothing trustworthy to resume)."
        Write-Host "REJOIN-BAG-TEST RESULT: FAIL"
        exit 1
    }
    $stage1InBags = Get-VerdictInBags -LogFile (Join-Path $stage1Dir "host.log") `
        -Pattern "SCENARIO NEST verdict role=host .* inBags='([^']*)'"
    if ($null -eq $stage1InBags) {
        Write-Host "ERROR: no stage-1 host NEST verdict to compare persistence against."
        Write-Host "REJOIN-BAG-TEST RESULT: FAIL"
        exit 1
    }
    Write-Host "  stage-1 host inBags (saved): '$stage1InBags'"
} else {
    Write-Host "== STAGE 1 skipped (-SkipStage1): resuming the existing 'coopresume' =="
}

# The save the restart rides on must exist before relaunching (run_test's own
# fail-fast would also catch it, but this names the actual failure).
if (-not (Test-Path (Join-Path $saveRoot "coopresume"))) {
    Write-Host "ERROR: '$saveRoot\coopresume' does not exist after stage 1."
    Write-Host "REJOIN-BAG-TEST RESULT: FAIL"
    exit 1
}

Start-Sleep -Seconds $InterStageSec

# ---- Stage 2: relaunch both on the transferred save + bag gates -------------------
Write-Host ""
Write-Host "== STAGE 2: rejoin_bag (both relaunch on 'coopresume', bag gates) =="
& powershell -NoProfile -ExecutionPolicy Bypass -File $runTest `
    -Scenario rejoin_bag -OutDir $stage2Dir @common
$stage2Pass = ($LASTEXITCODE -eq 0)

# ---- Cross-stage persistence leg (authority side) ---------------------------------
$persistPass = $true
if (-not $SkipStage1) {
    $stage2InBags = Get-VerdictInBags -LogFile (Join-Path $stage2Dir "host.log") `
        -Pattern "SCENARIO RB verdict role=host .* inBags='([^']*)'"
    Write-Host ("  stage-2 host inBags (resumed): " + $(if ($null -eq $stage2InBags) { "(no RB verdict)" } else { "'$stage2InBags'" }))
    if ($null -eq $stage2InBags) {
        $persistPass = $false
        Write-Host "  PERSISTENCE FAIL - no stage-2 host RB verdict to compare"
    } elseif ($stage2InBags -ne $stage1InBags) {
        $persistPass = $false
        Write-Host "  PERSISTENCE FAIL - the authority's bag contents changed across the full restart ('$stage1InBags' -> '$stage2InBags')"
    } else {
        Write-Host "  PERSISTENCE PASS - the host's bag contents survived the full restart ('$stage1InBags')"
    }
}

Write-Host ""
Write-Host "== Rejoin-bag summary =="
Write-Host ("  stage 1 (nested add + save + transfer): " + $(if ($SkipStage1) { "SKIPPED" } elseif ($stage1Pass) { "PASS" } else { "FAIL" }))
Write-Host ("  stage 2 (bag gates after full restart): " + $(if ($stage2Pass) { "PASS" } else { "FAIL" }))
Write-Host ("  persistence (stage-1 vs stage-2 host):  " + $(if ($SkipStage1) { "SKIPPED" } elseif ($persistPass) { "PASS" } else { "FAIL" }))
Write-Host "  stage 1 verdict: $stage1Dir\verdict.json"
Write-Host "  stage 2 verdict: $stage2Dir\verdict.json"

$pass = $stage1Pass -and $stage2Pass -and $persistPass
Write-Host ""
Write-Host ("REJOIN-BAG-TEST RESULT: " + $(if ($pass) { "PASS" } else { "FAIL" }))
if ($pass) { exit 0 } else { exit 1 }
