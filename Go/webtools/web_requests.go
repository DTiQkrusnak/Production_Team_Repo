package main

import (
	"bytes"
	"encoding/json"
	"log"
	"net/http"
)

type verificationResponse struct {
	IsSuccesfull bool `json:"IsSuccesfull"`
	Value        bool `json:"Value"`
}

func verifyEmail(client *http.Client, email string, isQAenv bool) bool {
	var verifyEmailEndpointQA string = "https://ezusrvpl-dev10.go360iq.com/QA/EZ360iQWeb/api/Users/IsEmailInUse"
	var verifyEmailEndpoint string = "https://app.go360iq.com/api/Users/IsEmailInUse"

	var buf bytes.Buffer
	err := json.NewEncoder(&buf).Encode(email)
	if err != nil {
		log.Println(err)
	}
	var response *http.Response
	if isQAenv {
		response, err = client.Post(verifyEmailEndpointQA, "application/json", &buf)
	} else {
		response, err = client.Post(verifyEmailEndpoint, "application/json", &buf)
	}
	if err != nil {
		log.Println(err)
	}

	defer response.Body.Close()

	var verification_response verificationResponse
	json.NewDecoder(response.Body).Decode(&verification_response)

	if verification_response.IsSuccesfull && !verification_response.Value {
		return true
	}
	return false
}

func verifyUsername(client *http.Client, username string, isQAenv bool) bool {
	var verifyUsernameEndpointQA string = "https://ezusrvpl-dev10.go360iq.com/QA/EZ360iQWeb/api/Users/IsUserNameTaken"
	var verifyUsernameEndpoint string = "https://app.go360iq.com/api/Users/IsUserNameTaken"

	var buf bytes.Buffer
	err := json.NewEncoder(&buf).Encode(username)
	if err != nil {
		log.Println(err)
	}

	var response *http.Response
	if isQAenv {
		response, err = client.Post(verifyUsernameEndpointQA, "application/json", &buf)
	} else {
		response, err = client.Post(verifyUsernameEndpoint, "application/json", &buf)
	}
	if err != nil {
		log.Println(err)
	}

	defer response.Body.Close()

	var verification_response verificationResponse
	json.NewDecoder(response.Body).Decode(&verification_response)

	if verification_response.IsSuccesfull && !verification_response.Value {
		return true
	}
	return false
}

func createUser(client *http.Client, user UserInfo, isQAenv bool) {
	var createUserEndpointQA string = "https://ezusrvpl-dev10.go360iq.com/QA/EZ360iQWeb/api/users/AddUser"
	var createUserEndpoint string = "https://app.go360iq.com/api/users/AddUser"

	var buf bytes.Buffer
	err := json.NewEncoder(&buf).Encode(user)
	if err != nil {
		log.Println(err)
	}

	var response *http.Response
	if isQAenv {
		response, err = client.Post(createUserEndpointQA, "application/json", &buf)
	} else {
		response, err = client.Post(createUserEndpoint, "application/json", &buf)
	}
	if err != nil {
		log.Println(err)
	}
	defer response.Body.Close()
	if response.StatusCode == 400 {
		log.Printf("Account with email: %s and username: %s cannot be created. Error during request", user.Email, user.Login)
	}
}
