$ErrorActionPreference='Stop'
$experimentRoot=$PSScriptRoot
$output=Join-Path $experimentRoot 'results\full_phy_v5_O3000_Pall_S0_-5_-10_-15_-20'
$required=@(foreach($cr in @(1,4)){foreach($snr in @(0,-5,-10,-15,-20)){
    $tag=$snr.ToString('+0;-0;0');if($snr -eq 0){$tag='+0'}
    Join-Path $output "CR${cr}_SNR${tag}\cell.mat"
}})
while (@($required | Where-Object {-not (Test-Path -LiteralPath $_)}).Count -gt 0) {
    Start-Sleep -Seconds 30
}
$logs=Join-Path $experimentRoot 'results\execution_logs'
$rootForMatlab=$experimentRoot.Replace('\','/')
$expression="maxNumCompThreads(2);addpath('$rootForMatlab');strictPaperSetup; r=run_strict_full_phy(); report=build_strict_formal_report(); audit=audit_strict_paper_reproduction(); disp(audit.status);"
$process=Start-Process -FilePath 'D:\MATLAB 2022a\bin\matlab.exe' `
    -ArgumentList @('-batch',('"'+$expression+'"')) -WindowStyle Hidden -PassThru `
    -RedirectStandardOutput (Join-Path $logs 'finalization.out.log') `
    -RedirectStandardError (Join-Path $logs 'finalization.err.log')
$process.WaitForExit();$process.Refresh()
if ($process.ExitCode -ne 0) {throw "Formal finalization exited with $($process.ExitCode); inspect logs."}
Write-Output 'Formal aggregation, uncertainty report and required audit completed.'
