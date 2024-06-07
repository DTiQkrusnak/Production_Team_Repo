use std::path::Path;

use calamine::{open_workbook, Data, DataType, Range, Reader, Xlsx, XlsxError};

use super::get_data::Value;

pub fn match_ids_from_xlsx(
    path: impl AsRef<Path>,
    sheet_name: &str,
    all_data: &Value,
    load_names: bool,
) -> Result<(Vec<u64>,Vec<Data>), XlsxError> {
    let excel_data = load_csv_file(path, sheet_name)?;

    let mut ids: Vec<u64> = vec![];
    let mut ids_not_parsed: Vec<Data> = vec![];

    for item in excel_data.rows() {
        let match_found = if load_names {
            if let Some(location_name) = item[0].get_string() {
                all_data.locations.iter().find(|location| location.location.as_str() == location_name)
            } else {
                None
            }
        } else if let Some(location_id) = item[0].get_float() {
            all_data.locations.iter().find(|location| location.location_id == location_id as u64)
        } else {
            None
        };

        if let Some(location) = match_found {
            ids.push(location.location_id);
        } else {
            ids_not_parsed.push(item[0].clone());
        };
    };


    ids.sort();
    ids.dedup();

    Ok((ids, ids_not_parsed))
}

fn load_csv_file(path: impl AsRef<Path>, sheet_name: &str) -> Result<Range<Data>, XlsxError> {
    let mut excel: Xlsx<_> = match open_workbook(path) {
        Ok(file) => file,
        Err(error) => return Err(error)
    };

    let sheets = excel.sheet_names();
    let sheet_name = sheet_name.to_owned();
    let sheet = if sheet_name.is_empty() {
        sheets.first().to_owned()
    } else {
        Some(&sheet_name)
    };

    let sheet = match sheet {
        Some(sheet) => sheet.to_owned(),
        None => panic!()
    };

    let excel_data = match excel.worksheet_range(sheet.as_str()) {
        Ok(data) => data,
        Err(error) => return Err(error)
    };

    Ok(excel_data)
}

#[cfg(test)]
mod tests {
    use crate::utils::get_data::{Value, Location, Organization};

    use super::{load_csv_file, match_ids_from_xlsx};

    #[test]
    fn file_load() {
        let xlsx = load_csv_file("tests/test_names.xlsx", "Controllers");
        match xlsx {
            Ok(_) => assert!(true),
            Err(_) => assert!(false)
        }
    }
    
    #[test]
    fn load_xlsx_with_names() {
        let result = match_ids_from_xlsx("tests/test_names.xlsx", "Controllers", &Value{
            locations: vec![Location {
                organization_id: 1,
                organization_prefix: Some(String::from("test")),
                location: String::from("test_location"),
                location_id: 1000000
            }],
            organizations: vec![Organization {
                organization: String::from("test"),
                organization_id: 1
            }]
        }, true).unwrap();

        assert_eq!(result.0[0], 1000000);
        assert_eq!(result.0.len(), 1);
    }

    #[test]
    fn load_xlsx_with_ids() {
        let result = match_ids_from_xlsx("tests/test_ids.xlsx", "Controllers", &Value{
            locations: vec![Location {
                organization_id: 1,
                organization_prefix: Some(String::from("test")),
                location: String::from("test_location"),
                location_id: 1000000
            }],
            organizations: vec![Organization {
                organization: String::from("test"),
                organization_id: 1
            }]
        }, false).unwrap();

        assert_eq!(result.0[0], 1000000);
        assert_eq!(result.0.len(), 1);
    }
}