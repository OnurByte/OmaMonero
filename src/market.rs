//! Opt-in public market data. Never uses wallet/node credentials or environment proxies.
use crate::{config::Config, state::snapshot::now};
use reqwest::{Client, redirect::Policy};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::time::Duration;

pub const REFRESH_SECS: u64 = 120;
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
#[serde(tag = "state", rename_all = "snake_case")]
pub enum Market {
    #[default]
    Disabled,
    Ready(Quote),
    Unavailable {
        error: MarketError,
    },
}
#[derive(Clone, Copy, Debug, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum MarketError {
    Connection,
    Timeout,
    HttpError,
    InvalidResponse,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Point {
    pub timestamp: u64,
    pub price: f64,
}
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Quote {
    pub source: String,
    pub currency: String,
    pub fetched_at: u64,
    pub stale_after_secs: u64,
    pub sample_interval_secs: u64,
    pub price: f64,
    pub change_percent: f64,
    pub points: Vec<Point>,
}
fn price(value: &Value) -> Result<f64, MarketError> {
    let p = value
        .as_str()
        .and_then(|v| v.parse::<f64>().ok())
        .ok_or(MarketError::InvalidResponse)?;
    if !p.is_finite() || p <= 0.0 || p > 1_000_000_000.0 {
        return Err(MarketError::InvalidResponse);
    }
    Ok(p)
}
pub fn parse_ohlc(raw: &str, time: u64) -> Result<Quote, MarketError> {
    parse_ohlc_interval(raw, time, 3600)
}

