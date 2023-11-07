package main

import (
	"flag"
	"log"
	"os"
	"sync"
)

var routinesWaitGroup sync.WaitGroup

func main() {

	// Read current working directory
	removeOldComponents := flag.Bool("remove", false, "Remove old components")
	installNewComponents := flag.Bool("install", false, "Install new components")
	flag.Parse()

	// Check Admin elevation
	if !checkForAdmin() {
		log.Println("Please run with admin privileges")
		os.Exit(0)
	}

	serviceManager := createServiceManager()
	defer serviceManager.Disconnect()

	// Cleanup
	if *removeOldComponents || !*installNewComponents {
		checkComponentsToRemove(serviceManager)
		log.Println("Cleanup Successful")
	}

	// Installation
	if *installNewComponents || !*removeOldComponents {
		routinesWaitGroup.Add(1)
		go installNewWindowsExporter()
		instanceName := readInstanceNameFromRegistry()
		createPushAdapterJsonConfiguration(&instanceName)
		registerPushAdapterWindowsService(serviceManager)
		routinesWaitGroup.Wait()
		log.Println("Installation Successful")
	}

}

func checkForAdmin() bool {
	_, err := os.Open("\\\\.\\PHYSICALDRIVE0")
	return err == nil
}
