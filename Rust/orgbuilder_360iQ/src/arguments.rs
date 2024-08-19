
use clap::{arg, command, Parser};

#[derive(Parser, Debug)]
#[command(version, about, long_about = None)]
pub struct Args {
    #[arg(short, long)]
    pub username: String,

    /// xlsx file path with names or ids in first column, names require --names flag to be passed in 
    #[arg(short, long, default_value_t = String::new())]
    pub file: String,

    /// sheet name to get data from, can be found inside file on the bottom as tab name
    #[arg(short, long, default_value_t = String::new())]
    pub sheet: String,

    #[arg(short, long)]
    pub organization: String,

    #[arg(short, long, default_value_t = false)]
    pub remove: bool,

    /// Remove all locations, leaving only placehoder, requires confirmation, CANNOT BE UNDONE
    #[arg(short, long, default_value_t = false)]
    pub wipe: bool,

    /// WIP
    #[arg(long, default_value_t = false)]
    pub save_credentials: bool,

    /// Parse location names from csv file instead of location ids
    #[arg(long, default_value_t = false)]
    pub names: bool,

    /// Verbose output
    #[arg(long, default_value_t = false)]
    pub verbose: bool
}