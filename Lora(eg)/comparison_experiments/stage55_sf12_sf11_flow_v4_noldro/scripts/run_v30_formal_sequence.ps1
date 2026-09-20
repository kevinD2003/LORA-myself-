$ErrorActionPreference = 'Stop'
$implementationRoot = 'D:\codex\Lora(eg)\comparison_experiments\stage55_sf12_sf11_flow_v4_noldro'
$matlabExe = 'D:\MATLAB 2022a\bin\matlab.exe'
$groups = @('B_AWGN_CONTROLLED','B_AWGN_NATIVE','B_RICIAN_CONTROLLED','B_RICIAN_NATIVE')
$snrs = -30..-21

try {
    foreach ($group in $groups) {
        foreach ($snr in $snrs) {
            $passFolder = Join-Path $implementationRoot ("results\formal\track_b\{0}\snr_{1:+00;-00}\passes" -f $group,$snr)
            foreach ($passIndex in 1..50) {
                $matPath = Join-Path $passFolder ('pass_{0:D2}.mat' -f $passIndex)
                $jsonPath = Join-Path $passFolder ('pass_{0:D2}.json' -f $passIndex)
                if ((Test-Path -LiteralPath $matPath) -and (Test-Path -LiteralPath $jsonPath)) {
                    Write-Output "SKIP complete $group SNR $snr pass $passIndex"
                    continue
                }
                if ((Test-Path -LiteralPath $matPath) -or (Test-Path -LiteralPath $jsonPath)) {
                    throw "Partial checkpoint: $group SNR $snr pass $passIndex"
                }
                $complete = $false
                foreach ($attempt in 1..3) {
                    Write-Output "START $group SNR $snr pass $passIndex attempt $attempt"
                    $call = "cd('D:/codex/Lora(eg)/comparison_experiments/stage55_sf12_sf11_flow_v4_noldro'); addpath('scripts'); r=runV4BFormalPassV30('$group',$snr,$passIndex);"
                    & $matlabExe -batch $call
                    $exitCode = $LASTEXITCODE
                    if ((Test-Path -LiteralPath $matPath) -and (Test-Path -LiteralPath $jsonPath)) {
                        $parsed = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json
                        if ($parsed.status -eq 'PASS') {
                            Write-Output "COMPLETE $group SNR $snr pass $passIndex exit $exitCode"
                            $complete = $true
                            break
                        }
                    }
                    Write-Output "RETRY $group SNR $snr pass $passIndex after exit $exitCode"
                }
                if (-not $complete) {
                    throw "Three pre-artifact failures: $group SNR $snr pass $passIndex"
                }
            }
        }
        Write-Output "AUDIT START $group"
        $auditCall = "cd('D:/codex/Lora(eg)/comparison_experiments/stage55_sf12_sf11_flow_v4_noldro'); addpath('scripts'); [r,a]=aggregateAndAuditV4BFormalGroupV30('$group');"
        & $matlabExe -batch $auditCall
        if ($LASTEXITCODE -ne 0) {
            throw "Formal group audit failed: $group"
        }
        Write-Output "AUDIT PASS $group"
    }
    Set-Content -LiteralPath (Join-Path $implementationRoot 'results\formal\track_b\V30_FORMAL_SEQUENCE_COMPLETE.txt') -Value ([DateTime]::Now.ToString('o')) -Encoding UTF8
    Write-Output 'V30 FORMAL SEQUENCE COMPLETE'
    exit 0
}
catch {
    Write-Error $_
    exit 1
}
