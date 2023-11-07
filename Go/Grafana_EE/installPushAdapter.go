package main

import (
	"encoding/json"
	"io"
	"log"
	"os"
	"os/exec"
	"strings"
	"time"

	"golang.org/x/exp/slices"
	"golang.org/x/sys/windows/registry"
	"golang.org/x/sys/windows/svc/mgr"
)

func readInstanceNameFromRegistry() string {
	var instance_name string = ""

	controllerInstallerRegistryKey, err := registry.OpenKey(registry.LOCAL_MACHINE, `SOFTWARE\EZUniverse\EZ360ControllerInstaller`, registry.QUERY_VALUE)
	CheckErrorPanic("Cannot get Controller Installer registry key", err)
	defer controllerInstallerRegistryKey.Close()
	instance_name, _, err = controllerInstallerRegistryKey.GetStringValue("LocationName")
	CheckErrorPanic("Cannot query Controller Installer registry", err)

	// Sanitize Instance name for PushGateway adapter, it cannot accept spaces
	instance_name = strings.ReplaceAll(instance_name, " ", "")
	log.Println("Refactored instance name: ", instance_name)
	return instance_name
}

func createPushAdapterJsonConfiguration(instanceName *string) {
	configuration_template := "resources/appsettings.json"
	configuration_write_path := "resources/adapter-x64/appsettings.json"

	f, err := os.Open(configuration_template)
	CheckErrorPanic("Cannot open configuration template", err)

	config_example_data, err := io.ReadAll(f)
	CheckErrorPanic("Cannot read configuration template", err)

	var configuration_json PushAdapterJsonStruct
	json.Unmarshal(config_example_data, &configuration_json)

	configuration_json.UploadMetricsEndpoint.URL = configuration_json.UploadMetricsEndpoint.URL + *instanceName

	f, err = os.Create(configuration_write_path)
	CheckErrorPanic("Cannot create config file", err)

	config_json_marshaled, err := json.MarshalIndent(configuration_json, "", "	")
	CheckErrorPanic("Cannot marshal configuration", err)

	_, err = f.Write(config_json_marshaled)
	CheckErrorPanic("Cannot write to config file", err)
}

func registerPushAdapterWindowsService(serviceManager *mgr.Mgr) {
	nssm_path := "resources/adapter-x64/nssm.exe"
	servicesList, err := serviceManager.ListServices()
	CheckErrorPanic("Cannot get services list", err)

	retryRate := 10
	for slices.Contains(servicesList, "Pushgateway.Adapter") || retryRate == 0 {
		if retryRate > 0 {
			time.Sleep(1 * time.Second)
			retryRate -= 1
			servicesList, err = serviceManager.ListServices()
			CheckErrorPanic("Cannot get services list", err)
			continue
		} else {
			break
		}
	}

	err = exec.Command(nssm_path, "install", "Pushgateway.Adapter", "Pushgateway.Adapter.exe").Run()
	CheckErrorPanic("Cannot register Push Adapter service with nssm", err)

	err = exec.Command(nssm_path, "start", "Pushgateway.Adapter").Run()
	CheckErrorPanic("Cannot start push adapter service", err)
}

// JSON struct to store PushAdapter configuration
type PushAdapterJsonStruct struct {
	ScrapeMetricsURL      string `json:"ScrapeMetricsUrl"`
	UploadMetricsEndpoint struct {
		URL                         string `json:"Url"`
		UseBasicAuth                bool   `json:"UseBasicAuth"`
		Username                    string `json:"Username"`
		Password                    string `json:"Password"`
		AllowInsecureSslCertificate bool   `json:"AllowInsecureSslCertificate"`
	} `json:"UploadMetricsEndpoint"`
	Interval        string `json:"Interval"`
	AllowedPatterns []struct {
		AllowedMetricsPattern string `json:"AllowedMetricsPattern"`
		AllowedLabelsPattern  string `json:"AllowedLabelsPattern,omitempty"`
	} `json:"AllowedPatterns"`
}
