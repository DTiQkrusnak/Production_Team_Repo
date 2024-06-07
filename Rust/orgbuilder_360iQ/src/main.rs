#![warn(clippy::unwrap_used)]
#![warn(clippy::expect_used)]

use std::time::Instant;

use calamine::Data;
use clap::Parser;

use crate::utils::{
    client_builder::build_http_client,
    get_data::{self, get_locations_assigned_to_organization, get_organization_by_name},
    load_locations_from_file::match_ids_from_xlsx,
    organization_modification::build_ids_list_ready_to_send
};

mod arguments;
mod utils;
fn main() {
    let cmd = arguments::Args::parse();
    let client = build_http_client();

    match utils::login::mms_login_request(&client, &cmd.username, &cmd.password) {
        Ok(_) => if cmd.verbose { println!("MMS logged in")},
        Err(error) => panic!("{:?}", error),
    };
    
    let now = Instant::now();
    if cmd.verbose { println!("Downloading locations"); };
    let all_data = utils::get_data::get_and_parse_all_locations_data(&client);
    if cmd.verbose { println!("Download took: {:?}", now.elapsed()) };

    let ids_from_file: (Vec<u64>, Vec<Data>) = match match_ids_from_xlsx(&cmd.file, &cmd.sheet, &all_data, cmd.names) {
        Ok(ids) => ids,
        Err(error) => panic!("{:?}", error),
    };

    if !(ids_from_file.1.is_empty()) { println!("not found in all locations: {:?}", ids_from_file.1); };

    let target_organization: get_data::Organization = match get_organization_by_name(&all_data, &cmd.organization) {
        Ok(organization) => organization,
        Err(error) => panic!("{:?}", error),
    };

    let locations_in_target_organization =
        match get_locations_assigned_to_organization(&all_data, target_organization.organization_id) {
            Ok(assigned) => assigned,
            Err(_) => panic!("Cannot get assigned locations"),
        };
    if cmd.verbose {println!("locations assigned to target found")};

    let organization_prefix: String = match locations_in_target_organization[0]
        .clone()
        .organization_prefix
    {
        Some(prefix) => prefix,
        None => target_organization.organization.clone(),
    };

    let location_ids_in_target_organization: Vec<u64> = locations_in_target_organization
        .iter()
        .map(|location| location.location_id)
        .collect();

    let id_ready_to_send_edit =
        build_ids_list_ready_to_send(all_data, ids_from_file.0, cmd.remove, location_ids_in_target_organization);

    match utils::login::web_login_request(&client, &cmd.username, &cmd.password) {
        Ok(_) => if cmd.verbose { println!("WEB logged in")},
        Err(error) => panic!("{:?}", error),
    };

    let modification_response_body = utils::organization_modification::edit_organization(
        &client,
        target_organization,
        organization_prefix,
        &cmd.remove,
        id_ready_to_send_edit,
    );

    if cmd.verbose { println!("{}", modification_response_body)}
}
