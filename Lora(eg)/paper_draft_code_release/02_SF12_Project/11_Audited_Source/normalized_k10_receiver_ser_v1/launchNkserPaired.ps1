param([ValidateSet(7,12)][int[]]$Sf=@(7,12))
$ErrorActionPreference='Stop'
$experimentRoot=$PSScriptRoot
$matlabExe='D:\MATLAB 2022a\bin\matlab.exe'
$runDirectory=Join-Path $experimentRoot 'results\pairedHalf100'
New-Item -ItemType Directory -Path $runDirectory -Force | Out-Null
$jobs=foreach ($value in $Sf) {
    $log=Join-Path $runDirectory ('SF'+$value+'.log')
    $matlabRoot=$experimentRoot.Replace('\','/').Replace("'","''")
    $statement="addpath('$matlabRoot'); nkserRunPairedHalf($value);"
    $arguments=@('-singleCompThread','-batch',('"'+$statement+'"'),'-logfile',('"'+$log+'"'))
    $process=Start-Process -FilePath $matlabExe -ArgumentList $arguments -WindowStyle Hidden -PassThru
    [pscustomobject]@{sf=$value;pid=$process.Id;log=$log;startedUtc=[DateTime]::UtcNow.ToString('o')}
}
$jobs | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $runDirectory 'LAUNCH.json') -Encoding utf8
$jobs | Format-Table
