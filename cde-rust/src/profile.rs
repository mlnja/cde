use anyhow::Result;
use dialoguer::{FuzzySelect, theme::ColorfulTheme};

mod aws;
mod azure;
mod gcp;

#[derive(Debug, Clone)]
pub struct Profile {
    pub provider: String,
    pub name: String,
    pub display: String,
}

impl Profile {
    fn new(provider: &str, name: &str, icon: &str) -> Self {
        Self {
            provider: provider.to_string(),
            name: name.to_string(),
            display: format!("{} {}:{}", icon, provider, name),
        }
    }
}

pub async fn run() -> Result<()> {
    let mut profiles = Vec::new();

    // Collect AWS profiles
    profiles.extend(aws::list_profiles().await?);

    // Collect GCP profiles
    profiles.extend(gcp::list_profiles()?);

    // Collect Azure profiles
    profiles.extend(azure::list_profiles()?);

    if profiles.is_empty() {
        eprintln!("❌ No cloud profiles found");
        return Ok(());
    }

    println!("🌥️  Select Cloud Profile:");

    let selection = FuzzySelect::with_theme(&ColorfulTheme::default())
        .items(
            &profiles
                .iter()
                .map(|p| p.display.as_str())
                .collect::<Vec<_>>(),
        )
        .default(0)
        .interact_opt()?;

    if let Some(index) = selection {
        let profile = &profiles[index];

        match profile.provider.as_str() {
            "aws" => aws::set_profile(&profile.name).await?,
            "gcp" => gcp::set_profile(&profile.name)?,
            "azure" => azure::set_profile(&profile.name)?,
            _ => eprintln!("❌ Unknown provider: {}", profile.provider),
        }
    } else {
        // User cancelled - clean all profiles
        println!("⚠️  No profile selected - cleaning all profiles");
        clean_all_profiles()?;
    }

    Ok(())
}

fn clean_all_profiles() -> Result<()> {
    use crate::shell;

    // Clean AWS variables
    shell::unset_env("AWS_PROFILE")?;
    shell::unset_env("AWS_DEFAULT_PROFILE")?;
    shell::unset_env("AWS_ACCESS_KEY_ID")?;
    shell::unset_env("AWS_SECRET_ACCESS_KEY")?;
    shell::unset_env("AWS_SESSION_TOKEN")?;
    shell::unset_env("AWS_REGION")?;
    shell::unset_env("AWS_DEFAULT_REGION")?;

    // Clean GCP variables
    shell::unset_env("GOOGLE_APPLICATION_CREDENTIALS")?;
    shell::unset_env("GCLOUD_PROJECT")?;
    shell::unset_env("GOOGLE_CLOUD_PROJECT")?;

    // Clean Azure variables
    shell::unset_env("AZURE_SUBSCRIPTION_ID")?;
    shell::unset_env("AZURE_TENANT_ID")?;
    shell::unset_env("AZURE_CLIENT_ID")?;
    shell::unset_env("AZURE_CLIENT_SECRET")?;

    Ok(())
}
