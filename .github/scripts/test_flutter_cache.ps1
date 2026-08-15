param(
    [Parameter(Mandatory)][string]$ExpectedVersion,
    [Parameter(Mandatory)]
    [ValidateSet('android', 'windows')]
    [string]$PrecachePlatform
)

$ErrorActionPreference = 'Stop'

$versionOutput = (& flutter --version --machine 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0) {
    throw 'Flutter could not report its version.'
}

$jsonStart = $versionOutput.IndexOf('{')
$jsonEnd = $versionOutput.LastIndexOf('}')
if ($jsonStart -lt 0 -or $jsonEnd -le $jsonStart) {
    throw 'Flutter version output did not contain its machine-readable JSON.'
}

$versionJson = $versionOutput.Substring($jsonStart, $jsonEnd - $jsonStart + 1)
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

Write-Host "Flutter $ExpectedVersion and $PrecachePlatform artifacts are healthy."
