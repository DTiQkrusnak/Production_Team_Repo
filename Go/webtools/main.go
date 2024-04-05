package main

import "log"

func main() {
	//+ log into WEB
	//read CSV
	//load CSV into Users[]
	//loop over Users[]
	// verify if user already exists or email is in use
	//make request to make user

	username, password, filename, qaFlag := initFlags()
	log.Println("QA: ", qaFlag)
	client, err := LoginWebApp(username, password, qaFlag)
	if err != nil {
		log.Println(err)
	}
	usersData := LoadCsv(filename)

	for _, data := range usersData {
		var isEmailFree bool = false
		var isUsernameFree bool = false

		isEmailFree = verifyEmail(client, data.Email, qaFlag)
		isUsernameFree = verifyUsername(client, data.Login, qaFlag)

		if isEmailFree && isUsernameFree {
			createUser(client, data, qaFlag)

			isEmailFree = verifyEmail(client, data.Email, qaFlag)
			isUsernameFree = verifyUsername(client, data.Login, qaFlag)

			if !isEmailFree && !isUsernameFree {
				log.Println("created user: ", data.Login)
			}
		} else {
			log.Println("Email: ", isEmailFree, " Username: ", isUsernameFree)
			log.Printf("Account with email: %s and username: %s cannot be created", data.Email, data.Login)
		}
	}
}
