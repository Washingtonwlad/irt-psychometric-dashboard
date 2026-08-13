param(
    [string]$RHome = "",
    [string]$QuartoBin = ""
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

if (-not $QuartoBin) {
    $QuartoBin = Resolve-FirstExistingPath @(
        "D:\Washington\Programas\Positron\Positron\resources\app\quarto\bin\quarto.exe",
        "D:\Washington\Programas\RStudio\resources\app\bin\quarto\bin\quarto.exe",
        "C:\Program Files\Quarto\bin\quarto.exe"
    )
}

if (-not $QuartoBin) {
    throw "Quarto executable not found. Pass -QuartoBin with the path to quarto.exe."
}

$env:Path = "$(Split-Path $QuartoBin -Parent);$env:Path"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

# Use Quarto's normal per-user cache (do NOT redirect LOCALAPPDATA into the
# project). Redirecting it to a project-local folder made rendering fragile:
# clearing or deleting that folder left Quarto unable to resolve its compiled
# syntax-highlighting assets. Reset it explicitly in case a prior run in the
# same shell left the variable pointing elsewhere.
$env:LOCALAPPDATA = Join-Path $env:USERPROFILE "AppData\Local"

& $QuartoBin render "analysis\irt_analysis.qmd" --to html
if ($LASTEXITCODE -ne 0) {
    throw "Quarto render failed with exit code $LASTEXITCODE."
}

New-Item -ItemType Directory -Force "docs" | Out-Null
Copy-Item "analysis\irt_analysis.html" "docs\index.html" -Force

if (Test-Path "docs\irt_analysis_files") {
    Remove-Item "docs\irt_analysis_files" -Recurse -Force
}

Copy-Item "analysis\irt_analysis_files" "docs\irt_analysis_files" -Recurse -Force

if (-not (Test-Path "docs\.nojekyll")) {
    Set-Content -Path "docs\.nojekyll" -Value "Static Quarto output for GitHub Pages." -Encoding UTF8
}

Write-Host "Report rendered and copied to docs/ for GitHub Pages."
