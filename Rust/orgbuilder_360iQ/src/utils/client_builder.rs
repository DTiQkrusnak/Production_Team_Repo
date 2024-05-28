use std::time::Duration;

use reqwest::blocking::Client;



pub fn build_http_client() -> Client {
    let client = reqwest::blocking::ClientBuilder::new()
        .cookie_store(true)
        .connect_timeout(Duration::from_secs(120));

    match client.build() {
        Ok(client) => client,
        Err(_) => panic!("Cannot create client"),
    }
}