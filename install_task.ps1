#Requires -Version 5.1
# One-time setup: registers the Task Scheduler job that runs ship.ps1 every
# 30 minutes while this user is logged in. Run this once, by hand.

$here = $PSScriptRoot
$taskName = "CookieShipper"

$action = New-ScheduledTaskAction -Execute "wscript.exe" `
    -Argument "`"$here\run_hidden.vbs`"" `
    -WorkingDirectory $here

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Minutes 30) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
    -DontStopIfGoingOnBatteries -AllowStartIfOnBatteries

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
    -Settings $settings -Description "Ships YouTube/Google cookies to the cookie_shipper receiver every 30 min while logged in." `
    -Force

Write-Host "Registered scheduled task '$taskName'. It runs only while you are logged in, every 30 minutes."