/// Map a user-selected public JSON API to the common XMR/USD trailing-day chart.
/// Timestamps in mapped history must be Unix seconds and the source must keep
/// at least 24 hours of ordered samples in the configured interval.
pub fn parse_custom_json(
    raw: &str,
    time: u64,
    source: &str,
    price_pointer: &str,
    points_pointer: &str,
    timestamp_pointer: &str,
    point_price_pointer: &str,
    interval: u64,
) -> Result<Quote, MarketError> {
    let invalid = MarketError::InvalidResponse;
    if source.trim().is_empty()
        || source.len() > 48
        || raw.len() > 1_048_576
        || ![300, 900, 1800, 3600].contains(&interval)
        || ![
            price_pointer,
            points_pointer,
            timestamp_pointer,
            point_price_pointer,
        ]
        .iter()
        .all(|pointer| pointer.starts_with('/') && pointer.len() <= 256)
    {
        return Err(invalid);
    }
    let body: Value = serde_json::from_str(raw).map_err(|_| invalid)?;
    let read_price = |value: &Value, pointer: &str| -> Result<f64, MarketError> {
        let value = value.pointer(pointer).ok_or(invalid)?;
        let number = value
            .as_f64()
            .or_else(|| value.as_str()?.parse().ok())
            .ok_or(invalid)?;
        if !number.is_finite() || number <= 0.0 || number > 1_000_000_000.0 {
            return Err(invalid);
        }
        Ok(number)
    };
    let current = read_price(&body, price_pointer)?;
    let rows = body
        .pointer(points_pointer)
        .and_then(Value::as_array)
        .ok_or(invalid)?;
    if !(2..=400).contains(&rows.len()) {
        return Err(invalid);
    }
    let mut points = Vec::with_capacity(rows.len() + 1);
    let mut previous = 0;
    for row in rows {
        let timestamp_value = row.pointer(timestamp_pointer).ok_or(invalid)?;
        let timestamp = timestamp_value
            .as_u64()
            .or_else(|| timestamp_value.as_str()?.parse().ok())
            .ok_or(invalid)?;
        if timestamp == 0
            || timestamp > time
            || (previous > 0 && (timestamp <= previous || timestamp - previous > interval * 2))
        {
            return Err(invalid);
        }
        previous = timestamp;
        points.push(Point {
            timestamp,
            price: read_price(row, point_price_pointer)?,
        });
    }
    if time.saturating_sub(previous) > interval + 180 {
        return Err(invalid);
    }
    if previous < time {
        points.push(Point {
            timestamp: time,
            price: current,
        });
    } else if let Some(last) = points.last_mut() {
        last.price = current;
    }
    let cutoff = time.checked_sub(86400).ok_or(invalid)?;
    let mut baseline = None;
    for pair in points.windows(2) {
        if pair[0].timestamp <= cutoff && pair[1].timestamp >= cutoff {
            let ratio = (cutoff - pair[0].timestamp) as f64
                / (pair[1].timestamp - pair[0].timestamp) as f64;
            baseline = Some(pair[0].price + (pair[1].price - pair[0].price) * ratio);
            break;
        }
    }
    let baseline = baseline.ok_or(invalid)?;
    let change = (current - baseline) / baseline * 100.0;
    if !change.is_finite() {
        return Err(invalid);
    }
    points.retain(|point| point.timestamp > cutoff);
    points.insert(
        0,
        Point {
            timestamp: cutoff,
            price: baseline,
        },
    );
    if !(2..=400).contains(&points.len()) {
        return Err(invalid);
    }
    Ok(Quote {
        source: source.trim().to_owned(),
        currency: "USD".into(),
        fetched_at: time,
        stale_after_secs: 360,
        sample_interval_secs: interval,
        price: current,
        change_percent: change,
        points,
    })
}
/// Convert committed closes and the latest provisional close into a trailing day.
pub fn parse_ohlc_interval(raw: &str, time: u64, interval: u64) -> Result<Quote, MarketError> {
    let invalid = MarketError::InvalidResponse;
    if ![300, 3600].contains(&interval) {
        return Err(invalid);
    }
    let body: Value = serde_json::from_str(raw).map_err(|_| invalid)?;
    if !body
        .get("error")
        .and_then(Value::as_array)
        .is_some_and(Vec::is_empty)
    {
        return Err(invalid);
    }
    let rows = body
        .pointer("/result/XXMRZUSD")
        .and_then(Value::as_array)
        .ok_or(invalid)?;
    if !(2..=721).contains(&rows.len()) {
        return Err(invalid);
    }
    let mut points: Vec<Point> = Vec::new();
    let mut previous = 0;
    for (index, row) in rows.iter().enumerate() {
        let fields = row.as_array().filter(|v| v.len() == 8).ok_or(invalid)?;
        let start = fields[0]
            .as_u64()
            .filter(|s| *s > 0 && *s <= time)
            .ok_or(invalid)?;
        if index > 0 && (start <= previous || start - previous > interval * 2) {
            return Err(invalid);
        }
        previous = start;
        if index == 0 {
            points.push(Point {
                timestamp: start,
                price: price(&fields[1])?,
            });
        }
        let p = price(&fields[4])?;
        let end = if index == rows.len() - 1 {
            if time - start > interval + 180 {
                return Err(invalid);
            }
            time
        } else {
            start.checked_add(interval).ok_or(invalid)?
        };
        if end > time {
            return Err(invalid);
        }
        if points.last().is_some_and(|p| p.timestamp == end) {
            points.pop();
        }
        points.push(Point {
            timestamp: end,
            price: p,
        });
    }
    let cutoff = time.checked_sub(86400).ok_or(invalid)?;
    let mut anchor = None;
    for pair in points.windows(2) {
        if pair[0].timestamp <= cutoff && pair[1].timestamp >= cutoff {
            let delta = pair[1].timestamp - pair[0].timestamp;
            if delta == 0 {
                return Err(invalid);
            }
            let ratio = (cutoff - pair[0].timestamp) as f64 / delta as f64;
            anchor = Some(pair[0].price + (pair[1].price - pair[0].price) * ratio);
            break;
        }
    }
    let baseline = anchor.ok_or(invalid)?;
    let current = points.last().ok_or(invalid)?.price;
    let change = (current - baseline) / baseline * 100.0;
    if !change.is_finite() {
        return Err(invalid);
    }
    points.retain(|p| p.timestamp > cutoff);
    points.insert(
        0,
        Point {
            timestamp: cutoff,
            price: baseline,
        },
    );
    if !(2..=400).contains(&points.len()) {
        return Err(invalid);
    }
    Ok(Quote {
        source: "Kraken".into(),
        currency: "USD".into(),
        fetched_at: time,
        stale_after_secs: 360,
        sample_interval_secs: interval,
        price: current,
        change_percent: change,
        points,
    })
}
pub async fn fetch(config: &Config) -> Market {
    if !config.market_enabled {
        return Market::Disabled;
    }
    match request(config).await {
        Ok(quote) => Market::Ready(quote),
        Err(error) => Market::Unavailable { error },
    }
}
async fn request(config: &Config) -> Result<Quote, MarketError> {
    let invalid = MarketError::InvalidResponse;
    let mut builder = Client::builder()
        .no_proxy()
        .redirect(Policy::none())
        .timeout(Duration::from_secs(8))
        .connect_timeout(Duration::from_secs(5));
    if let Some(proxy) = &config.proxy {
        builder = builder.proxy(reqwest::Proxy::all(proxy).map_err(|_| invalid)?);
    }
    let client = builder.build().map_err(|_| invalid)?;
    let time = now();
    let mut response = if config.market_source.url.is_empty() {
        client
            .get("https://api.kraken.com/0/public/OHLC")
            .query(&[
                ("pair", "XMRUSD"),
                ("interval", "5"),
                ("since", &time.saturating_sub(90000).to_string()),
            ])
            .send()
            .await
            .map_err(network_error)?
    } else {
        client
            .get(&config.market_source.url)
            .send()
            .await
            .map_err(network_error)?
    };
    if !response.status().is_success() {
        return Err(MarketError::HttpError);
    }
    const LIMIT: usize = 1048576;
    if response.content_length().is_some_and(|n| n > LIMIT as u64) {
        return Err(invalid);
    }
    let mut data = Vec::new();
    while let Some(chunk) = response.chunk().await.map_err(network_error)? {
        if data.len() + chunk.len() > LIMIT {
            return Err(invalid);
        }
        data.extend_from_slice(&chunk);
    }
    let text = std::str::from_utf8(&data).map_err(|_| invalid)?;
    // Use response completion time for the provisional candle's latest close.
    if config.market_source.url.is_empty() {
        parse_ohlc_interval(text, now(), 300)
    } else {
        parse_custom_json(
            text,
            now(),
            &config.market_source.name,
            &config.market_source.price_pointer,
            &config.market_source.points_pointer,
            &config.market_source.timestamp_pointer,
            &config.market_source.point_price_pointer,
            config.market_source.interval_secs,
        )
    }
}
fn network_error(error: reqwest::Error) -> MarketError {
    if error.is_timeout() {
        MarketError::Timeout
    } else {
        MarketError::Connection
    }
}
