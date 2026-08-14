param(
    [Parameter(Mandatory)][string]$ExpectedVersion,
    [Parameter(Mandatory)]
    [ValidateSet('android', 'windows')]
    [string]$PrecachePlatform
)

$ErrorActionPreference = 'Stop'

$versionJson = & flutter --version --machine
if ($LASTEXITCODE -ne 0) {
    throw 'Flutter could not report its version.'
}

$version = $versionJson | ConvertFrom-Json
if ($version.frameworkVersion -ne $ExpectedVersion) {
    throw "Expected Flutter $ExpectedVersion but restored $($version.frameworkVersion)."
}

& dart --version
if ($LASTEXITCODE -ne 0) {
    throw 'The Dart executable in the Flutter cache is not healthy.'
}

& flutter precache "--$PrecachePlatform"
if ($LASTEXITCODE -ne 0) {
    throw "Flutter could not validate $PrecachePlatform engine artifacts."
}

& flutter doctor -v
if ($LASTEXITCODE -ne 0) {
    throw 'Flutter doctor reported an unusable SDK cache.'
}

Write-Host "Flutter $ExpectedVersion and $PrecachePlatform artifacts are healthy."
