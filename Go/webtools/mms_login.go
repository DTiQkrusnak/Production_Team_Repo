package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"net/http/cookiejar"
)

var MMSloginEndpointQA string = ""
var MMSloginEndpoint string = "https://mmsrc.go360iq.com/api/account/Login"

func LoginMMS(username string, password string, isQAenv bool) (*http.Client, error) {
	jar, err := cookiejar.New(nil)
	if err != nil {
		log.Println(err)
	}

	client := &http.Client{
		Jar: jar,
	}

	prepared_login_payload := web_login_payload{
		Password:     password,
		Login:        username,
		IsPersistent: false,
	}

	var buf bytes.Buffer
	err = json.NewEncoder(&buf).Encode(prepared_login_payload)
	if err != nil {
		log.Println(err)
	}
	var response *http.Response
	if isQAenv {
		response, err = client.Post(MMSloginEndpointQA, "application/json", &buf)
	} else {
		response, err = client.Post(MMSloginEndpoint, "application/json", &buf)
	}

	if err != nil {
		log.Println(err)
	}

	defer response.Body.Close()

	var web_response_json web_login_response
	json.NewDecoder(response.Body).Decode(&web_response_json)

	if web_response_json.IsSuccessfull {
		log.Println("MMS logged in")
		return client, nil
	}

	return nil, errors.New("cannot login to WEB")
}
