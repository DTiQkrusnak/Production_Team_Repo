package main

import (
	"bytes"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strconv"
)

type DI_Output struct {
	RegisteredControllers []struct {
		Location struct {
			LocationID           int    `json:"LocationID"`
			LocationGUID         string `json:"LocationGUID"`
			BrandID              int    `json:"BrandID"`
			AddressID            int    `json:"AddressID"`
			RegionID             int    `json:"RegionID"`
			Name                 string `json:"Name"`
			DisplayAs            string `json:"DisplayAs"`
			Identification       string `json:"Identification"`
			Utc                  int    `json:"UTC"`
			TimezoneID           int    `json:"TimezoneID"`
			OverrideTimezoneID   any    `json:"OverrideTimezoneID"`
			SynchronizationID    any    `json:"SynchronizationID"`
			AccountPanelType     string `json:"AccountPanelType"`
			AccountEnabled       bool   `json:"AccountEnabled"`
			PaymentStatusID      int    `json:"PaymentStatusID"`
			CustomerSegmentID    any    `json:"CustomerSegmentID"`
			IsSynchronized       bool   `json:"IsSynchronized"`
			Status               string `json:"Status"`
			IsDataOnly           bool   `json:"IsDataOnly"`
			IsVideoOnly          bool   `json:"IsVideoOnly"`
			CountryCode          any    `json:"CountryCode"`
			LanguageCode         any    `json:"LanguageCode"`
			CurrencyCode         any    `json:"CurrencyCode"`
			CreatedOn            string `json:"CreatedOn"`
			CreatedBy            int    `json:"CreatedBy"`
			ModifiedOn           any    `json:"ModifiedOn"`
			ModifiedBy           any    `json:"ModifiedBy"`
			BusinessDayTypeID    int    `json:"BusinessDayTypeID"`
			BusinessDayTypeValue any    `json:"BusinessDayTypeValue"`
			Address              struct {
				LocationID     int     `json:"LocationID"`
				AddressID      int     `json:"AddressID"`
				CityID         int     `json:"CityID"`
				Street         string  `json:"Street"`
				Phone          string  `json:"Phone"`
				PostalCode     string  `json:"PostalCode"`
				Longitude      float64 `json:"Longitude"`
				Latitude       float64 `json:"Latitude"`
				IsSynchronized bool    `json:"IsSynchronized"`
				CreatedOn      string  `json:"CreatedOn"`
				CreatedBy      int     `json:"CreatedBy"`
				ModifiedOn     any     `json:"ModifiedOn"`
				ModifiedBy     any     `json:"ModifiedBy"`
				City           struct {
					LocationID int    `json:"LocationID"`
					CityID     int    `json:"CityID"`
					StateID    int    `json:"StateID"`
					Name       string `json:"Name"`
					DisplayAs  string `json:"DisplayAs"`
					PostalCode string `json:"PostalCode"`
					CreatedOn  string `json:"CreatedOn"`
					CreatedBy  int    `json:"CreatedBy"`
					ModifiedOn any    `json:"ModifiedOn"`
					ModifiedBy any    `json:"ModifiedBy"`
					State      struct {
						LocationID int    `json:"LocationID"`
						StateID    int    `json:"StateID"`
						CountryID  int    `json:"CountryID"`
						Code       string `json:"Code"`
						Name       string `json:"Name"`
						DisplayAs  string `json:"DisplayAs"`
						Country    struct {
							LocationID int    `json:"LocationID"`
							CountryID  int    `json:"CountryID"`
							Code       string `json:"Code"`
							Name       string `json:"Name"`
							DisplayAs  string `json:"DisplayAs"`
							CreatedOn  string `json:"CreatedOn"`
							CreatedBy  int    `json:"CreatedBy"`
							ModifiedOn string `json:"ModifiedOn"`
							ModifiedBy int    `json:"ModifiedBy"`
						} `json:"Country"`
					} `json:"State"`
				} `json:"City"`
			} `json:"Address"`
			Brand struct {
				BrandID              int    `json:"BrandID"`
				Name                 string `json:"Name"`
				DisplayAs            string `json:"DisplayAs"`
				Logo                 any    `json:"Logo"`
				SynchronizationID    int    `json:"SynchronizationID"`
				IsSynchronized       bool   `json:"IsSynchronized"`
				BusinessDayTypeID    any    `json:"BusinessDayTypeId"`
				BusinessDayTypeValue any    `json:"BusinessDayTypeValue"`
				Status               string `json:"Status"`
				CreatedOn            string `json:"CreatedOn"`
				CreatedBy            int    `json:"CreatedBy"`
				ModifiedOn           string `json:"ModifiedOn"`
				ModifiedBy           int    `json:"ModifiedBy"`
			} `json:"Brand"`
			Timezone struct {
				LocationID int    `json:"LocationID"`
				TimezoneID int    `json:"TimezoneID"`
				Name       string `json:"Name"`
				DisplayAs  string `json:"DisplayAs"`
				Code       string `json:"Code"`
				Utc        int    `json:"UTC"`
				Path       string `json:"Path"`
				CreatedOn  string `json:"CreatedOn"`
				CreatedBy  int    `json:"CreatedBy"`
				ModifiedOn string `json:"ModifiedOn"`
				ModifiedBy int    `json:"ModifiedBy"`
			} `json:"Timezone"`
			CustomerSegment any `json:"CustomerSegment"`
			IntegrationData any `json:"IntegrationData"`
		} `json:"Location"`
		Controller struct {
			ControllerID           int    `json:"ControllerID"`
			LocationID             int    `json:"LocationID"`
			ModelID                int    `json:"ModelID"`
			Name                   string `json:"Name"`
			DisplayAs              string `json:"DisplayAs"`
			Identification         string `json:"Identification"`
			SynchronizationID      any    `json:"SynchronizationID"`
			IsSynchronized         bool   `json:"IsSynchronized"`
			Status                 string `json:"Status"`
			ControllerInterfaceURL string `json:"ControllerInterfaceURL"`
			ControllerGUID         string `json:"ControllerGUID"`
			VSWebSocketPort        any    `json:"VSWebSocketPort"`
			VSTCPPort              any    `json:"VSTCPPort"`
			CreatedOn              string `json:"CreatedOn"`
			CreatedBy              int    `json:"CreatedBy"`
			ModifiedOn             any    `json:"ModifiedOn"`
			ModifiedBy             any    `json:"ModifiedBy"`
		} `json:"Controller"`
		Registration struct {
			LocationID     int    `json:"LocationID"`
			ControllerID   int    `json:"ControllerID"`
			Code           string `json:"Code"`
			PhoneNumber    any    `json:"PhoneNumber"`
			HardwareMarker any    `json:"HardwareMarker"`
			LocalIP        any    `json:"LocalIP"`
			ExternalIP     any    `json:"ExternalIP"`
			HostName       any    `json:"HostName"`
			MachineName    any    `json:"MachineName"`
			Longitude      any    `json:"Longitude"`
			Latitude       any    `json:"Latitude"`
			CreatedOn      string `json:"CreatedOn"`
			CreatedBy      int    `json:"CreatedBy"`
			ModifiedOn     any    `json:"ModifiedOn"`
			ModifiedBy     any    `json:"ModifiedBy"`
		} `json:"Registration"`
		ManagementDetails   any `json:"ManagementDetails"`
		InstallerParameters struct {
			ControllerSoftwareTypeID int    `json:"ControllerSoftwareTypeID"`
			LocationID               int    `json:"LocationID"`
			ControllerID             int    `json:"ControllerID"`
			SoftwareTypeID           int    `json:"SoftwareTypeID"`
			SoftwareTypeName         string `json:"SoftwareTypeName"`
			CreatedOn                string `json:"CreatedOn"`
			CreatedBy                int    `json:"CreatedBy"`
			ModifiedOn               any    `json:"ModifiedOn"`
			ModifiedBy               any    `json:"ModifiedBy"`
		} `json:"InstallerParameters"`
		Cameras       []any `json:"Cameras"`
		Registers     []any `json:"Registers"`
		Sensors       []any `json:"Sensors"`
		Organizations []struct {
			CustomerSegment   any    `json:"CustomerSegment"`
			OrganizationID    int    `json:"OrganizationID"`
			Prefix            string `json:"Prefix"`
			Name              string `json:"Name"`
			DisplayAs         string `json:"DisplayAs"`
			CustomerSegmentID any    `json:"CustomerSegmentID"`
			SynchronizationID any    `json:"SynchronizationID"`
			IsSynchronized    bool   `json:"IsSynchronized"`
			Status            string `json:"Status"`
			CreatedOn         string `json:"CreatedOn"`
			CreatedBy         int    `json:"CreatedBy"`
			ModifiedOn        string `json:"ModifiedOn"`
			ModifiedBy        int    `json:"ModifiedBy"`
		} `json:"Organizations"`
	} `json:"RegisteredControllers"`
	InvalidRequests []any `json:"InvalidRequests"`
}

