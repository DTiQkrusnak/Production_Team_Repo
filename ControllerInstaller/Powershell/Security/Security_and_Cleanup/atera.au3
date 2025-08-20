Opt("TrayAutoPause", 0)

$WarningWindowName = "Atera - Security Warning"
$msiCommand = "msiexec.exe /i C:\ProgramData\DTiQ\TaskScheduler\ateraInstall\setup_final.msi IntegratorLogin=atera.update@dttusa.com CompanyId=" & $CmdLine[1]
Run($msiCommand)
$WarningWindow = WinWait($WarningWindowName)
$button = ControlGetHandle($WarningWindow, "", "Button1")
While ( WinExists($WarningWindow) )
	ControlClick($WarningWindow, "", $button)
	Sleep(20)
	ControlClick($WarningWindow, "", $button)
	Sleep(20)
	ControlClick($WarningWindow, "", $button)
	Sleep(20)
WEnd
GuiDelete()
Exit