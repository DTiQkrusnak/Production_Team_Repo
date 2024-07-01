package main

import (
	"encoding/json"
	"log"
	"os"
	"path/filepath"
)

type DI_LOGIN_JSON struct {
	LOGIN    string `json:"DI_LOGIN"`
	PASSWORD string `json:"DI_PASSWORD"`
}

func check(err error) {
	if err != nil {
		log.Panicln(err)
	}
}

func read_DI_crentials(path_to_DI_creds string) DI_LOGIN_JSON {
	path := filepath.FromSlash(path_to_DI_creds)
	data, err := os.ReadFile(path)
	check(err)

	var DI_login_data DI_LOGIN_JSON
	err = json.Unmarshal(data, &DI_login_data)
	check(err)

	return DI_login_data
}
