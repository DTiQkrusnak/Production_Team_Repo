package main

import "log"

func CheckErrorPanic(message string, errorVar error) {
	if errorVar != nil {
		log.Println(message)
		log.Panicln(errorVar)
	} else {
		return
	}
}
