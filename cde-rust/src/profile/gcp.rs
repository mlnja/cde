use crate::profile::Profile;
use crate::shell;
use anyhow::Result;
use std::process::Command;

pub fn list_profiles() -> Result<Vec<Profile>> {
    // Check if gcloud is installed
    if Command::new("gcloud").arg("--version").output().is_err() {
        return Ok(Vec::new());
    }

    let output = Command::new("gcloud")
        .args(&["config", "configurations", "list", "--format=value(name)"])
        .output()?;

    if !output.status.success() {
        return Ok(Vec::new());
    }

    let profiles_str = String::from_utf8_lossy(&output.stdout);
    let mut profiles = Vec::new();

    for line in profiles_str.lines() {
        let name = line.trim();
        if !name.is_empty() {
            profiles.push(Profile::new("gcp", name, "🔵"));
        }
    }

    Ok(profiles)
}

pub fn set_profile(name: &str) -> Result<()> {
    // Activate the gcloud configuration
    let output = Command::new("gcloud")
        .args(&["config", "configurations", "activate", name])
        .output()?;

    if !output.status.success() {
        let error = String::from_utf8_lossy(&output.stderr);
        return Err(anyhow::anyhow!("Failed to activate GCP profile: {}", error));
    }

    // Get the project ID for this configuration
    if let Ok(project) = get_profile_project(name) {
        shell::set_env("GOOGLE_CLOUD_PROJECT", &project)?;
        shell::set_env("GCLOUD_PROJECT", &project)?;
    }

    println!("✅ GCP profile set: {}", name);

    // Cache the current profile
    crate::db::set_cache("current_profile", &format!("gcp:{}", name))?;

    Ok(())
}

fn get_profile_project(config: &str) -> Result<String> {
    let output = Command::new("gcloud")
        .args(&[
            "config",
            "configurations",
            "describe",
            config,
            "--format=value(properties.core.project)",
        ])
        .output()?;

    if output.status.success() {
        let project = String::from_utf8_lossy(&output.stdout);
        let project = project.trim();
        if !project.is_empty() {
            return Ok(project.to_string());
        }
    }

    Err(anyhow::anyhow!("Project not found for configuration"))
}
