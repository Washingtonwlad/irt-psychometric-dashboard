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

quarto render "analysis\irt_analysis.qmd" --to html

New-Item -ItemType Directory -Force "docs" | Out-Null
Copy-Item "analysis\irt_analysis.html" "docs\index.html" -Force
Copy-Item "analysis\irt_analysis_files" "docs\irt_analysis_files" -Recurse -Force

if (-not (Test-Path "docs\.nojekyll")) {
    Set-Content -Path "docs\.nojekyll" -Value "Static Quarto output for GitHub Pages." -Encoding UTF8
}

Write-Host "Report rendered and copied to docs/ for GitHub Pages."
