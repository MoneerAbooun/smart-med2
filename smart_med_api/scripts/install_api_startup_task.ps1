param(
    [string]$TaskName = "SmartMedApiServer",
    [string]$HostAddress = "0.0.0.0",
    [int]$Port = 8000
)

$ErrorActionPreference = "Stop"

$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDirectory
$RunScript = Join-Path $ScriptDirectory "run_api_server.ps1"
$PowerShellPath = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"

if (-not (Test-Path -LiteralPath $RunScript)) {
    throw "Could not find server runner at $RunScript"
}

$ActionArguments = @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    "`"$RunScript`"",
    "-HostAddress",
    "`"$HostAddress`"",
    "-Port",
    $Port.ToString()
) -join " "

$Action = New-ScheduledTaskAction `
    -Execute $PowerShellPath `
    -Argument $ActionArguments `
    -WorkingDirectory $ProjectRoot

$Trigger = New-ScheduledTaskTrigger -AtLogOn

$Settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -RestartCount 999 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $Action `
    -Trigger $Trigger `
    -Settings $Settings `
    -Description "Runs the Smart Med FastAPI server at Windows logon." `
    -Force | Out-Null

Start-ScheduledTask -TaskName $TaskName

Write-Host "Installed and started scheduled task: $TaskName"
Write-Host "API URL: http://127.0.0.1:$Port"
Write-Host "Log file: $(Join-Path $ProjectRoot 'logs\api-server.log')"
