pub mod command {
    use serde::{Deserialize, Serialize};

    /// Protocol message describing the desired shell mutation.
    #[derive(Debug, Serialize, Deserialize)]
    #[serde(tag = "action")]
    pub enum ShellCommand {
        #[serde(rename = "set_env")]
        SetEnv { key: String, value: String },

        #[serde(rename = "unset_env")]
        UnsetEnv { key: String },
    }

    impl ShellCommand {
        pub fn set_env(key: impl Into<String>, value: impl Into<String>) -> Self {
            ShellCommand::SetEnv {
                key: key.into(),
                value: value.into(),
            }
        }

        pub fn unset_env(key: impl Into<String>) -> Self {
            ShellCommand::UnsetEnv { key: key.into() }
        }
    }

    #[cfg(test)]
    mod tests {
        use super::ShellCommand;

        #[test]
        fn test_serialize_set_env() {
            let cmd = ShellCommand::set_env("AWS_PROFILE", "production");
            let json = serde_json::to_string(&cmd).unwrap();
            assert_eq!(
                json,
                r#"{"action":"set_env","key":"AWS_PROFILE","value":"production"}"#
            );
        }

        #[test]
        fn test_serialize_unset_env() {
            let cmd = ShellCommand::unset_env("AWS_PROFILE");
            let json = serde_json::to_string(&cmd).unwrap();
            assert_eq!(json, r#"{"action":"unset_env","key":"AWS_PROFILE"}"#);
        }

        #[test]
        fn test_deserialize_set_env() {
            let json = r#"{"action":"set_env","key":"FOO","value":"bar"}"#;
            let cmd: ShellCommand = serde_json::from_str(json).unwrap();
            match cmd {
                ShellCommand::SetEnv { key, value } => {
                    assert_eq!(key, "FOO");
                    assert_eq!(value, "bar");
                }
                _ => panic!("Wrong variant"),
            }
        }
    }
}

pub mod channel {
    use super::command::ShellCommand;
    use anyhow::Result;
    use std::fs::File;
    use std::io::{self, Write};
    use std::os::unix::io::FromRawFd;

    /// Channel that emits shell commands to the wrapper-provided file descriptor.
    pub struct EnvironmentChannel {
        fd: i32,
    }

    impl Default for EnvironmentChannel {
        fn default() -> Self {
            Self { fd: 3 }
        }
    }

    impl EnvironmentChannel {
        pub fn set_env(&self, key: &str, value: &str) -> Result<()> {
            self.send(&ShellCommand::set_env(key, value))
        }

        pub fn unset_env(&self, key: &str) -> Result<()> {
            self.send(&ShellCommand::unset_env(key))
        }

        pub fn send(&self, command: &ShellCommand) -> Result<()> {
            let json = serde_json::to_string(command)?;

            // The parent shell only opens fd(3) when running through the wrapper; outside
            // of that environment we expect this write to fail with EBADF and silently ignore it.
            unsafe {
                let mut file = File::from_raw_fd(self.fd);
                let result: io::Result<()> = (|| {
                    writeln!(file, "{}", json)?;
                    file.flush()
                })();
                std::mem::forget(file);

                match result {
                    Ok(()) => Ok(()),
                    Err(err) => {
                        if err.raw_os_error() == Some(9) {
                            Ok(())
                        } else {
                            Err(err.into())
                        }
                    }
                }
            }
        }
    }
}
