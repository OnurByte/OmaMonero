use crate::{
    Error, Result,
    config::{Config, Network},
    state::snapshot::{Metrics, Node, RpcError},
};
use reqwest::{Client, Url, redirect::Policy};
use serde::Deserialize;
use serde_json::{Value, json};
use std::time::Instant;

const MAX_RESPONSE: usize = 1024 * 1024;
#[derive(Deserialize)]
struct Info {
    height: u64,
    target_height: u64,
    synchronized: bool,
    busy_syncing: bool,
    nettype: Network,
    incoming_connections_count: u64,
    outgoing_connections_count: u64,
    version: Option<String>,
    database_size: Option<u64>,
    free_space: Option<u64>,
    untrusted: bool,
}
pub struct RpcClient {
    client: Client,
    url: Url,
    network: Network,
}
impl RpcClient {
    pub fn new(config: &Config) -> Result<Self> {
        config.validate()?;
        let mut builder = Client::builder()
            .no_proxy()
            .redirect(Policy::none())
            .timeout(config.timeout())
            .connect_timeout(config.timeout());
        if let Some(proxy) = &config.proxy {
            builder = builder.proxy(reqwest::Proxy::all(proxy).map_err(|_| Error::Client)?);
        }
        let base = Url::parse(&config.endpoint).map_err(|_| Error::Config)?;
        Ok(Self {
            client: builder.build().map_err(|_| Error::Client)?,
            url: base.join("json_rpc").map_err(|_| Error::Config)?,
            network: config.network,
        })
    }
    pub async fn poll(&self) -> Node {
        match self.get_info().await {
            Ok((metrics, synced)) if synced => Node::Online(metrics),
            Ok((metrics, _)) => Node::Syncing(metrics),
            Err(error) => Node::Offline { error },
        }
    }
    async fn get_info(&self) -> std::result::Result<(Metrics, bool), RpcError> {
        let started = Instant::now();
        let mut response = self
            .client
            .post(self.url.clone())
            .json(&json!({"jsonrpc":"2.0","id":"0","method":"get_info"}))
            .send()
            .await
            .map_err(request_error)?;
        if !response.status().is_success() {
            return Err(RpcError::HttpError);
        }
        if response
            .content_length()
            .is_some_and(|n| n > MAX_RESPONSE as u64)
        {
            return Err(RpcError::ResponseTooLarge);
        }
        let mut bytes = Vec::new();
        while let Some(chunk) = response.chunk().await.map_err(request_error)? {
            if bytes.len() + chunk.len() > MAX_RESPONSE {
                return Err(RpcError::ResponseTooLarge);
            }
            bytes.extend_from_slice(&chunk);
        }
        let body: Value = serde_json::from_slice(&bytes).map_err(|_| RpcError::InvalidResponse)?;
        if body.get("error").is_some_and(|e| !e.is_null()) {
            return Err(RpcError::RpcError);
        }
        if body.get("jsonrpc").and_then(Value::as_str) != Some("2.0")
            || body.get("id") != Some(&json!("0"))
        {
            return Err(RpcError::InvalidResponse);
        }
        let result = body.get("result").ok_or(RpcError::InvalidResponse)?;
        if result.get("status").and_then(Value::as_str) != Some("OK") {
            return Err(RpcError::RpcError);
        }
        let info: Info =
            serde_json::from_value(result.clone()).map_err(|_| RpcError::InvalidResponse)?;
        if info.nettype != self.network {
            return Err(RpcError::NetworkMismatch);
        }
        if info.height == 0
            || info.version.as_ref().is_some_and(|v| {
                v.len() > 64
                    || !v
                        .chars()
                        .all(|c| c.is_ascii_alphanumeric() || ".-_+".contains(c))
            })
        {
            return Err(RpcError::InvalidResponse);
        }
        let synced = info.synchronized && !info.busy_syncing;
        let percent = if synced {
            Some(100.0)
        } else if info.target_height > 0 {
            Some((info.height as f64 / info.target_height as f64 * 100.0).min(100.0))
        } else {
            None
        };
        Ok((
            Metrics {
                height: info.height,
                target_height: info.target_height,
                sync_percent: percent,
                incoming_peers: info.incoming_connections_count,
                outgoing_peers: info.outgoing_connections_count,
                network: info.nettype,
                version: info.version,
                database_bytes: info.database_size,
                free_bytes: info.free_space,
                latency_ms: started.elapsed().as_millis().min(u64::MAX as u128) as u64,
                untrusted: info.untrusted,
            },
            synced,
        ))
    }
}
fn request_error(error: reqwest::Error) -> RpcError {
    if error.is_timeout() {
        RpcError::Timeout
    } else {
        RpcError::Connection
    }
}
