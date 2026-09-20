$ErrorActionPreference = 'Stop'
$implementationRoot = 'D:\codex\Lora(eg)\comparison_experiments\stage55_sf12_sf11_flow_v4_noldro'
$matlabExe = 'D:\MATLAB 2022a\bin\matlab.exe'
$groups = @('B_AWGN_CONTROLLED','B_AWGN_NATIVE')
$snrs = -30..-21
try {
    foreach ($group in $groups) {
        foreach ($snr in $snrs) {
            $folder = Join-Path $implementationRoot ("results\formal\track_b\{0}\snr_{1:+00;-00}\passes" -f $group,$snr)
            foreach ($passIndex in 1..10) {
                $matPath=Join-Path $folder ('pass_{0:D2}.mat'-f$passIndex);$jsonPath=Join-Path $folder ('pass_{0:D2}.json'-f$passIndex)
                if((Test-Path $matPath)-and(Test-Path $jsonPath)){continue}
                if((Test-Path $matPath)-or(Test-Path $jsonPath)){throw "Partial checkpoint: $group SNR $snr pass $passIndex"}
                $ok=$false
                foreach($attempt in 1..3){
                    Write-Output "START $group SNR $snr pass $passIndex attempt $attempt"
                    $call="cd('D:/codex/Lora(eg)/comparison_experiments/stage55_sf12_sf11_flow_v4_noldro'); addpath('scripts'); r=runV4BFormalPassV30('$group',$snr,$passIndex);"
                    &$matlabExe -batch $call;$exitCode=$LASTEXITCODE
                    if((Test-Path $matPath)-and(Test-Path $jsonPath)){$j=Get-Content $jsonPath -Raw|ConvertFrom-Json;if($j.status-eq'PASS'){Write-Output "COMPLETE $group SNR $snr pass $passIndex exit $exitCode";$ok=$true;break}}
                }
                if(-not$ok){throw "Three failures: $group SNR $snr pass $passIndex"}
            }
        }
    }
    $build="cd('D:/codex/Lora(eg)/comparison_experiments/stage55_sf12_sf11_flow_v4_noldro'); addpath('scripts'); d=buildV4ExpeditedAwgnP10FinalV30();"
    &$matlabExe -batch $build
    if($LASTEXITCODE-ne0){throw 'P10 report build failed.'}
    Set-Content -LiteralPath (Join-Path $implementationRoot 'results\formal\track_b\V30_AWGN_P10_COMPLETE.txt') -Value ([DateTime]::Now.ToString('o')) -Encoding UTF8
    Write-Output 'V30 AWGN P10 COMPLETE'
    exit 0
}
catch{Write-Error $_;exit 1}
