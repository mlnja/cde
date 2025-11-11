use crate::profile::Profile;
use crate::shell;
use anyhow::Result;
use std::process::Command;

pub fn list_profiles() -> Result<Vec<Profile>> {
    // Check if az is installed
    if Command::new("az").arg("--version").output().is_err() {
        return Ok(Vec::new());
    }

    let output = Command::new("az")
        .args(&["account", "list", "--query", "[].name", "-o", "tsv"])
        .output()?;

    if !output.status.success() {
        return Ok(Vec::new());
    }

    let accounts_str = String::from_utf8_lossy(&output.stdout);
    let mut profiles = Vec::new();

    for line in accounts_str.lines() {
        let name = line.trim();
        if !name.is_empty() {
            profiles.push(Profile::new("azure", name, "🔷"));
        }
    }

    Ok(profiles)
}

pub fn set_profile(name: &str) -> Result<()> {
    // Set the Azure subscription
    let output = Command::new("az")
        .args(&["account", "set", "--subscription", name])
        .output()?;

    if !output.status.success() {
        let error = String::from_utf8_lossy(&output.stderr);
        return Err(anyhow::anyhow!(
            "Failed to set Azure subscription: {}",
            error
        ));
    }

    // Get subscription details
    if let Ok(sub_id) = get_subscription_id(name) {
        shell::set_env("AZURE_SUBSCRIPTION_ID", &sub_id)?;
    }

    println!("✅ Azure subscription set: {}", name);

    // Cache the current profile
    crate::db::set_cache("current_profile", &format!("azure:{}", name))?;

    Ok(())
}

fn get_subscription_id(name: &str) -> Result<String> {
    let output = Command::new("az")
        .args(&[
            "account",
            "show",
            "--subscription",
            name,
            "--query",
            "id",
            "-o",
            "tsv",
        ])
        .output()?;

    if output.status.success() {
        let sub_id = String::from_utf8_lossy(&output.stdout);
        let sub_id = sub_id.trim();
        if !sub_id.is_empty() {
            return Ok(sub_id.to_string());
        }
    }

    Err(anyhow::anyhow!("Subscription ID not found"))
}
