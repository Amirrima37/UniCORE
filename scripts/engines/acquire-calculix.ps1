$ErrorActionPreference='Stop'
$root=(Resolve-Path "$PSScriptRoot/../..").Path
$archive=Join-Path $root '.tools/engines/calculix-2.23.zip'
if (!(Test-Path -LiteralPath $archive)) {
    Invoke-WebRequest 'https://raw.githubusercontent.com/calculix/CalculiX-Windows/60c9a10b350ec813f4d493098f47f7a8b96cd276/releases/CalculiX-2.23.0-win-x64.zip' -OutFile $archive -TimeoutSec 120
}
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne '79A674FDEE735A22720BBD12BB9CCBADAD1E8C8AD5B1DE74E1C62F8808B2D395') {throw 'Archive digest mismatch'}
Expand-Archive -LiteralPath $archive -DestinationPath (Join-Path $root '.tools/engines/calculix') -Force
