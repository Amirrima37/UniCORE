$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot/../..").Path
$cache = Join-Path $root '.tools/engines'
New-Item -ItemType Directory -Force $cache | Out-Null
$archive = Join-Path $cache 'gmsh.zip'
if (!(Test-Path -LiteralPath $archive)) {
    Invoke-WebRequest 'https://gmsh.info/bin/Windows/gmsh-4.15.2-Windows64-sdk.zip' -OutFile $archive -TimeoutSec 120
}
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne '7513CC7096E0492AF88EAB8C217F313EE4FB6155A3155723042E2547F55845E8') {
    throw 'Gmsh archive digest mismatch; refusing extraction'
}
Expand-Archive -LiteralPath $archive -DestinationPath $cache -Force
