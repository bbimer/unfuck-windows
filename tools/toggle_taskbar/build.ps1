$ErrorActionPreference = "Stop"
$csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not (Test-Path $csc)) {
    throw "C# compiler csc.exe not found at $csc"
}
& $csc /target:winexe /optimize+ /platform:anycpu /out:"$PSScriptRoot\toggle_taskbar.exe" "$PSScriptRoot\Program.cs"

