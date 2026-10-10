param(
    [int]$WaitForPid = 22748,
    [int]$FrameBudget = 500
)

$projectDir = 'D:\codex\Lora(eg)\project\orbit_doppler\satellite_fig3_rolling8'
$resultDir = Join-Path $projectDir 'results\stage26_formal_ber'
$matlabExe = 'E:\Matlab2022\MATLAB2022\bin\matlab.exe'
$workerLog = Join-Path $resultDir ("worker_{0}frames.log" -f $FrameBudget)
$queueLog = Join-Path $resultDir 'worker_queue.log'

Add-Content -LiteralPath $queueLog -Value `
    "$(Get-Date -Format o) waiting for MATLAB PID $WaitForPid"
Wait-Process -Id $WaitForPid -ErrorAction SilentlyContinue
Start-Sleep -Seconds 5

$batchCommand = "cd('$projectDir'); run_stage26_formal_ber(" + `
    "FrameBudgetThisCall=$FrameBudget," + `
    "OutputFolderName='stage26_formal_ber',Resume=true);"
$worker = Start-Process -FilePath $matlabExe -ArgumentList `
    '-logfile', "`"$workerLog`"", '-batch', "`"$batchCommand`"" `
    -WindowStyle Hidden -PassThru
Add-Content -LiteralPath $queueLog -Value `
    ("$(Get-Date -Format o) started MATLAB launcher PID $($worker.Id) " + `
    "with frame budget $FrameBudget")
