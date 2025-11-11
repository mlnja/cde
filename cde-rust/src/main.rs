use anyhow::Result;
use clap::{Parser, Subcommand};

mod db;
mod profile;
mod protocol;
mod shell;

#[derive(Parser)]
#[command(name = "cde")]
#[command(about = "Cloud DevEx - Beautiful command-line interface for cloud operations", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Select and switch cloud profiles
    #[command(name = "p")]
    Profile,

    /// Show help information
    Help,

    /// Check dependencies and installation
    Doctor,

    /// Update CDE to latest version
    Update,

    /// Show cached data
    Cache,

    /// Clean all cached data
    #[command(name = "cache-clean")]
    CacheClean,
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Profile => {
            profile::run().await?;
        }
        Commands::Help => {
            print_help();
        }
        Commands::Doctor => {
            check_dependencies()?;
        }
        Commands::Update => {
            println!("Update functionality not yet implemented");
        }
        Commands::Cache => {
            db::show_cache()?;
        }
        Commands::CacheClean => {
            db::clean_cache()?;
        }
    }

    Ok(())
}

fn print_help() {
    println!("CDE - Cloud DevEx");
    println!("Beautiful cloud utilities\n");
    println!("Available commands:");
    println!("  cde p                    - Select cloud profile");
    println!("  cde cache                - Show all cached data");
    println!("  cde cache-clean          - Clean all cached data");
    println!("  cde doctor               - Check dependencies");
    println!("  cde update               - Update CDE");
    println!("  cde help                 - Show this help");
}

fn check_dependencies() -> Result<()> {
    use std::process::Command;

    println!("🩺 CDE Doctor - Checking dependencies...\n");

    let mut all_good = true;

    // Check AWS CLI
    if let Ok(output) = Command::new("aws").arg("--version").output() {
        if output.status.success() {
            let version = String::from_utf8_lossy(&output.stdout);
            println!("✅ aws: {}", version.trim());
        }
    } else {
        println!("⚠️  aws: not found (optional for AWS features)");
        println!("   Install with: https://aws.amazon.com/cli/");
    }

    // Check gcloud CLI
    if let Ok(output) = Command::new("gcloud").arg("version").output() {
        if output.status.success() {
            println!("✅ gcloud: installed");
        }
    } else {
        println!("⚠️  gcloud: not found (optional for GCP features)");
        println!("   Install with: https://cloud.google.com/sdk/docs/install");
    }

    // Check az CLI
    if let Ok(output) = Command::new("az").arg("version").output() {
        if output.status.success() {
            println!("✅ az: installed");
        }
    } else {
        println!("⚠️  az: not found (optional for Azure features)");
        println!("   Install with: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli");
    }

    // Check jq
    if let Ok(output) = Command::new("jq").arg("--version").output() {
        if output.status.success() {
            let version = String::from_utf8_lossy(&output.stdout);
            println!("✅ jq: {}", version.trim());
        }
    } else {
        println!("❌ jq: not found (required for wrapper script)");
        println!("   Install with: brew install jq (macOS) or apt install jq (Linux)");
        all_good = false;
    }

    println!();
    if all_good {
        println!("🎉 All required dependencies are installed!");
    } else {
        println!("⚠️  Some required dependencies are missing.");
    }

    Ok(())
}
