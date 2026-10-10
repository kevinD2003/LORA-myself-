param(
    [int[]]$ConditionIndices = @(),
    [int[]]$WaitForIndices = @(),
    [switch]$TableDiagnostic,
    [int]$MaximumBatches = 500,
    [int]$MaximumPacketPositions = 100
)
$ErrorActionPreference='Stop'
$experimentRoot=$PSScriptRoot
$matlabPath='D:\MATLAB 2022a\bin\matlab.exe'
$logs=Join-Path $experimentRoot 'results\execution_logs'
if (-not (Test-Path -LiteralPath $logs)) { New-Item -Path $logs -ItemType Directory | Out-Null }
if ($TableDiagnostic) {
    $tag='table_iv_32'
    $targets=@(Join-Path $experimentRoot 'results\table_iv_v5_O32\table_iv.mat')
    $calculation="r=run_strict_table_iv(Overpasses=32,MaximumPacketsPerCall=$MaximumPacketPositions); disp(r.status);"
} else {
    if ($ConditionIndices.Count -eq 0 -or ($ConditionIndices | Where-Object { $_ -lt 1 -or $_ -gt 10 })) {
        throw 'Select disjoint formal condition indices from 1 through 10.'
    }
    $tag='conditions_'+($ConditionIndices -join '_')
    $snrs=@(0,-5,-10,-15,-20)
    $targets=@(foreach ($condition in $ConditionIndices) {
        $cr=1; if ($condition -gt 5) { $cr=4 }
        $snr=$snrs[($condition-1)%5]
        $snrTag=$snr.ToString('+0;-0;0'); if ($snr -eq 0) { $snrTag='+0' }
        Join-Path $experimentRoot "results\full_phy_v5_O3000_Pall_S0_-5_-10_-15_-20\CR${cr}_SNR${snrTag}\cell.mat"
    })
    $indices=$ConditionIndices -join ' '
    $calculation="r=run_strict_full_phy(ConditionIndices=[$indices].',MaximumBatchesPerCall=$MaximumBatches); disp(r.status);"
}
$matlabRoot=$experimentRoot.Replace('\','/')
$expression="maxNumCompThreads(2); addpath('$matlabRoot'); strictPaperSetup; $calculation"
$attempt=0;$consecutiveFailures=0
$runId=[datetimeoffset]::Now.ToString('yyyyMMdd_HHmmss_fff')
if ($WaitForIndices.Count -gt 0) {
    if ($TableDiagnostic -or ($WaitForIndices | Where-Object {$_ -lt 1 -or $_ -gt 10}) -or
        ($WaitForIndices | Where-Object {$_ -in $ConditionIndices})) {
        throw 'Invalid condition prerequisites.'
    }
    $prerequisites=@(foreach($condition in $WaitForIndices) {
        $cr=1;if($condition -gt 5){$cr=4}
        $snr=$snrs[($condition-1)%5]
        $snrTag=$snr.ToString('+0;-0;0');if($snr -eq 0){$snrTag='+0'}
        Join-Path $experimentRoot "results\full_phy_v5_O3000_Pall_S0_-5_-10_-15_-20\CR${cr}_SNR${snrTag}\cell.mat"
    })
    Write-Output "$tag queued after conditions $($WaitForIndices -join ',')."
    while (@($prerequisites | Where-Object { -not (Test-Path -LiteralPath $_) }).Count -gt 0) {
        Start-Sleep -Seconds 30
    }
}
while (@($targets | Where-Object { -not (Test-Path -LiteralPath $_) }).Count -gt 0) {
    $attempt++
    $outPath=Join-Path $logs ($tag+'_'+$runId+'_attempt_'+$attempt+'.out.log')
    $errPath=Join-Path $logs ($tag+'_'+$runId+'_attempt_'+$attempt+'.err.log')
    $process=Start-Process -FilePath $matlabPath -ArgumentList @('-batch',('"'+$expression+'"')) `
        -WindowStyle Hidden -PassThru -RedirectStandardOutput $outPath -RedirectStandardError $errPath
    $record=[ordered]@{status='RUNNING';attempt=$attempt;pid=$process.Id;tag=$tag;targets=$targets;runId=$runId;maximumBatches=$MaximumBatches}
    $record | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $logs ($tag+'_state.json')) -Encoding UTF8
    $process.WaitForExit();$process.Refresh()
    if ($process.ExitCode -eq 0) { $consecutiveFailures=0 } else { $consecutiveFailures++ }
    Write-Output "$tag attempt $attempt exit=$($process.ExitCode), retryFailures=$consecutiveFailures"
    if ($consecutiveFailures -ge 3) { throw "Three consecutive process failures; inspect $errPath." }
}
[ordered]@{status='CELLS_WRITTEN';attempts=$attempt;tag=$tag;targets=$targets} |
    ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $logs ($tag+'_state.json')) -Encoding UTF8
Write-Output "$tag complete; calculation signatures and formal aggregation must still be audited."
