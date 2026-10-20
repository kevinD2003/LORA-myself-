param([ValidateSet('validation100','formal1000')][string]$Cohort='validation100', [ValidateRange(1,4)][int]$Workers=4)
$ErrorActionPreference='Stop'
$experimentRoot=$PSScriptRoot
$matlabExe='D:\MATLAB 2022a\bin\matlab.exe'
if (-not (Test-Path -LiteralPath (Join-Path $experimentRoot 'POINTS.json'))) { throw 'Export POINTS.json with acExportPlan first.' }
$runDirectory=Join-Path $experimentRoot ('results\'+$Cohort)
New-Item -ItemType Directory -Path $runDirectory -Force | Out-Null
$jobs=foreach ($shard in 1..$Workers) {
    $log=Join-Path $runDirectory ('SHARD_'+$shard+'.log')
    $matlabRoot=$experimentRoot.Replace('\','/').Replace("'","''")
    $statement="addpath('$matlabRoot'); runAcShard($shard,$Workers,'$Cohort');"
    $arguments=@('-batch',('"'+$statement+'"'),'-logfile',('"'+$log+'"'))
    $process=Start-Process -FilePath $matlabExe -ArgumentList $arguments -WindowStyle Hidden -PassThru
    [pscustomobject]@{shard=$shard;pid=$process.Id;log=$log;startedUtc=[DateTime]::UtcNow.ToString('o')}
}
$jobs | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $runDirectory 'LAUNCH.json') -Encoding utf8
$jobs | Format-Table
