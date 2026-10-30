use crate::config::{Config, Network, Transport};
use serde::{Deserialize, Serialize};
use std::time::{SystemTime, UNIX_EPOCH};

pub const API_VERSION: u32 = 1;
pub fn now() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Snapshot {
    pub api_version: u32,
    pub backend_version: String,
    pub generated_at: u64,
    pub stale_after_secs: u64,
    pub node: Node,
    pub privacy: Privacy,
    #[serde(default)]
    pub market: crate::market::Market,
    #[serde(default)]
    pub modules: crate::modules::Modules,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Privacy {
    pub transport: Transport,
    pub p2p_verified: bool,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "state", rename_all = "snake_case")]
pub enum Node {
    Online(Metrics),
    Syncing(Metrics),
    Offline { error: RpcError },
    Stopped,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Metrics {
    pub height: u64,
    pub target_height: u64,
    pub sync_percent: Option<f64>,
    pub incoming_peers: u64,
    pub outgoing_peers: u64,
    pub network: Network,
    pub version: Option<String>,
    pub database_bytes: Option<u64>,
    pub free_bytes: Option<u64>,
    pub latency_ms: u64,
    pub untrusted: bool,
}
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RpcError {
    Connection,
    Timeout,
    HttpError,
    InvalidResponse,
    RpcError,
    NetworkMismatch,
    ResponseTooLarge,
}
impl Snapshot {
    pub fn new(config: &Config, node: Node) -> Self {
        Self {
            api_version: API_VERSION,
            market: crate::market::Market::Disabled,
            modules: crate::modules::Modules::default(),
            backend_version: env!("CARGO_PKG_VERSION").into(),
            generated_at: now(),
            stale_after_secs: config.stale_after_secs(),
            node,
            privacy: Privacy {
                transport: config.transport,
                p2p_verified: false,
            },
        }
    }
    pub fn healthy(&self) -> bool {
        matches!(self.node, Node::Online(_) | Node::Syncing(_))
    }
    pub fn fresh(&self) -> bool {
        let time = now();
        self.api_version == API_VERSION
            && self.generated_at <= time + 5
            && time.saturating_sub(self.generated_at) <= self.stale_after_secs
            && (1..=1000).contains(&self.stale_after_secs)
    }
}
