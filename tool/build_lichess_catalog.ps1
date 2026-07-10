param(
    [Parameter(Mandatory = $true)]
    [string]$InputFile,

    [Parameter(Mandatory = $true)]
    [string]$OutputFile,

    [string]$SourceDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd"),
    [string]$Zstd = "zstd",
    [int]$BatchSize = 10000,
    [int]$MaxDbSizeKb = 8388608,
    [Nullable[int]]$Limit = $null,
    [switch]$Strict,
    [switch]$Overwrite,
    [switch]$KeepWork
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$BuilderRoot = Join-Path $ProjectRoot "tools\puzzle_catalog_builder"
$ObjectBoxDll = Join-Path $BuilderRoot "lib\objectbox.dll"

if (-not (Test-Path $ObjectBoxDll)) {
    throw "ObjectBox native library missing. Run .\tool\setup_database_patch.ps1 first."
}

$arguments = @(
    "run",
    "bin\build_catalog.dart",
    "--input", (Resolve-Path $InputFile).Path,
    "--output", [System.IO.Path]::GetFullPath($OutputFile),
    "--source-date", $SourceDate,
    "--zstd", $Zstd,
    "--batch-size", $BatchSize,
    "--max-db-size-kb", $MaxDbSizeKb
)

if ($null -ne $Limit) {
    $arguments += @("--limit", $Limit.Value)
}
if ($Strict) {
    $arguments += "--strict"
}
if ($Overwrite) {
    $arguments += "--overwrite"
}
if ($KeepWork) {
    $arguments += "--keep-work"
}

Push-Location $BuilderRoot
try {
    & dart @arguments
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }
}
finally {
    Pop-Location
}
