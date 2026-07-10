param(
    [string]$Version = "5.3.2",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$BuilderRoot = Join-Path $ProjectRoot "tools\puzzle_catalog_builder"
$LibDirectory = Join-Path $BuilderRoot "lib"
$TargetDll = Join-Path $LibDirectory "objectbox.dll"

if ((Test-Path $TargetDll) -and -not $Force) {
    Write-Host "ObjectBox native library already present: $TargetDll"
    return
}

$architecture = switch ($env:PROCESSOR_ARCHITECTURE.ToUpperInvariant()) {
    "AMD64" { "x64" }
    "ARM64" { "arm64" }
    "X86" { "x86" }
    default { throw "Unsupported Windows architecture: $env:PROCESSOR_ARCHITECTURE" }
}

$archiveName = "objectbox-windows-$architecture.zip"
$url = "https://github.com/objectbox/objectbox-c/releases/download/v$Version/$archiveName"
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) `
    "better-puzzles-objectbox-$Version-$architecture"
$archive = Join-Path $tempRoot $archiveName
$extract = Join-Path $tempRoot "extract"

if (Test-Path $tempRoot) {
    Remove-Item $tempRoot -Recurse -Force
}
New-Item $tempRoot -ItemType Directory | Out-Null

try {
    Write-Host "Downloading ObjectBox C library $Version for Windows $architecture"
    Invoke-WebRequest -Uri $url -OutFile $archive
    Expand-Archive -Path $archive -DestinationPath $extract -Force

    $sourceDll = Get-ChildItem $extract -Recurse -Filter "objectbox.dll" |
        Select-Object -First 1
    if ($null -eq $sourceDll) {
        throw "objectbox.dll was not found in $archiveName"
    }

    New-Item $LibDirectory -ItemType Directory -Force | Out-Null
    Copy-Item $sourceDll.FullName $TargetDll -Force
    Write-Host "Installed: $TargetDll"
}
finally {
    if (Test-Path $tempRoot) {
        Remove-Item $tempRoot -Recurse -Force
    }
}
