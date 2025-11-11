use crate::profile::Profile;
use crate::shell;
use anyhow::Result;
use aws_config::BehaviorVersion;
use home::home_dir;
use std::collections::BTreeSet;
use std::fs::File;
use std::io::{BufRead, BufReader};

pub async fn list_profiles() -> Result<Vec<Profile>> {
    let mut names = BTreeSet::new();

    if let Some(home_dir) = home_dir() {
        let config_path = home_dir.join(".aws/config");

        if let Ok(file) = File::open(config_path) {
            let reader = BufReader::new(file);
            for line in reader.lines().flatten() {
                if let Some(name) = parse_profile_header(&line) {
                    names.insert(name);
                }
            }
        }
    }

    let profiles = names
        .into_iter()
        .map(|name| Profile::new("aws", &name, "☁️"))
        .collect();

    Ok(profiles)
}

pub async fn set_profile(name: &str) -> Result<()> {
    // Set AWS_PROFILE environment variable which AWS SDK respects
    shell::set_env("AWS_PROFILE", name)?;
    shell::set_env("AWS_DEFAULT_PROFILE", name)?;

    // Clear any temporary credentials that might override the profile
    shell::unset_env("AWS_ACCESS_KEY_ID")?;
    shell::unset_env("AWS_SECRET_ACCESS_KEY")?;
    shell::unset_env("AWS_SESSION_TOKEN")?;

    // Load the config for this profile to get region
    let config = aws_config::defaults(BehaviorVersion::latest())
        .profile_name(name)
        .load()
        .await;

    if let Some(region) = config.region() {
        shell::set_env("AWS_REGION", region.as_ref())?;
        shell::set_env("AWS_DEFAULT_REGION", region.as_ref())?;
    }

    println!("✅ AWS profile set: {}", name);

    // Cache the current profile
    crate::db::set_cache("current_profile", &format!("aws:{}", name))?;

    Ok(())
}

fn parse_profile_header(line: &str) -> Option<String> {
    let trimmed = line.trim();
    if !trimmed.starts_with('[') || !trimmed.ends_with(']') {
        return None;
    }

    let inner = &trimmed[1..trimmed.len() - 1];
    let inner = inner.trim();

    if inner.is_empty() {
        return None;
    }

    if let Some(rest) = inner.strip_prefix("profile ") {
        Some(rest.trim().to_string())
    } else {
        Some(inner.to_string())
    }
}
