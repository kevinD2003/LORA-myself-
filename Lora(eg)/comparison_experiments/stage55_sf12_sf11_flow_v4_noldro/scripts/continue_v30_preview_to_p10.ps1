$ErrorActionPreference='Stop'
$implementationRoot='D:\codex\Lora(eg)\comparison_experiments\stage55_sf12_sf11_flow_v4_noldro'
Wait-Process -Id 16780 -ErrorAction SilentlyContinue
& 'powershell.exe' -NoProfile -ExecutionPolicy Bypass -File (Join-Path $implementationRoot 'scripts\run_v30_awgn_p10.ps1')
exit $LASTEXITCODE
