use super::get_data::Value;

pub fn verify_access_to_locations(data: &Value, location_ids: Vec<u64>) -> Vec<u64> {
    let all_location_ids: Vec<u64> = data.locations
        .clone()
        .into_iter()
        .map(|location| location.location_id)
        .collect();

    let found: Vec<u64> = location_ids.clone().into_iter().filter(|id| all_location_ids.contains(id)).collect();
    let not_found: Vec<&u64> = location_ids.iter().filter(|id| !all_location_ids.contains(id)).collect();
    
    
    if !(not_found.is_empty()) {
        println!("list of ids that are not valid: {:?}", not_found);
    }

    found
}