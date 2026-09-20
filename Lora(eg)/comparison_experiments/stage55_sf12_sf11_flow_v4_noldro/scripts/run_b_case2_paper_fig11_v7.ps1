$ErrorActionPreference='Stop'
$root='D:\codex\Lora(eg)\comparison_experiments\stage55_sf12_sf11_flow_v4_noldro'
$matlab='D:\MATLAB 2022a\bin\matlab.exe'
try {
 $run="cd('D:/codex/Lora(eg)/comparison_experiments/stage55_sf12_sf11_flow_v4_noldro');addpath('scripts');runV4PaperCurveFormalV7Worker(1,1);r=buildV4PaperCurveReportV7();assert(strcmp(r.status,'PASS'));b=buildV4HardBerOnlyPlotV7();assert(strcmp(b.status,'PASS')&&~b.mlBerPlotted);a=auditV4PaperCurveV7();assert(strcmp(a.status,'PASS'));"
 & $matlab -batch $run
 if($LASTEXITCODE-ne0){throw 'Paper Figure 11 V7 failed.'}
 Set-Content -LiteralPath (Join-Path $root 'results\paper_curve_v7\COMPLETE.txt') -Value ([DateTime]::Now.ToString('o')) -Encoding UTF8
 Write-Output 'CASE2 PAPER FIGURE 11 V7 COMPLETE'
 exit 0
}catch{Write-Error $_;exit 1}
