param(
    [string]$RHome = "C:\Program Files\R\R-4.3.3"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $RHome)) {
    throw "R installation not found at: $RHome"
}

$env:R_HOME = $RHome
$env:Path = "$RHome\bin\x64;$RHome\bin;$env:Path"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

Rscript "scripts\build_cache.R"
