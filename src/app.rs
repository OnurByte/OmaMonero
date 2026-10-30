use crate::{
    Error, Result,
    config::Config,
    market::{self, Market},
    rpc::daemon::RpcClient,
    state::{
        snapshot::{Node, Snapshot},
        writer::StateWriter,
    },
};
use std::{path::Path, time::Duration};
use tokio::sync::watch;

pub async fn once(config: &Config, parent: &Path) -> Result<Snapshot> {
    let writer = StateWriter::new(parent)?;
    let client = RpcClient::new(config)?;
    let (node, market, modules) = tokio::join!(
        client.poll(),
        market::fetch(config),
        crate::modules::poll(&config.modules)
    );
    let mut snapshot = Snapshot::new(config, node);
    snapshot.market = market;
    snapshot.modules = modules;
    writer.write(&snapshot)?;
    Ok(snapshot)
}
pub async fn daemon(config: &Config, parent: &Path) -> Result<()> {
    let writer = StateWriter::new(parent)?;
    let client = RpcClient::new(config)?;
    let (node_tx, mut node_rx) = watch::channel(Node::Offline {
        error: crate::state::snapshot::RpcError::Connection,
    });
    let (market_tx, mut market_rx) = watch::channel(Market::Disabled);
    let (modules_tx, mut modules_rx) = watch::channel(crate::modules::Modules::default());
    let modules_config = config.modules.clone();
    let modules_task = tokio::spawn(async move {
        let mut tracker = crate::modules::IncomingTracker::default();
        loop {
            let modules = crate::modules::poll(&modules_config).await;
            if modules_config.notify_payments && tracker.observe(&modules.wallet) {
                let mut command = tokio::process::Command::new("notify-send");
                command
                    .args([
                        "OmaMonero",
                        "New incoming payment detected in your watch-only wallet.",
                    ])
                    .kill_on_drop(true);
                let _ = tokio::time::timeout(Duration::from_secs(3), command.status()).await;
            }
            if modules_tx.send(modules).is_err() {
                break;
            }
            tokio::time::sleep(Duration::from_secs(30)).await;
        }
    });
    let node_config = config.clone();
    let node_task = tokio::spawn(async move {
        loop {
            let node = client.poll().await;
            if node_tx.send(node).is_err() {
                break;
            }
            tokio::time::sleep(Duration::from_secs(node_config.poll_interval_secs)).await;
        }
    });
    let market_config = config.clone();
    let market_task = tokio::spawn(async move {
        if !market_config.market_enabled {
            return;
        }
        loop {
            let state = market::fetch(&market_config).await;
            if market_tx.send(state).is_err() {
                break;
            }
            tokio::time::sleep(Duration::from_secs(market::REFRESH_SECS)).await;
        }
    });
    let mut terminate = tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())
        .map_err(|_| Error::Signal)?;
    let interrupt = tokio::signal::ctrl_c();
    tokio::pin!(interrupt);
    let mut node = Node::Offline {
        error: crate::state::snapshot::RpcError::Connection,
    };
    let mut market = Market::Disabled;
    let mut modules = crate::modules::Modules::default();
    let mut node_time = std::time::Instant::now();
    let mut market_channel_open = config.market_enabled;
    let result = loop {
        tokio::select! {
         changed=node_rx.changed()=>{if changed.is_err(){break Err(Error::Client);}node=node_rx.borrow_and_update().clone();node_time=std::time::Instant::now();},
         changed=market_rx.changed(),if market_channel_open=>{
          if changed.is_err(){market_channel_open=false;continue;}
          market=market_rx.borrow_and_update().clone();
         },
         changed=modules_rx.changed()=>{if changed.is_err(){break Err(Error::Client);}modules=modules_rx.borrow_and_update().clone();},
         _=terminate.recv()=>break Ok(()),
         _=&mut interrupt=>break Ok(()),
        }
        let current = if node_time.elapsed().as_secs() > config.stale_after_secs() {
            Node::Offline {
                error: crate::state::snapshot::RpcError::Timeout,
            }
        } else {
            node.clone()
        };
        let mut snapshot = Snapshot::new(config, current);
        snapshot.market = market.clone();
        snapshot.modules = modules.clone();
        if let Err(error) = writer.write(&snapshot) {
            break Err(error);
        }
    };
    node_task.abort();
    market_task.abort();
    modules_task.abort();
    writer.write(&Snapshot::new(config, Node::Stopped))?;
    result
}
