package main

import (
	"bytes"
	"log"
	"net/http"
)

func request_sender(client *http.Client, method string, url string, body string) *http.Response {

	BODY_READER := bytes.NewReader([]byte(body))
	request, err := http.NewRequest(method, url, BODY_READER)
	if err != nil {
		log.Panicln(err)
	}

	response, err := client.Do(request)

	return response
}
