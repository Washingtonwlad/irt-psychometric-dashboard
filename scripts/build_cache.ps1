param(
    [string]$RHome = ""
)

$ErrorActionPreference = "Stop"

function Resolve-FirstExistingPath {
    param([string[]]$Candidates)

    foreach ($candidate in $Candidates) {
        if ($candidate -and (Test-Path $candidate)) {
            return (Resolve-Path $candidate).Path
        }
    }

    return $null
}

if (-not $RHome) {
    $RHome = Resolve-FirstExistingPath @(
        "D:\Washington\Programas\R\R-4.5.2",
        "C:\Program Files\R\R-4.5.2",
        "C:\Program Files\R\R-4.3.3"
    )
}

if (-not (Test-Path $RHome)) {
    throw "R installation not found at: $RHome"
}

$env:R_HOME = $RHome
$env:Path = "$RHome\bin\x64;$RHome\bin;$env:Path"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

& (Join-Path $RHome "bin\Rscript.exe") "scripts\build_cache.R"
