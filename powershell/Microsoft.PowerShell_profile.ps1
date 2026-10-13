# UTF-8 Encoding
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
chcp 65001 > $null
$env:PYTHONUTF8 = "1"

# Clear host and show fastfetch banner
Clear-Host
if (Get-Command fastfetch -ErrorAction SilentlyContinue) {
    fastfetch
}

# Oh My Posh initialization (wholespace theme)
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\wholespace.omp.json" | Invoke-Expression
}
