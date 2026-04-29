param(
    [string]$HostAddress = "0.0.0.0",
    [int]$Port = 8000,
    [int]$RestartDelaySeconds = 5,
    [switch]$NoRestart
)

$ErrorActionPreference = "Stop"

$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDirectory
$VenvPythonPath = Join-Path $ProjectRoot ".venv\Scripts\python.exe"
$LogDirectory = Join-Path $ProjectRoot "logs"
$LogFile = Join-Path $LogDirectory "api-server.log"
$StdoutLogFile = Join-Path $LogDirectory "api-server.stdout.log"
$StderrLogFile = Join-Path $LogDirectory "api-server.stderr.log"

New-Item -ItemType Directory -Force -Path $LogDirectory | Out-Null
Set-Location $ProjectRoot

function Write-ServerLog {
    param([string]$Message)

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$Timestamp] $Message" | Tee-Object -FilePath $LogFile -Append
}

function Test-PythonHasUvicorn {
    param([string]$PythonCandidate)

    $PreviousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    try {
        & $PythonCandidate -c "import uvicorn" *> $null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    } finally {
        $ErrorActionPreference = $PreviousErrorActionPreference
    }
}

if ((Test-Path -LiteralPath $VenvPythonPath) -and (Test-PythonHasUvicorn $VenvPythonPath)) {
    $PythonPath = $VenvPythonPath
} elseif (Test-PythonHasUvicorn "python") {
    $PythonPath = "python"
} else {
    throw "Could not find a Python environment with uvicorn installed. Run: pip install -r requirements.txt"
}

Write-ServerLog "Using Python command: $PythonPath"

while ($true) {
    Write-ServerLog "Starting Smart Med API on ${HostAddress}:$Port"

    $UvicornArgs = @(
        "-m",
        "uvicorn",
        "app.main:app",
        "--host",
        $HostAddress,
        "--port",
        $Port.ToString()
    )

    $ServerProcess = Start-Process `
        -FilePath $PythonPath `
        -ArgumentList $UvicornArgs `
        -WorkingDirectory $ProjectRoot `
        -NoNewWindow `
        -PassThru `
        -Wait `
        -RedirectStandardOutput $StdoutLogFile `
        -RedirectStandardError $StderrLogFile

    $ExitCode = $ServerProcess.ExitCode

    Write-ServerLog "Smart Med API stopped with exit code $ExitCode"

    if ($NoRestart) {
        exit $ExitCode
    }

    Write-ServerLog "Restarting in $RestartDelaySeconds seconds"
    Start-Sleep -Seconds $RestartDelaySeconds
}
