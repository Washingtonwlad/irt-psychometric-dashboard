param(
    [string]$RHome = "C:\Program Files\R\R-4.3.3"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $RHome)) {
    throw "R installation not found at: $RHome"
}

$env:R_HOME = $RHome
$env:Path = "$RHome\bin\x64;$RHome\bin;$env:Path"

Write-Host "R_HOME=$env:R_HOME"
Write-Host ""

Write-Host "Rscript:"
Rscript --version

Write-Host ""
Write-Host "Required R packages:"
Rscript -e "pkgs <- c('shiny','bslib','DT','mirt','dplyr','ggplot2','tidyr','haven','gridExtra','knitr','rmarkdown'); print(data.frame(package=pkgs, installed=sapply(pkgs, requireNamespace, quietly=TRUE)), row.names=FALSE)"

Write-Host ""
Write-Host "Quarto:"
quarto check
