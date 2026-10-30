use crate::{
    Result,
    config::Config,
    rpc::daemon::RpcClient,
    state::{snapshot::Snapshot, writer},
};
use serde_json::{Value, json};
use std::path::Path;

pub async fn diagnose(config: &Config, parent: &Path) -> Result<(Value, bool)> {
    let rpc = Snapshot::new(config, RpcClient::new(config)?.poll().await);
    let (snapshot, cache_ok) = match writer::read(parent) {
        Ok(Some(s)) if !s.fresh() => (json!({"state":"stale_or_incompatible"}), false),
        Ok(Some(s)) => (
            json!({"state":if s.healthy(){"fresh"}else{"unhealthy"},"generated_at":s.generated_at}),
            s.healthy(),
        ),
        Ok(None) => (json!({"state":"missing"}), false),
        Err(_) => (json!({"state":"invalid_or_unsafe"}), false),
    };
    let ok = rpc.healthy() && cache_ok;
    Ok((
        json!({"ok":ok,"rpc":rpc,"snapshot":snapshot,"notes":["Node data is self-reported by the configured RPC endpoint.","Monerod P2P privacy has not been verified.","doctor does not start services or modify files."]}),
        ok,
    ))
}
