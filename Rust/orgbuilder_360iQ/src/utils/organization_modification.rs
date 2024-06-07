use reqwest::blocking::Client;
use serde::Deserialize;
use serde::Serialize;
use serde_json::Value;

use super::get_data;
use super::get_data::Organization;
use super::verify_access::verify_access_to_locations;

#[derive(Default, Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct OrganizationEditPayload {
    #[serde(rename = "OrganizationId")]
    pub organization_id: String,
    #[serde(rename = "OrganizationTypeId")]
    pub organization_type_id: i64,
    #[serde(rename = "Prefix")]
    pub prefix: String,
    #[serde(rename = "Organization")]
    pub organization: String,
    #[serde(rename = "OrganizationType")]
    pub organization_type: String,
    #[serde(rename = "NewLocations")]
    pub new_locations: Vec<u64>,
    #[serde(rename = "DeletedLocations")]
    pub deleted_locations: Vec<u64>,
    #[serde(rename = "NewUsers")]
    pub new_users: Vec<Value>,
    #[serde(rename = "DeletedUsers")]
    pub deleted_users: Vec<Value>,
    #[serde(rename = "NewUserApprovers")]
    pub new_user_approvers: Vec<Value>,
    #[serde(rename = "DeletedUserApprovers")]
    pub deleted_user_approvers: Vec<Value>,
    #[serde(rename = "NewTeams")]
    pub new_teams: Vec<Value>,
    #[serde(rename = "DeletedTeams")]
    pub deleted_teams: Vec<Value>,
    #[serde(rename = "NewAlertInstances")]
    pub new_alert_instances: Vec<Value>,
    #[serde(rename = "DeletedAlertInstances")]
    pub deleted_alert_instances: Vec<Value>,
    #[serde(rename = "TwoFactorAuthEnabled")]
    pub two_factor_auth_enabled: bool,
    #[serde(rename = "TwoFactorAuthExpirationDays")]
    pub two_factor_auth_expiration_days: i64,
    #[serde(rename = "SSOEnabled")]
    pub ssoenabled: bool,
    #[serde(rename = "SSOKey")]
    pub ssokey: String,
    #[serde(rename = "EngagementReporting")]
    pub engagement_reporting: bool,
    #[serde(rename = "BenchmarkScore")]
    pub benchmark_score: String,
    #[serde(rename = "IsSupportChatEnabled")]
    pub is_support_chat_enabled: bool,
    #[serde(rename = "AddAsContact")]
    pub add_as_contact: bool,
}

pub fn edit_organization(
    client: &Client,
    organization: Organization,
    prefix: String,
    remove_flag: &bool,
    locations: Vec<u64>,
) -> String {
    let mut org = OrganizationEditPayload {
        organization_id: organization.organization_id.to_string(),
        organization_type_id: 9,
        organization_type: String::from("Internal"),
        prefix,
        organization: organization.organization,
        ..Default::default()
    };
    if *remove_flag {
        org.deleted_locations = locations;
        org.new_locations = vec![]
    } else {
        org.new_locations = locations;
        org.deleted_locations = vec![]
    }

    //dbg!(&org);

    let response = match client
        .post("https://app.go360iq.com/api/Organizations/EditOrganization")
        .json(&org)
        .send()
    {
        Ok(response) => response,
        Err(error) => panic!("{}", error),
    };
    
    match response.text() {
        Ok(result) => result,
        Err(error) => panic!("{}", error),
    }
}

pub fn build_ids_list_ready_to_send(
    all_data: get_data::Value,
    ids_from_file: Vec<u64>,
    remove: bool,
    location_assigned_ids: Vec<u64>,
) -> Vec<u64> {
    let mut ids_with_access_verified = verify_access_to_locations(&all_data, ids_from_file);

    if remove {
        ids_with_access_verified = ids_with_access_verified
            .clone()
            .into_iter()
            .filter(|id| location_assigned_ids.contains(id))
            .collect();
    } else {
        ids_with_access_verified = ids_with_access_verified
            .clone()
            .into_iter()
            .filter(|id| !location_assigned_ids.contains(id))
            .collect();
    }
    ids_with_access_verified
}
