$ErrorActionPreference = 'Stop'
$root = 'D:\codex\Lora(eg)\comparison_experiments\stage55_sf12_sf11_flow_v4_noldro'
$matlab = 'D:\MATLAB 2022a\bin\matlab.exe'
try {
    $call = "cd('D:/codex/Lora(eg)/comparison_experiments/stage55_sf12_sf11_flow_v4_noldro'); addpath('scripts'); p=promoteV5ToV6KnownCaseProfile(); assert(strcmp(p.status,'PASS')); r=buildV4BCaseAnchorReportV6(); assert(strcmp(r.status,'PASS')); a=auditV4BCaseAnchorV6(); assert(strcmp(a.status,'PASS'));"
    & $matlab -batch $call
    if ($LASTEXITCODE -ne 0) { throw 'V6 promotion, report or audit failed.' }
    Set-Content -LiteralPath (Join-Path $root 'results\case_anchor_b\B_CASE_ANCHOR_AWGN_V6_COMPLETE.txt') `
        -Value ([DateTime]::Now.ToString('o')) -Encoding UTF8
    Write-Output 'B CASE ANCHOR AWGN V6 COMPLETE'
    exit 0
}
catch { Write-Error $_; exit 1 }
