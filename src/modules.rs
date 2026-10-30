//! Explicitly configured, local, read-only wallet and miner telemetry.
use reqwest::{Client, Url, redirect::Policy};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use std::{
    io::Read,
    net::IpAddr,
    path::{Path, PathBuf},
    time::{Duration, SystemTime, UNIX_EPOCH},
};
const LIMIT: usize = 512 * 1024;
const UNAVAILABLE: &str = "Local service unavailable or invalid response";
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct ModulesConfig {
    pub wallet_rpc: Option<String>,
    pub watch_only_confirmed: bool,
    pub notify_payments: bool,
    pub xmrig_url: Option<String>,
    pub p2pool_directory: Option<PathBuf>,
}
fn origin(raw: &str) -> Result<Url, String> {
    let url = Url::parse(raw).map_err(|_| "Use a numeric loopback HTTP origin".to_owned())?;
    let host = url
        .host_str()
        .unwrap_or("")
        .trim_start_matches('[')
        .trim_end_matches(']');
    if url.scheme() != "http"
        || !host.parse::<IpAddr>().is_ok_and(|a| a.is_loopback())
        || !url.username().is_empty()
        || url.password().is_some()
        || url.path() != "/"
        || url.query().is_some()
        || url.fragment().is_some()
    {
        return Err("Use a numeric loopback HTTP origin without credentials or path".into());
    }
    Ok(url)
}
impl ModulesConfig {
    pub fn validate(&self) -> Result<(), String> {
        for raw in [&self.wallet_rpc, &self.xmrig_url].into_iter().flatten() {
            origin(raw)?;
        }
        if self
            .p2pool_directory
            .as_ref()
            .is_some_and(|p| !p.is_absolute())
        {
            return Err("P2Pool data directory must be absolute".into());
        }
        Ok(())
    }
}
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct Modules {
    pub wallet: Wallet,
    pub xmrig: Xmrig,
    pub p2pool: P2Pool,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Wallet {
    pub state: String,
    pub error: Option<String>,
    pub updated_at: Option<u64>,
    #[serde(with = "optional_atomic")]
    pub balance_atomic: Option<u64>,
    #[serde(with = "optional_atomic")]
    pub unlocked_balance_atomic: Option<u64>,
    pub address: Option<String>,
    pub incoming: Vec<Incoming>,
    #[serde(default)]
    pub incoming_error: Option<String>,
    #[serde(default)]
    pub coverage_from_height: Option<u64>,
}
impl Default for Wallet {
    fn default() -> Self {
        Self {
            state: "disabled".into(),
            error: None,
            updated_at: None,
            balance_atomic: None,
            unlocked_balance_atomic: None,
            address: None,
            incoming: vec![],
            incoming_error: None,
            coverage_from_height: None,
        }
    }
}
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Incoming {
    pub txid: String,
    #[serde(with = "atomic")]
    pub amount_atomic: u64,
    pub confirmations: Option<u64>,
    pub timestamp: Option<u64>,
    pub in_pool: bool,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Xmrig {
    pub state: String,
    pub error: Option<String>,
    pub updated_at: Option<u64>,
    pub hashrate: Option<f64>,
    pub shares_good: Option<u64>,
    pub shares_total: Option<u64>,
    pub uptime: Option<u64>,
}
impl Default for Xmrig {
    fn default() -> Self {
        Self {
            state: "disabled".into(),
            error: None,
            updated_at: None,
            hashrate: None,
            shares_good: None,
            shares_total: None,
            uptime: None,
        }
    }
}
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct P2Pool {
    pub state: String,
    pub error: Option<String>,
    pub updated_at: Option<u64>,
    pub hashrate_15m: Option<u64>,
    pub hashrate_1h: Option<u64>,
    pub hashrate_24h: Option<u64>,
    pub shares_found: Option<u64>,
    pub connections: Option<u64>,
}
impl Default for P2Pool {
    fn default() -> Self {
        Self {
            state: "disabled".into(),
            error: None,
            updated_at: None,
            hashrate_15m: None,
            hashrate_1h: None,
            hashrate_24h: None,
            shares_found: None,
            connections: None,
        }
    }
}
fn now() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}
fn client() -> Result<Client, String> {
    Client::builder()
        .no_proxy()
        .redirect(Policy::none())
        .timeout(Duration::from_secs(4))
        .connect_timeout(Duration::from_secs(2))
        .build()
        .map_err(|_| UNAVAILABLE.into())
}
async fn bounded(request: reqwest::RequestBuilder) -> Result<Value, String> {
    let mut response = request.send().await.map_err(|_| UNAVAILABLE.to_owned())?;
    if response.status() == reqwest::StatusCode::UNAUTHORIZED
        || response.status() == reqwest::StatusCode::FORBIDDEN
    {
        return Err("Endpoint authentication is unsupported".into());
    }
    if !response.status().is_success()
        || response.content_length().is_some_and(|n| n > LIMIT as u64)
    {
        return Err(UNAVAILABLE.into());
    }
    let mut bytes = Vec::new();
    while let Some(chunk) = response.chunk().await.map_err(|_| UNAVAILABLE.to_owned())? {
        if bytes.len() + chunk.len() > LIMIT {
            return Err(UNAVAILABLE.into());
        }
        bytes.extend_from_slice(&chunk);
    }
    serde_json::from_slice(&bytes).map_err(|_| UNAVAILABLE.into())
}
async fn rpc(c: &Client, raw: &str, method: &str, params: Value) -> Result<Value, String> {
    let mut url = origin(raw)?;
    url.set_path("/json_rpc");
    let v = bounded(
        c.post(url)
            .json(&json!({"jsonrpc":"2.0","id":"omamonero","method":method,"params":params})),
    )
    .await?;
    if v.get("error").is_some() {
        return Err(UNAVAILABLE.into());
    }
    v.get("result")
        .filter(|v| v.is_object())
        .cloned()
        .ok_or_else(|| UNAVAILABLE.into())
}
fn integer(v: &Value, key: &str) -> Result<u64, String> {
    v.get(key)
        .and_then(Value::as_u64)
        .ok_or_else(|| UNAVAILABLE.into())
}
fn hex_txid(s: &str) -> bool {
    s.len() == 64 && s.bytes().all(|b| b.is_ascii_hexdigit())
}
async fn wallet(_config: &ModulesConfig, c: &Client, raw: &str) -> Result<Wallet, String> {
    let b = rpc(c, raw, "get_balance", json!({"account_index":0})).await?;
    let balance = integer(&b, "balance")?;
    let unlocked = integer(&b, "unlocked_balance")?;
    let a = rpc(c, raw, "get_address", json!({"account_index":0})).await?;
    let address = a
        .get("address")
        .and_then(Value::as_str)
        .filter(|s| s.len() <= 106 && s.chars().all(|c| c.is_ascii_alphanumeric()))
        .ok_or(UNAVAILABLE)?;
    let mut result = Wallet {
        state: "ready".into(),
        updated_at: Some(now()),
        balance_atomic: Some(balance),
        unlocked_balance_atomic: Some(unlocked),
        address: Some(address.into()),
        ..Wallet::default()
    };
    // Never request the entire wallet history. Failure of optional history must
    // not hide otherwise valid balance/address data or expose upstream messages.
    let history = async {
        let height = integer(&rpc(c, raw, "get_height", json!({})).await?, "height")?;
        let from = height.saturating_sub(720);
        result.coverage_from_height = Some(from);
        let t = rpc(
            c,
            raw,
            "get_transfers",
            json!({
                "in":true,"pool":true,"out":false,"pending":false,"failed":false,
                "account_index":0,"filter_by_height":true,"min_height":from,"max_height":height
            }),
        )
        .await?;
        let mut incoming = vec![];
        for (key, in_pool) in [("in", false), ("pool", true)] {
            if let Some(rows) = t.get(key) {
                for row in rows.as_array().ok_or(UNAVAILABLE)? {
                    let txid = row
                        .get("txid")
                        .and_then(Value::as_str)
                        .filter(|s| hex_txid(s))
                        .ok_or(UNAVAILABLE)?;
                    incoming.push(Incoming {
                        txid: txid.into(),
                        amount_atomic: integer(row, "amount")?,
                        confirmations: row.get("confirmations").and_then(Value::as_u64),
                        timestamp: row.get("timestamp").and_then(Value::as_u64),
                        in_pool,
                    });
                }
            }
        }
        // Empty result is a valid wallet history; arbitrary unrelated objects are not.
        if t.get("in").is_none()
            && t.get("pool").is_none()
            && !t.as_object().is_some_and(|o| o.is_empty())
        {
            return Err(UNAVAILABLE.to_owned());
        }
        incoming.sort_by_key(|i| std::cmp::Reverse(i.timestamp.unwrap_or(0)));
        incoming.truncate(20);
        Ok::<_, String>(incoming)
    }
    .await;
    match history {
        Ok(incoming) => result.incoming = incoming,
        Err(_) => {
            result.incoming_error = Some(
                "Recent incoming payments unavailable; balance and address remain available".into(),
            )
        }
    }
    Ok(result)
}
async fn xmrig(c: &Client, raw: &str) -> Result<Xmrig, String> {
    let mut url = origin(raw)?;
    url.set_path("/2/summary");
    let v = bounded(c.get(url)).await?;
    let hashrate = v
        .pointer("/hashrate/total/0")
        .and_then(Value::as_f64)
        .filter(|n| n.is_finite() && *n >= 0.0);
    if v.get("hashrate").is_none() || v.get("results").is_none() {
        return Err(UNAVAILABLE.into());
    }
    Ok(Xmrig {
        state: "ready".into(),
        error: None,
        updated_at: Some(now()),
        hashrate,
        shares_good: v.pointer("/results/shares_good").and_then(Value::as_u64),
        shares_total: v.pointer("/results/shares_total").and_then(Value::as_u64),
        uptime: v.pointer("/connection/uptime").and_then(Value::as_u64),
    })
}
// P2Pool --data-api DIR --local-api publishes DIR/local/stratum.
// Structure: SChernykh/p2pool src/stratum_server.cpp::api_update_local_stats.
fn p2pool(path: &Path) -> Result<P2Pool, String> {
    use std::os::unix::fs::OpenOptionsExt;
    let path = path.join("local/stratum");
    let file = std::fs::OpenOptions::new()
        .read(true)
        .custom_flags(libc::O_NOFOLLOW | libc::O_NONBLOCK)
        .open(path)
        .map_err(|_| UNAVAILABLE)?;
    let meta = file.metadata().map_err(|_| UNAVAILABLE)?;
    if !meta.is_file() || meta.len() > LIMIT as u64 {
        return Err(UNAVAILABLE.into());
    }
    let modified = meta
        .modified()
        .ok()
        .and_then(|t| t.duration_since(UNIX_EPOCH).ok())
        .map(|d| d.as_secs())
        .ok_or(UNAVAILABLE)?;
    let mut bytes = vec![];
    file.take((LIMIT + 1) as u64)
        .read_to_end(&mut bytes)
        .map_err(|_| UNAVAILABLE)?;
    if bytes.len() > LIMIT {
        return Err(UNAVAILABLE.into());
    }
    let v: Value = serde_json::from_slice(&bytes).map_err(|_| UNAVAILABLE)?;
    Ok(P2Pool {
        state: if now().saturating_sub(modified) > 120 {
            "stale"
        } else {
            "ready"
        }
        .into(),
        error: None,
        updated_at: Some(modified),
        hashrate_15m: Some(integer(&v, "hashrate_15m")?),
        hashrate_1h: Some(integer(&v, "hashrate_1h")?),
        hashrate_24h: Some(integer(&v, "hashrate_24h")?),
        shares_found: Some(integer(&v, "shares_found")?),
        connections: Some(integer(&v, "connections")?),
    })
}
pub async fn poll(config: &ModulesConfig) -> Modules {
    let mut out = Modules::default();
    let c = client();
    if let Some(raw) = &config.wallet_rpc {
        if !config.watch_only_confirmed {
            out.wallet.state = "confirmation_required".into()
        } else {
            match &c {
                Ok(c) => match wallet(config, c, raw).await {
                    Ok(v) => out.wallet = v,
                    Err(e) => {
                        out.wallet.state = "unavailable".into();
                        out.wallet.error = Some(e)
                    }
                },
                Err(e) => {
                    out.wallet.state = "unavailable".into();
                    out.wallet.error = Some(e.clone())
                }
            }
        }
    }
    if let Some(raw) = &config.xmrig_url {
        match &c {
            Ok(c) => match xmrig(c, raw).await {
                Ok(v) => out.xmrig = v,
                Err(e) => {
                    out.xmrig.state = "unavailable".into();
                    out.xmrig.error = Some(e)
                }
            },
            Err(e) => {
                out.xmrig.state = "unavailable".into();
                out.xmrig.error = Some(e.clone())
            }
        }
    }
    if let Some(path) = &config.p2pool_directory {
        let path = path.clone();
        match tokio::task::spawn_blocking(move || p2pool(&path)).await {
            Ok(Ok(v)) => out.p2pool = v,
            _ => {
                out.p2pool.state = "unavailable".into();
                out.p2pool.error=Some("P2Pool local/stratum is unavailable or invalid; enable its data API and local API".into())
            }
        }
    }
    out
}
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ProofRequest {
    pub txid: String,
    pub address: String,
    pub message: String,
    pub signature: String,
}
pub async fn check_proof(config: &ModulesConfig, proof: ProofRequest) -> Result<Value, String> {
    if !hex_txid(&proof.txid)
        || !(proof.address.len() == 95 || proof.address.len() == 106)
        || !proof.address.bytes().all(|b| b.is_ascii_alphanumeric())
        || proof.message.len() > 4096
        || proof.signature.len() > 8192
        || proof.signature.is_empty()
        || !proof.signature.bytes().all(|b| b.is_ascii_alphanumeric())
    {
        return Err("Invalid transaction proof input".into());
    }
    if !config.watch_only_confirmed {
        return Err("Confirm the local wallet is watch-only before connecting".into());
    }
    let raw = config
        .wallet_rpc
        .as_deref()
        .ok_or("Configure a local wallet RPC first")?;
    let v=rpc(&client()?,raw,"check_tx_proof",json!({"txid":proof.txid,"address":proof.address,"message":proof.message,"signature":proof.signature})).await?;
    let good = v.get("good").and_then(Value::as_bool).ok_or(UNAVAILABLE)?;
    if !good {
        return Ok(json!({"good":false}));
    }
    Ok(
        json!({"good":true,"received":integer(&v,"received")?,"confirmations":integer(&v,"confirmations")?,"in_pool":v.get("in_pool").and_then(Value::as_bool).ok_or(UNAVAILABLE)?}),
    )
}

mod atomic {
    use serde::{Deserialize, Deserializer, Serializer, de::Error};
    pub fn serialize<S: Serializer>(value: &u64, serializer: S) -> Result<S::Ok, S::Error> {
        serializer.serialize_str(&value.to_string())
    }
    pub fn deserialize<'de, D: Deserializer<'de>>(deserializer: D) -> Result<u64, D::Error> {
        let value = serde_json::Value::deserialize(deserializer)?;
        value
            .as_str()
            .and_then(|v| v.parse().ok())
            .or_else(|| value.as_u64())
            .ok_or_else(|| D::Error::custom("invalid atomic amount"))
    }
}
mod optional_atomic {
    use serde::{Deserialize, Deserializer, Serialize, Serializer, de::Error};
    pub fn serialize<S: Serializer>(value: &Option<u64>, serializer: S) -> Result<S::Ok, S::Error> {
        value.map(|n| n.to_string()).serialize(serializer)
    }
    pub fn deserialize<'de, D: Deserializer<'de>>(
        deserializer: D,
    ) -> Result<Option<u64>, D::Error> {
        let value = serde_json::Value::deserialize(deserializer)?;
        if value.is_null() {
            return Ok(None);
        }
        value
            .as_str()
            .and_then(|v| v.parse().ok())
            .or_else(|| value.as_u64())
            .map(Some)
            .ok_or_else(|| D::Error::custom("invalid atomic amount"))
    }
}

#[derive(Default)]
pub struct IncomingTracker {
    known: std::collections::HashSet<String>,
    initialized: bool,
}
impl IncomingTracker {
    pub fn observe(&mut self, wallet: &Wallet) -> bool {
        if wallet.state != "ready" || wallet.incoming_error.is_some() {
            return false;
        }
        let new = wallet
            .incoming
            .iter()
            .any(|tx| tx.amount_atomic > 0 && !self.known.contains(&tx.txid));
        for tx in &wallet.incoming {
            self.known.insert(tx.txid.clone());
        }
        if self.known.len() > 4096 {
            self.known = wallet.incoming.iter().map(|tx| tx.txid.clone()).collect();
        }
        let notify = self.initialized && new;
        self.initialized = true;
        notify
    }
}
