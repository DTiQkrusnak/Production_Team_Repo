package main

import (
	"flag"
	"log"
	"os"
)

func initFlags() (string, string, string, bool) {
	var usernameFlag = flag.String("u", "", "WEB username")
	var passwordFlag = flag.String("p", "", "WEB password")
	var filenameFlag = flag.String("f", "", "CSV filename")
	var qaFlag = flag.Bool("qa", false, "is QA env")
	flag.Parse()

	if *usernameFlag == "" || *passwordFlag == "" || *filenameFlag == "" {
		log.Println("use flags are required, run -h for all available flags")
		os.Exit(-1)
	}

	return *usernameFlag, *passwordFlag, *filenameFlag, *qaFlag
}
