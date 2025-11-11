use crate::protocol::channel::EnvironmentChannel;
use anyhow::Result;

/// Send a command to set an environment variable in the parent shell via fd(3)
pub fn set_env(key: &str, value: &str) -> Result<()> {
    EnvironmentChannel::default().set_env(key, value)
}

/// Send a command to unset an environment variable in the parent shell via fd(3)
pub fn unset_env(key: &str) -> Result<()> {
    EnvironmentChannel::default().unset_env(key)
}
