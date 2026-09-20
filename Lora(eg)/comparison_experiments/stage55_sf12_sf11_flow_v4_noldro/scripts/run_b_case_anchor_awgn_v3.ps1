$ErrorActionPreference = 'Stop'
$root = 'D:\codex\Lora(eg)\comparison_experiments\stage55_sf12_sf11_flow_v4_noldro'
$matlab = 'D:\MATLAB 2022a\bin\matlab.exe'

try {
    # Checkpoint-aware single-worker entry. Completed cells are verified by
    # signature and returned without recomputation.
    $run = "cd('D:/codex/Lora(eg)/comparison_experiments/stage55_sf12_sf11_flow_v4_noldro'); addpath('scripts'); runV4BCaseAnchorFormalV3Worker(1,1);"
    & $matlab -batch $run
    if ($LASTEXITCODE -ne 0) { throw 'Formal V3 cells failed.' }

    $finish = "cd('D:/codex/Lora(eg)/comparison_experiments/stage55_sf12_sf11_flow_v4_noldro'); addpath('scripts'); r=buildV4BCaseAnchorReportV3(); assert(strcmp(r.status,'PASS')); a=auditV4BCaseAnchorV3(); assert(strcmp(a.status,'PASS'));"
    & $matlab -batch $finish
    if ($LASTEXITCODE -ne 0) { throw 'V3 report or audit failed.' }

    Set-Content -LiteralPath (Join-Path $root 'results\case_anchor_b\B_CASE_ANCHOR_AWGN_V3_COMPLETE.txt') `
        -Value ([DateTime]::Now.ToString('o')) -Encoding UTF8
    Write-Output 'B CASE ANCHOR AWGN V3 COMPLETE'
    exit 0
}
catch {
    Write-Error $_
    exit 1
}
