' Launches ship.ps1 with no visible window at all (Task Scheduler's
' powershell.exe action otherwise flashes a console on screen).
scriptDir = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\"))
cmd = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & scriptDir & "ship.ps1"""
CreateObject("WScript.Shell").Run cmd, 0, True
