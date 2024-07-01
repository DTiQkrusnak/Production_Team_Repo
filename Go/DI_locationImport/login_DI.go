package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/cookiejar"
)

const DI_LOGIN_URL string = "https://data-us-ps1.go360iq.com//EZ360DataInterface_Software/api/Authorization/Login"

type DI_LoginPayload struct {
	Login    string `json:"Login"`
	Passowrd string `json:"Password"`
}

type DI_LoginResponse struct {
	ExpirationDate string `json:"ExpirationDate"`
	UserID         int    `json:"UserId"`
	SessionToken   string `json:"SessionToken"`
}

func DI_login(creds DI_LOGIN_JSON) (*http.Client, DI_LoginResponse) {
	jar, err := cookiejar.New(nil)
	check(err)

	client := &http.Client{
		Jar: jar,
	}

	DI_login_payload := DI_LoginPayload{
		Login:    creds.LOGIN,
		Passowrd: creds.PASSWORD,
	}

	buf, err := json.Marshal(DI_login_payload)
	reader := bytes.NewReader(buf)
	check(err)

	response_encoded, err := client.Post(DI_LOGIN_URL, "application/json", reader)
	check(err)
	defer response_encoded.Body.Close()

	var DI_login_response DI_LoginResponse
	json.NewDecoder(response_encoded.Body).Decode(&DI_login_response)
	check(err)

	return client, DI_login_response
}
