package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"net/http/cookiejar"
)

var loginEndpointQA string = "https://ezusrvpl-dev10.go360iq.com/QA/EZ360iQWeb/en-US/Account/Login"
var loginEndpoint string = "https://app.go360iq.com/en-US/Account/Login"

type web_login_payload struct {
	Password     string `json:"password"`
	Login        string `json:"login"`
	IsPersistent bool   `json:"isPersistent"`
}

type web_login_response struct {
	IsSuccessfull bool `json:"IsSuccessfull"`
}

func LoginWebApp(username string, password string, isQAenv bool) (*http.Client, error) {
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
		response, err = client.Post(loginEndpointQA, "application/json", &buf)
	} else {
		response, err = client.Post(loginEndpoint, "application/json", &buf)
	}

	if err != nil {
		log.Println(err)
	}

	defer response.Body.Close()

	var web_response_json web_login_response
	json.NewDecoder(response.Body).Decode(&web_response_json)

	if web_response_json.IsSuccessfull {
		log.Println("WEB logged in")
		return client, nil
	}

	return nil, errors.New("cannot login to WEB")
}
