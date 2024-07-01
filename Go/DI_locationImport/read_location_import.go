package main

import (
	"strconv"

	"github.com/pborman/uuid"
	"github.com/thedatashed/xlsxreader"
)

type ImportLocationsContent struct {
	Content      []Content `json:"Content"`
	UserID       int       `json:"UserId"`
	SessionToken string    `json:"SessionToken"`
}

type Content struct {
	GUID            string  `json:"guid"`
	FranchiseNumber string  `json:"franchise_number"`
	Status          bool    `json:"status"`
	Lockdown        bool    `json:"lockdown"`
	PaymentStatusID int     `json:"payment_status_id"`
	Features        []int   `json:"features"`
	SedonaSiteID    int     `json:"sedona_site_id"`
	TimeZone        any     `json:"time_zone"`
	Region          string  `json:"region"`
	PanelType       string  `json:"panel_type"`
	Address         Address `json:"address"`
	Organization    struct {
		Name         string `json:"name"`
		Segmentation string `json:"segmentation"`
	} `json:"organization"`
	Brand struct {
		Name string `json:"name"`
	} `json:"brand"`
	Controllers any `json:"controllers"`
}

type Address struct {
	Address   string `json:"address1"`
	City      string `json:"city"`
	State     string `json:"state"`
	Zip       string `json:"zip"`
	Country   string `json:"country"`
	Phone1    any    `json:"phone1"`
	Latitude  any    `json:"latitude"`
	Longitude any    `json:"longitude"`
}

func read_locations_from_file(filename string) ImportLocationsContent {
	file, err := xlsxreader.OpenFile(filename)
	check(err)
	defer file.Close()

	var import_locations_content ImportLocationsContent

	for row := range file.ReadRows(file.Sheets[0]) {
		if row.Index == 1 {
			continue
		}

		GUID := uuid.New()

		var one_location_content Content
		one_location_content.GUID = GUID
		one_location_content.FranchiseNumber = row.Cells[3].Value
		one_location_content.Status = true
		one_location_content.Lockdown = false
		one_location_content.PaymentStatusID = 2
		one_location_content.Features = []int{}
		i_sedona_site_id, err := strconv.Atoi(row.Cells[2].Value)
		check(err)
		one_location_content.SedonaSiteID = i_sedona_site_id
		one_location_content.TimeZone = nil
		one_location_content.Region = row.Cells[9].Value
		one_location_content.PanelType = ""
		one_location_content.Address = Address{
			Address:   row.Cells[4].Value,
			City:      row.Cells[6].Value,
			State:     row.Cells[7].Value,
			Zip:       row.Cells[5].Value,
			Country:   row.Cells[8].Value,
			Phone1:    nil,
			Longitude: nil,
			Latitude:  nil,
		}
		one_location_content.Organization.Name = row.Cells[1].Value
		one_location_content.Organization.Segmentation = ""
		one_location_content.Brand.Name = row.Cells[0].Value
		one_location_content.Controllers = nil

		import_locations_content.Content = append(import_locations_content.Content, one_location_content)
	}

	return import_locations_content
}
