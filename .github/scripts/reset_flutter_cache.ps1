$ErrorActionPreference = 'Stop'

function Remove-RemoteCache {
    param([Parameter(Mandatory)][string]$Key)

    if ([string]::IsNullOrWhiteSpace($env:GITHUB_REPOSITORY)) {
        throw 'GITHUB_REPOSITORY is not available.'
    }

    $encodedKey = [Uri]::EscapeDataString($Key)
    Write-Host "Deleting remote cache key: $Key"
    & gh api `
        --method DELETE `
        --silent `
        "repos/$env:GITHUB_REPOSITORY/actions/caches?key=$encodedKey"

    if ($LASTEXITCODE -ne 0) {
        throw "GitHub could not delete cache key '$Key'."
    }
}

function Test-PathInsideRoot {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Root
    )

    $fullPath = [IO.Path]::GetFullPath($Path)
    $fullRoot = [IO.Path]::GetFullPath($Root)
    $separator = [IO.Path]::DirectorySeparatorChar
    $rootPrefix = $fullRoot.TrimEnd($separator, [IO.Path]::AltDirectorySeparatorChar) + $separator

    return $fullPath.StartsWith(
        $rootPrefix,
        [StringComparison]::OrdinalIgnoreCase
    )
}

function Remove-LocalCache {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string[]]$AllowedRoots
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw 'Refusing to remove an empty cache path.'
    }

    $isAllowed = $false
    foreach ($root in $AllowedRoots) {
        if (-not [string]::IsNullOrWhiteSpace($root) -and
            (Test-PathInsideRoot -Path $Path -Root $root)) {
            $isAllowed = $true
            break
        }
    }

    if (-not $isAllowed) {
        throw "Refusing to remove cache path outside runner-owned roots: $Path"
    }

    if (Test-Path -LiteralPath $Path) {
        Write-Host "Removing local cache path: $Path"
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
}

$requiredValues = @(
    'FLUTTER_CACHE_KEY',
    'PUB_CACHE_KEY',
    'FLUTTER_CACHE_PATH',
    'PUB_CACHE_PATH'
)

foreach ($name in $requiredValues) {
    $value = [Environment]::GetEnvironmentVariable($name)
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Required environment value '$name' is missing."
    }
}

Remove-RemoteCache -Key $env:FLUTTER_CACHE_KEY
Remove-RemoteCache -Key $env:PUB_CACHE_KEY

$allowedRoots = @(
    $env:RUNNER_TOOL_CACHE,
    $env:HOME,
    $env:USERPROFILE,
    $env:LOCALAPPDATA
) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

Remove-LocalCache -Path $env:FLUTTER_CACHE_PATH -AllowedRoots $allowedRoots
Remove-LocalCache -Path $env:PUB_CACHE_PATH -AllowedRoots $allowedRoots

Write-Host 'Flutter and pub caches are ready for a clean rebuild.'
