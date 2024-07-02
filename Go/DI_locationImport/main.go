package main

import (
	"encoding/json"
	"flag"
	"os"
)

func main() {
	var DI_credentials_path = flag.String(
		"creds",
		"./.env",
		"path to DataInterface credentials as specified JSON \n{\n\t\"DI_LOGIN\": \"\",\n\t\"DI_PASSWORD\": \"\"\n}\n")
	var file_with_data_for_import = flag.String(
		"input",
		"./locations.xlsx",
		"path to file with locations data used for import.\nFirst row is ignored because of column headers.\nCOLUMS:\nBrand | Organization | StoreID | LocationName | Address | PostalCode | City | State | Country | RegionCode")
	var generate_just_json_payload = flag.Bool("generate", false, "if set to true, locations will not be imported, instead json payload will be generated in ./output.json file")
	flag.Parse()

	import_locations_content := read_locations_from_file(*file_with_data_for_import)
	if *generate_just_json_payload {
		import_locations_content_as_json, err := json.Marshal(import_locations_content)
		check(err)
		err = os.WriteFile("./output.json", []byte(import_locations_content_as_json), 0644)
		check(err)
		return
	}
	DI_credentials := read_DI_crentials(*DI_credentials_path)
	client, session_information := DI_login(DI_credentials)

	// fmt.Println(client)
	// fmt.Println(session_information)

	import_locations_content.UserID = session_information.UserID
	import_locations_content.SessionToken = session_information.SessionToken
	//import_locations(client, import_locations_content)

	// ! TODO change to read model from string and match ID.
	set_controller_model(client, 8)
}
