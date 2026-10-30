pub mod app;
pub mod cli;
pub mod config;
pub mod market;
pub mod modules;
pub mod payments;
pub mod rpc;
pub mod state;

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("invalid public payment request or network")]
    Payment,
    #[error("configuration could not be read")]
    ConfigRead,
    #[error("invalid configuration (check config.example.toml; values are intentionally redacted)")]
    Config,
    #[error(
        "runtime directory must be absolute, owned by this user, private, and free of symlinks"
    )]
    Runtime,
    #[error("another OmaMonero backend is already running")]
    AlreadyRunning,
    #[error("private state could not be read or written")]
    State,
    #[error("network client could not be initialized")]
    Client,
    #[error("signal handler could not be initialized")]
    Signal,
}
pub type Result<T> = std::result::Result<T, Error>;
