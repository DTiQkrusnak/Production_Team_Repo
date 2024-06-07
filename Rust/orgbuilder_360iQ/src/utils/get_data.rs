
use std::time::Duration;

use reqwest::blocking::{Client, Response};
use serde::{Deserialize, Serialize};

use crate::utils;
#[derive(Debug)]
pub enum AllDataError {
    CannotFindOrganization,
    MultipleOrganizationsFound,
    NoLocationsAssignedToOrganization
}

#[derive(Default, Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Root {
    pub value: Value,
}

#[derive(Default, Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Value {
    pub locations: Vec<Location>,
    pub organizations: Vec<Organization>,
}

#[derive(Default, Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Location {
    pub organization_id: i64,
    pub organization_prefix: Option<String>,
    pub location_id: u64,
    pub location: String,
}

#[derive(Default, Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Organization {
    pub organization_id: i64,
    pub organization: String,
}

fn get_data(client: &Client) -> Result<Response, reqwest::Error> {
    let web_get_everything_url =
        "https://mmsrc.go360iq.com/api/Filters/GetAllLocationsOrganizationsAndBrands";

    client
        .get(web_get_everything_url)
        .timeout(Duration::from_secs(120))
        .send()
}

fn parse_all_locations_data_from_response(data: Response) -> Result<String, reqwest::Error> {
    let data = match data.text() {
        Ok(data) => data,
        Err(error) => return Err(error)
    };

    Ok(data)
}

fn parse_all_locations_data_from_text(stringified_data: &str) -> Result<Value, serde_json::Error>{
    let json: Root = match serde_json::from_str(stringified_data) {
        Ok(json) => json,
        Err(error) => return Err(error)
    };

    Ok(json.value)
}

pub fn get_locations_assigned_to_organization(data: &Value, id: i64) -> Result<Vec<Location>, AllDataError> {
    let filtered_output: Vec<Location> = data
        .locations
        .clone()
        .into_iter()
        .filter(|location| location.organization_id == id)
        .collect();

    if filtered_output.is_empty() { return Err(AllDataError::NoLocationsAssignedToOrganization) }

    Ok(filtered_output)
}

pub fn get_organization_by_name(data: &Value, name: &str) -> Result<Organization, AllDataError>  {
    let filtered_output: Vec<Organization> = data
        .organizations
        .clone()
        .into_iter()
        .filter(|organization| organization.organization == name)
        .collect();
    
    if filtered_output.is_empty() { return Err(AllDataError::CannotFindOrganization) }
    if filtered_output.len() > 1 { return Err(AllDataError::MultipleOrganizationsFound) }

    Ok(filtered_output[0].clone())
}

pub fn get_and_parse_all_locations_data(client: &Client) -> Value {
    let mut get_data_retry_count = 3;
    loop {
        let all_data_downloaded = match utils::get_data::get_data(client) {
            Ok(response) => response,
            Err(error) => {
                println!("{:?}", error);
                if get_data_retry_count > 0 {
                    println!("retrying data download, retries left: {}", get_data_retry_count); 
                    get_data_retry_count -= 1;
                    continue
                }
                panic!("{:?}", error)
            }
        };

       //dbg!(&all_data_downloaded);

        let all_data_buffer = match utils::get_data::parse_all_locations_data_from_response(all_data_downloaded) {
            Ok(data) => data,
            Err(error) => {
                println!("{:?}", error);
                if get_data_retry_count > 0 {
                    println!("retrying data parsing, retries left: {}", get_data_retry_count); 
                    get_data_retry_count -= 1;
                    continue
                }
                panic!("{:?}", error)
            }
        };

        //dbg!(&all_data_buffer);

        let all_data = match utils::get_data::parse_all_locations_data_from_text(&all_data_buffer) {
            Ok(data) => data,
            Err(error) => {
                println!("{:?}", error);
                if get_data_retry_count > 0 {
                    println!("retrying data parsing, retries left: {}", get_data_retry_count);
                    get_data_retry_count -= 1;
                    continue
                }
                panic!("{:?}", error)
            }
        };
        break all_data
    }
}
