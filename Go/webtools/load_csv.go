package main

import (
	"encoding/csv"
	"log"
	"os"
	"strconv"
)

type UserInfo struct {
	AddAsContact           bool   `json:"AddAsContact"`
	FirstName              string `json:"FirstName"`
	LastName               string `json:"LastName"`
	Password               string `json:"Password"`
	Login                  string `json:"Login"`
	LoginID                any    `json:"LoginId"`
	UserID                 any    `json:"UserId"`
	Email                  string `json:"Email"`
	InitialScreenElementID any    `json:"InitialScreenElementId"`
	RoleID                 int    `json:"RoleId"`
	UserLevelID            int    `json:"UserLevelID"`
	Country                string `json:"Country"`
	Language               string `json:"Language"`
	Currency               string `json:"Currency"`
	TwoFactorAuthEnabled   any    `json:"TwoFactorAuthEnabled"`
	OrganizationsIds       []int  `json:"OrganizationsIds"`
	LocationsIds           []int  `json:"LocationsIds"`
	ObjectsPermissions     []any  `json:"ObjectsPermissions"`
	Permissions            []any  `json:"Permissions"`
}

func LoadCsv(filename string) []UserInfo {
	var file *os.File

	file, err := os.Open(filename)
	if err != nil {
		createExampleCsv()
	}
	defer file.Close()

	csvRecords, err := csv.NewReader(file).ReadAll()
	if err != nil {
		log.Println(err)
	}

	var UserInfoRecords []UserInfo
	for index, record := range csvRecords {

		//data preparation
		tempAddAsContact, err := strconv.ParseBool(record[0])
		csvParseErrorCheck(err, index)
		tempRoleId, err := strconv.Atoi(record[9])
		csvParseErrorCheck(err, index)
		tempUserLevelID, err := strconv.Atoi(record[10])
		csvParseErrorCheck(err, index)
		tempOrganizationIds, err := strconv.Atoi(record[15])
		csvParseErrorCheck(err, index)

		user := UserInfo{
			AddAsContact:           tempAddAsContact,
			FirstName:              record[1],
			LastName:               record[2],
			Password:               record[3],
			Login:                  record[4],
			LoginID:                record[5],
			UserID:                 record[6],
			Email:                  record[7],
			InitialScreenElementID: record[8],
			RoleID:                 tempRoleId,
			UserLevelID:            tempUserLevelID,
			Country:                record[11],
			Language:               record[12],
			Currency:               record[13],
			TwoFactorAuthEnabled:   record[14],
			OrganizationsIds:       []int{tempOrganizationIds},
			LocationsIds:           nil,
			ObjectsPermissions:     nil,
			Permissions:            nil,
		}

		UserInfoRecords = append(UserInfoRecords, user)
	}

	return UserInfoRecords
}

func csvParseErrorCheck(err error, index int) {
	if err != nil {
		log.Printf("csv index %d cannot be parsed to object, skipping", index+1)
		log.Println(err)
	}
}

func createExampleCsv() {
	file, err := os.Create("UsersExample.csv")
	if err != nil {
		log.Println(err)
	}
	file.WriteString(`"AddAsContact","FirstName","LastName","Password","Login","LoginId","UserId","Email","InitialScreenElementId","RoleId","UserLevelID","Country","Language","Currency","TwoFactorAuthEnabled","OrganizationsIds__-","LocationsIds__-"
"False","TestFirstName","TestLastName","TestPassword1!@","TestUsername","null","null","test@test.example","null","12","1","USA","en-US","USD","null","99999","99999"`)
	file.Close()
	log.Println("Missing CSV file. UsersExample.csv generated")
	os.Exit(0)
}
