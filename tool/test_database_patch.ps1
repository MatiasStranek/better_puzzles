$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

flutter analyze

Push-Location "packages\bpuzzles_format"
try {
    dart test
}
finally {
    Pop-Location
}

Push-Location "packages\puzzle_catalog_store"
try {
    dart test
}
finally {
    Pop-Location
}

Push-Location "tools\puzzle_catalog_builder"
try {
    dart test
}
finally {
    Pop-Location
}
