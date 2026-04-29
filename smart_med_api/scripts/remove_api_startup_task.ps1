param(
    [string]$TaskName = "SmartMedApiServer"
)

$ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

if ($null -eq $ExistingTask) {
    Write-Host "Scheduled task not found: $TaskName"
    exit 0
}

Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false

Write-Host "Removed scheduled task: $TaskName"
