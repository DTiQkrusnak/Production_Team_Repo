use reqwest::blocking::Client;
use serde::Deserialize;
use serde::Serialize;

#[derive(Default, Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct LoginPayload {
    pub password: String,
    pub login: String,
    pub is_persistent: bool,
}
#[derive(Debug)]
pub enum LoginErrors {
    CannotLogin,
    RequestFailed,
    UserUnauthorized,
}

pub fn web_login_request(
    client: &Client,
    username: &str,
    password: &str,
) -> Result<(), LoginErrors> 
{
    let map: LoginPayload = LoginPayload {
        password: String::from(password),
        login: String::from(username),
        is_persistent: true,
    };

    let login_response = match client
        .post("https://app.go360iq.com/en-US/Account/Login")
        .json(&map)
        .send()
    {
        Ok(response) => response,
        Err(_) => return Err(LoginErrors::RequestFailed),
    };

    let result_body = match login_response.text() {
        Ok(result) => result,
        Err(_) => return Err(LoginErrors::CannotLogin),
    };

    const SUCCESS: &str = "IsSuccessfull\":true";
    match result_body.as_str().find(SUCCESS) {
        Some(_) => (),
        None => return Err(LoginErrors::UserUnauthorized),
    };

    Ok(())
}

pub fn mms_login_request(    client: &Client,
    username: &str,
    password: &str,
) -> Result<(), LoginErrors> {
    let map: LoginPayload = LoginPayload {
        password: String::from(password),
        login: String::from(username),
        is_persistent: true,
    };

    let login_response = match client
        .post("https://mms.go360iq.com/api/account/Login")
        .json(&map)
        .send()
    {
        Ok(response) => response,
        Err(_) => return Err(LoginErrors::RequestFailed),
    };

    let result_body = match login_response.text() {
        Ok(result) => result,
        Err(_) => return Err(LoginErrors::CannotLogin),
    };

    match result_body.find("\"status\":0") {
        Some(_) => (),
        None => return Err(LoginErrors::UserUnauthorized),
    };

    Ok(())
}