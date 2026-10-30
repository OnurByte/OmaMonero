use crate::{Error, Result};
use reqwest::Url;
use serde::{Deserialize, Serialize};
use std::{
    net::IpAddr,
    path::{Path, PathBuf},
    time::Duration,
};

#[derive(Clone, Copy, Debug, Default, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum Transport {
    #[default]
    Local,
    Direct,
    Tor,
    I2p,
}
#[derive(Clone, Copy, Debug, Default, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "lowercase")]
pub enum Network {
    #[default]
    Mainnet,
    Testnet,
    Stagenet,
}
#[derive(Clone, Deserialize)]
#[serde(default, deny_unknown_fields)]
pub struct Config {
    pub endpoint: String,
    pub market_enabled: bool,
    #[serde(default)]
    pub market_source: MarketSource,
    pub modules: crate::modules::ModulesConfig,
    pub transport: Transport,
    pub proxy: Option<String>,
    pub network: Network,
    pub timeout_ms: u64,
    pub poll_interval_secs: u64,
}

#[derive(Clone, Deserialize, Serialize)]
#[serde(default, deny_unknown_fields)]
pub struct MarketSource {
    pub name: String,
    pub url: String,
    pub price_pointer: String,
    pub points_pointer: String,
    pub timestamp_pointer: String,
    pub point_price_pointer: String,
    pub interval_secs: u64,
}

impl Default for MarketSource {
    fn default() -> Self {
        Self {
            name: "Kraken".into(),
            url: String::new(),
            price_pointer: "/price".into(),
            points_pointer: "/points".into(),
            timestamp_pointer: "/timestamp".into(),
            point_price_pointer: "/price".into(),
            interval_secs: 3600,
        }
    }
}
impl Default for Config {
    fn default() -> Self {
        Self {
            endpoint: "http://127.0.0.1:18081".into(),
            market_enabled: false,
            market_source: MarketSource::default(),
            modules: crate::modules::ModulesConfig::default(),
            transport: Transport::Local,
            proxy: None,
            network: Network::Mainnet,
            timeout_ms: 3000,
            poll_interval_secs: 5,
        }
    }
}
fn loopback(url: &Url) -> bool {
    url.host_str()
        .and_then(|h| h.trim_matches(['[', ']']).parse::<IpAddr>().ok())
        .is_some_and(|ip| ip.is_loopback())
}
fn plain_authority(url: &Url) -> bool {
    url.host().is_some()
        && url.username().is_empty()
        && url.password().is_none()
        && url.query().is_none()
        && url.fragment().is_none()
        && matches!(url.path(), "" | "/")
}
impl Config {
    pub fn load(path: Option<&Path>) -> Result<Self> {
        let allow_missing = path.is_none();
        let default = default_path();
        let path = path.or(default.as_deref());
        let config: Self = match path {
            Some(p) => match std::fs::read_to_string(p) {
                Ok(text) => toml::from_str(&text).map_err(|_| Error::Config)?,
                Err(e) if e.kind() == std::io::ErrorKind::NotFound && allow_missing => {
                    Self::default()
                }
                Err(_) => return Err(Error::ConfigRead),
            },
            None => Self::default(),
        };
        config.validate()?;
        Ok(config)
    }
    pub fn validate(&self) -> Result<()> {
        self.modules.validate().map_err(|_| Error::Config)?;
        if !(1..=300).contains(&self.poll_interval_secs) || !(50..=30000).contains(&self.timeout_ms)
        {
            return Err(Error::Config);
        }
        let url = Url::parse(&self.endpoint).map_err(|_| Error::Config)?;
        if !plain_authority(&url) || !matches!(url.scheme(), "http" | "https") {
            return Err(Error::Config);
        }
        match self.transport {
            Transport::Local if !loopback(&url) || self.proxy.is_some() => {
                return Err(Error::Config);
            }
            Transport::Direct
                if self.proxy.is_some() || (url.scheme() != "https" && !loopback(&url)) =>
            {
                return Err(Error::Config);
            }
            Transport::Tor | Transport::I2p => {
                let proxy = Url::parse(self.proxy.as_deref().ok_or(Error::Config)?)
                    .map_err(|_| Error::Config)?;
                if proxy.scheme() != "socks5h"
                    || !plain_authority(&proxy)
                    || !loopback(&proxy)
                    || proxy.port().is_none()
                {
                    return Err(Error::Config);
                }
            }
            _ => {}
        }
        self.market_source.validate().map_err(|_| Error::Config)?;
        Ok(())
    }
    pub fn timeout(&self) -> Duration {
        Duration::from_millis(self.timeout_ms)
    }
    pub fn stale_after_secs(&self) -> u64 {
        (self.poll_interval_secs * 3 + self.timeout_ms.div_ceil(1000)).max(15)
    }
}

impl MarketSource {
    fn validate(&self) -> Result<()> {
        if self.name.trim().is_empty()
            || self.name.len() > 48
            || self.name.chars().any(char::is_control)
            || self.price_pointer.len() > 256
            || self.points_pointer.len() > 256
            || self.timestamp_pointer.len() > 256
            || self.point_price_pointer.len() > 256
            || !self.price_pointer.starts_with('/')
            || !self.points_pointer.starts_with('/')
            || !self.timestamp_pointer.starts_with('/')
            || !self.point_price_pointer.starts_with('/')
            || ![300, 900, 1800, 3600].contains(&self.interval_secs)
        {
            return Err(Error::Config);
        }
        if self.url.len() > 2048 {
            return Err(Error::Config);
        }
        if !self.url.is_empty() {
            let url = Url::parse(&self.url).map_err(|_| Error::Config)?;
            if url.scheme() != "https" || !plain_api_url(&url) {
                return Err(Error::Config);
            }
        }
        Ok(())
    }
}

fn plain_api_url(url: &Url) -> bool {
    url.host().is_some()
        && url.username().is_empty()
        && url.password().is_none()
        && url.fragment().is_none()
}
pub fn default_path() -> Option<PathBuf> {
    std::env::var_os("XDG_CONFIG_HOME")
        .map(PathBuf::from)
        .filter(|p| p.is_absolute())
        .or_else(|| std::env::var_os("HOME").map(|h| PathBuf::from(h).join(".config")))
        .map(|p| p.join("omamonero/config.toml"))
}
