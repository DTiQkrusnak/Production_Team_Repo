package main

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"os"
)

const DI_IMPORT_URL string = "https://data-us-ps1.go360iq.com/EZ360DataInterface_SedonaSync/api/ExternalIntegrations/MergeDTTLocations"

func import_locations(client *http.Client, content ImportLocationsContent) {

	buf, err := json.Marshal(content)
	check(err)

	reader := bytes.NewReader(buf)
	response_encoded, err := client.Post(DI_IMPORT_URL, "application/json", reader)
	check(err)

	response, err := io.ReadAll(response_encoded.Body)
	check(err)

	err = os.WriteFile("./DI_output.json", response, 0644)
	check(err)
}
