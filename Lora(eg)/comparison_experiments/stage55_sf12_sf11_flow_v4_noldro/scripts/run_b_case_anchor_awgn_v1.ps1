$ErrorActionPreference='Stop'
$root='D:\codex\Lora(eg)\comparison_experiments\stage55_sf12_sf11_flow_v4_noldro'
$matlab='D:\MATLAB 2022a\bin\matlab.exe'
try {
 foreach($caseIndex in 1..2){
  foreach($snrIndex in 1..10){
   $snr=-31+$snrIndex;$folder=Join-Path $root ("results\case_anchor_b\B-case-anchor-AWGN-v1\case_{0}\snr_{1:+00;-00}"-f$caseIndex,$snr)
   $matPath=Join-Path $folder 'formal_cell.mat';$jsonPath=Join-Path $folder 'formal_cell.json'
   if((Test-Path $matPath)-and(Test-Path $jsonPath)){continue}
   $ok=$false
   foreach($attempt in 1..3){
    Write-Output "START Case $caseIndex SNR $snr attempt $attempt"
    $call="cd('D:/codex/Lora(eg)/comparison_experiments/stage55_sf12_sf11_flow_v4_noldro'); addpath('scripts'); r=runV4BCaseAnchorCellV1($caseIndex,$snrIndex);"
    &$matlab -batch $call;$exitCode=$LASTEXITCODE
    if((Test-Path $matPath)-and(Test-Path $jsonPath)){Write-Output "COMPLETE Case $caseIndex SNR $snr exit $exitCode";$ok=$true;break}
   }
   if(-not$ok){throw "Cell failed: Case $caseIndex SNR $snr"}
  }
 }
 $build="cd('D:/codex/Lora(eg)/comparison_experiments/stage55_sf12_sf11_flow_v4_noldro'); addpath('scripts'); r=buildV4BCaseAnchorReportV1();"
 &$matlab -batch $build
 if($LASTEXITCODE-ne0){throw 'Report build failed.'}
 Set-Content -LiteralPath (Join-Path $root 'results\case_anchor_b\B_CASE_ANCHOR_AWGN_V1_COMPLETE.txt') -Value ([DateTime]::Now.ToString('o')) -Encoding UTF8
 Write-Output 'B CASE ANCHOR AWGN V1 COMPLETE'
 exit 0
}
catch{Write-Error $_;exit 1}
