use clap::{Parser, Subcommand};
use omamonero_core::{Result, app, cli::doctor, config::Config, state::writer};
use std::{path::PathBuf, process::ExitCode};

#[derive(Parser)]
#[command(version, about = "Read-only Monero node companion for Omarchy")]
struct Args {
    #[arg(long, global = true)]
    config: Option<PathBuf>,
    /// Parent runtime directory (defaults to XDG_RUNTIME_DIR); must be private.
    #[arg(long, global = true)]
    runtime_dir: Option<PathBuf>,
    #[command(subcommand)]
    command: Commands,
}
#[derive(Subcommand)]
enum Commands {
    /// Build a local public-address payment request from bounded JSON stdin.
    Payment,
    /// Verify a transaction proof through the explicitly configured read-only wallet RPC.
    Proof,
    /// Validate configuration without connecting or writing files.
    CheckConfig,
    /// Monitor the node until SIGINT/SIGTERM. Does not start monerod.
    Daemon,
    /// Poll once, publish a snapshot and print it as JSON.
    Once,
    /// Check live RPC and cached state without modifying files; JSON output.
    Doctor,
    /// Read cached state without making network requests.
    Status,
}
#[tokio::main]
async fn main() -> ExitCode {
    tracing_subscriber::fmt()
        .with_target(false)
        .with_writer(std::io::stderr)
        .with_env_filter(tracing_subscriber::EnvFilter::new("omamonero_core=warn"))
        .init();
    match execute(Args::parse()).await {
        Ok(true) => ExitCode::SUCCESS,
        Ok(false) => ExitCode::from(2),
        Err(e) => {
            eprintln!("omamonero-core: {e}");
            ExitCode::from(1)
        }
    }
}
async fn execute(args: Args) -> Result<bool> {
    if matches!(args.command, Commands::CheckConfig) {
        Config::load(args.config.as_deref())?;
        println!("{{\"valid\":true}}");
        return Ok(true);
    }
    if matches!(args.command, Commands::Payment) {
        use std::io::Read;
        let config = Config::load(args.config.as_deref())?;
        let mut raw = String::new();
        std::io::stdin()
            .take(4097)
            .read_to_string(&mut raw)
            .map_err(|_| omamonero_core::Error::Payment)?;
        if raw.len() > 4096 {
            return Err(omamonero_core::Error::Payment);
        }
        let request = serde_json::from_str(&raw).map_err(|_| omamonero_core::Error::Payment)?;
        let payment = omamonero_core::payments::build(request, config.network)
            .map_err(|_| omamonero_core::Error::Payment)?;
        println!(
            "{}",
            serde_json::to_string(&payment).map_err(|_| omamonero_core::Error::Payment)?
        );
        return Ok(true);
    }
    if matches!(args.command, Commands::Proof) {
        use std::io::Read;
        let config = Config::load(args.config.as_deref())?;
        let mut raw = String::new();
        std::io::stdin()
            .take(16385)
            .read_to_string(&mut raw)
            .map_err(|_| omamonero_core::Error::Payment)?;
        if raw.len() > 16384 {
            return Err(omamonero_core::Error::Payment);
        }
        let proof: omamonero_core::modules::ProofRequest =
            serde_json::from_str(&raw).map_err(|_| omamonero_core::Error::Payment)?;
        omamonero_core::payments::validate_address(&proof.address, config.network)
            .map_err(|_| omamonero_core::Error::Payment)?;
        let result = omamonero_core::modules::check_proof(&config.modules, proof)
            .await
            .map_err(|_| omamonero_core::Error::Payment)?;
        println!("{result}");
        return Ok(true);
    }
    let parent = writer::runtime_parent(args.runtime_dir)?;
    if matches!(args.command, Commands::Status) {
        return match writer::read(&parent)? {
            Some(snapshot) => {
                println!(
                    "{}",
                    serde_json::to_string(&snapshot).map_err(|_| omamonero_core::Error::State)?
                );
                Ok(snapshot.fresh() && snapshot.healthy())
            }
            None => {
                println!("{{\"state\":\"missing\"}}");
                Ok(false)
            }
        };
    }
    let config = Config::load(args.config.as_deref())?;
    match args.command {
        Commands::Daemon => {
            app::daemon(&config, &parent).await?;
            Ok(true)
        }
        Commands::Once => {
            let snapshot = app::once(&config, &parent).await?;
            println!(
                "{}",
                serde_json::to_string(&snapshot).map_err(|_| omamonero_core::Error::State)?
            );
            Ok(snapshot.healthy())
        }
        Commands::Doctor => {
            let (report, ok) = doctor::diagnose(&config, &parent).await?;
            println!("{}", report);
            Ok(ok)
        }
        Commands::Status | Commands::CheckConfig | Commands::Payment | Commands::Proof => {
            unreachable!()
        }
    }
}
