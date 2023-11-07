package main

import "golang.org/x/sys/windows/svc/mgr"

func createServiceManager() *mgr.Mgr {
	serviceManager, err := mgr.Connect()
	CheckErrorPanic("Cannot create service manager", err)
	return serviceManager
}
