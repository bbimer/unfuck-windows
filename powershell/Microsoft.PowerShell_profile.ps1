# UTF-8 Encoding (In-process .NET)
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$env:PYTHONUTF8 = "1"

# Banner
try { Clear-Host } catch {}
fastfetch

# Oh My Posh initialization with persistent compiled cache
$ompCache = "$env:LOCALAPPDATA\oh-my-posh\omp_fast_init.ps1"

if (-not (Test-Path -LiteralPath $ompCache)) {
    $ompTheme = "$env:POSH_THEMES_PATH\wholespace.omp.json"
    $ompCacheDir = "$env:LOCALAPPDATA\oh-my-posh"
    if (-not (Test-Path -LiteralPath $ompCacheDir)) {
        New-Item -ItemType Directory -Path $ompCacheDir -Force | Out-Null
    }
    $rawPrint = (& oh-my-posh init pwsh --config $ompTheme --print | Out-String).Trim()
    if ($rawPrint -match "'([^']+)'") {
        $raw = Get-Content -LiteralPath $Matches[1] -Raw
        $raw = $raw.Replace('(& $global:_ompExecutable get uuid)', '[System.Guid]::NewGuid().ToString()')
        $raw = $raw.Replace('((Invoke-Utf8Posh @("print", "secondary", "--shell=$script:ShellName")) -join "`n")', "'> '")
        Set-Content -LiteralPath $ompCache -Value $raw -Encoding utf8
    }
}

if (Test-Path -LiteralPath $ompCache) {
    . $ompCache
} else {
    oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\wholespace.omp.json" | Invoke-Expression
}