type UpdateControllerModelPayload struct {
	ControllerID string `json:"ControllerId"`
	LocationID   string `json:"LocationId"`
	ModelID      int    `json:"ModelId"`
}

type MMS_Login_payload struct {
	Password     string `json:"password"`
	Login        string `json:"login"`
	IsPersistent bool   `json:"isPersistent"`
}

func set_controller_model(client *http.Client, model int) {
	file_data, err := os.ReadFile("./DI_output.json")
	check(err)

	var di_output DI_Output
	err = json.Unmarshal(file_data, &di_output)
	check(err)

	var MMS_login_url string = "https://mmsrc.go360iq.com/api/account/Login"
	var payload MMS_Login_payload = MMS_Login_payload{
		// ! TODO change to pass login and password from creds file/args
		Password:     "",
		Login:        "",
		IsPersistent: true,
	}
	buf, err := json.Marshal(payload)
	check(err)
	reader := bytes.NewReader(buf)
	_, err = client.Post(MMS_login_url, "application/json", reader)
	check(err)

	var UPDATE_CONTROLLER_URL string = "https://mmsrc.go360iq.com/api/Locations/UpdateControllerModel"

	var invalid_requests []int = []int{}

	for _, controller := range di_output.RegisteredControllers {
		update_controller := UpdateControllerModelPayload{
			ControllerID: strconv.Itoa(controller.Registration.ControllerID),
			LocationID:   strconv.Itoa(controller.Registration.LocationID),
			ModelID:      model,
		}
		payload, err := json.Marshal(update_controller)
		if err != nil {
			invalid_requests = append(invalid_requests, controller.Registration.ControllerID)
		}

		reader := bytes.NewReader(payload)

		response, err := client.Post(UPDATE_CONTROLLER_URL, "application/json", reader)
		if err != nil {
			invalid_requests = append(invalid_requests, controller.Registration.ControllerID)
		}

		log.Println(response.Status)
	}

	log.Println(invalid_requests)
}
