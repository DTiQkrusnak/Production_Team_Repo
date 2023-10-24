package main

import (
	"os/exec"

	"golang.org/x/exp/slices"
	"golang.org/x/sys/windows/svc"
	"golang.org/x/sys/windows/svc/mgr"
)

func removeOldWmiExporter() {
	var wmiExporterPackageCode string = "{1F2534DC-9E6D-4E81-A97E-DEEABFC23FA4}"

	err := exec.Command("msiexec", "/quiet", "/qn", "/x", wmiExporterPackageCode).Run()
	CheckErrorPanic("Cannot uninstall Wmi exporter", err)

	defer routinesWaitGroup.Done()
}

func removeOldWindowsExporter() {
	var windowsExporterPackageCode string = "{BD9E3EB7-9041-481B-B5FC-B45557A80398}"

	err := exec.Command("msiexec", "/quiet", "/qn", "/x", windowsExporterPackageCode).Run()
	CheckErrorPanic("Cannot uninstall windows_exporter", err)

	defer routinesWaitGroup.Done()
}

func checkComponentsToRemove(serviceManager *mgr.Mgr) {
	servicesList, err := serviceManager.ListServices()
	CheckErrorPanic("Cannot list services", err)

	if slices.Contains(servicesList, "Pushgateway.Adapter") {
		pushGatewayService, err := serviceManager.OpenService("Pushgateway.Adapter")
		CheckErrorPanic("Cannot open Pushgateway.Adapter service to delete it", err)

		status, err := pushGatewayService.Control(svc.Stop)
		if status.State != svc.Stopped {
			CheckErrorPanic("Cannot stop Pushgateway.Adapter service", err)
		}

		err = pushGatewayService.Delete()
		CheckErrorPanic("Cannot delete Pushgateway.Adapter", err)
		err = pushGatewayService.Close()
		CheckErrorPanic("Cannot close service handle", err)
	}

	if slices.Contains(servicesList, "Wmi exporter") {
		routinesWaitGroup.Add(1)
		go removeOldWmiExporter()
	}

	if slices.Contains(servicesList, "windows_exporter") {
		routinesWaitGroup.Add(1)
		go removeOldWindowsExporter()
	}

	routinesWaitGroup.Wait()
}
