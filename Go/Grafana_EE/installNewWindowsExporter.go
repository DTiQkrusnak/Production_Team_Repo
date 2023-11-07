package main

import (
	"os"
	"os/exec"
)

func installNewWindowsExporter() {
	// Setup variables
	var enabled_collectors string = "ENABLED_COLLECTORS=cpu,cs,logical_disk,memory,process,service,os"
	var windows_exporter_package_name string = "windows_exporter-0.22.0-amd64.msi"

	path, err := os.Getwd()
	CheckErrorPanic("Cannot get working directory", err)

	err = exec.Command("msiexec", "/qn", "/quiet", "/i", path+"\\resources\\"+windows_exporter_package_name, enabled_collectors).Run()
	CheckErrorPanic("Cannot install windows exporter", err)

	// Runs when everything else finishes before closing function
	defer routinesWaitGroup.Done()
}
