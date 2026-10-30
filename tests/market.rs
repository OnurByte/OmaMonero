use omamonero_core::market::{Market, parse_ohlc};
use serde_json::{Value, json};
fn candles() -> Value {
    let rows: Vec<Value> = (0..=24)
        .map(|n| {
            json!([
                100000 + n * 3600,
                "100",
                "120",
                "80",
                format!("{}", 100 + n),
                "100",
                "1",
                1
            ])
        })
        .collect();
    json!({"error":[],"result":{"XXMRZUSD":rows,"last":186400}})
}
#[test]
fn hourly_chart_and_24h_change_are_computed_from_real_values() {
    let market = parse_ohlc(&candles().to_string(), 186400).unwrap();
    assert_eq!(market.source, "Kraken");
    assert_eq!(market.currency, "USD");
    assert_eq!(market.points.len(), 25);
    assert_eq!(market.price, 124.0);
    assert!((market.change_percent - 24.0).abs() < 0.00001);
}
#[test]
fn change_anchor_is_interpolated_and_old_candles_trimmed() {
    let market = parse_ohlc(&candles().to_string(), 188200).unwrap();
    // Last provisional close is timestamped now, not at the candle's start.
    assert_eq!(market.points.last().unwrap().timestamp, 188200);
    assert!(market.points.len() <= 26);
}
#[test]
fn missing_errors_old_unsorted_zero_or_unbounded_values_are_rejected() {
    let mut cases = vec![
        json!({"error":["private error"],"result":{}}),
        json!({"error":[],"result":{"last":1}}),
    ];
    for which in 0..5 {
        let mut v = candles();
        match which {
            0 => v["result"]["XXMRZUSD"][4][4] = json!("NaN"),
            1 => v["result"]["XXMRZUSD"][0][4] = json!("0"),
            2 => v["result"]["XXMRZUSD"][4][0] = json!(0),
            3 => v["result"]["XXMRZUSD"][0][4] = json!("100000000000000000000000"),
            _ => v["result"]["XXMRZUSD"] = json!([]),
        };
        cases.push(v);
    }
    for v in cases {
        assert!(parse_ohlc(&v.to_string(), 186400).is_err());
    }
    assert!(parse_ohlc(&candles().to_string(), 286400).is_err());
    assert!(parse_ohlc("{}", 186400).is_err());
    assert!(parse_ohlc("{broken", 186400).is_err());
}
#[test]
fn disabled_market_is_explicit() {
    assert_eq!(
        serde_json::to_value(Market::Disabled).unwrap()["state"],
        "disabled"
    );
}

#[test]
fn five_minute_candles_keep_real_resolution_and_provisional_time() {
    let rows: Vec<Value> = (0..=289)
        .map(|n| {
            json!([
                100000 + n * 300,
                "100",
                "120",
                "80",
                format!("{}", 100.0 + n as f64 / 100.0),
                "100",
                "1",
                1
            ])
        })
        .collect();
    let raw = json!({"error":[],"result":{"XXMRZUSD":rows}}).to_string();
    let quote = omamonero_core::market::parse_ohlc_interval(&raw, 186750, 300).unwrap();
    assert_eq!(quote.sample_interval_secs, 300);
    assert!(quote.points.len() >= 288 && quote.points.len() <= 291);
    assert_eq!(quote.points.first().unwrap().timestamp, 100350);
    assert_eq!(quote.points.last().unwrap().timestamp, 186750);
    assert!((quote.price - 102.89).abs() < 0.000001);
    assert!((quote.points[0].price - (100.0 + 0.01 / 6.0)).abs() < 0.000001);
    assert!(omamonero_core::market::parse_ohlc_interval(&raw, 187500, 300).is_err());
    assert!(omamonero_core::market::parse_ohlc_interval(&raw, 186750, 0).is_err());
}

#[test]
fn custom_json_source_maps_price_and_history_to_a_trailing_day_quote() {
    let raw = json!({
        "data": {"last": 124.0},
        "history": (0..=24).map(|n| json!({"at": 100000 + n * 3600, "close": 100 + n})).collect::<Vec<_>>()
    }).to_string();
    let quote = omamonero_core::market::parse_custom_json(
        &raw,
        186400,
        "My Exchange",
        "/data/last",
        "/history",
        "/at",
        "/close",
        3600,
    )
    .unwrap();
    assert_eq!(quote.source, "My Exchange");
    assert_eq!(quote.price, 124.0);
    assert_eq!(quote.sample_interval_secs, 3600);
    assert!((quote.change_percent - 24.0).abs() < 0.00001);
}

#[test]
fn custom_json_source_rejects_malformed_pointers_bad_prices_and_short_history() {
    let raw = json!({"price": 120.0, "points": [{"at": 186000, "price": 120.0}]}).to_string();
    assert!(
        omamonero_core::market::parse_custom_json(
            &raw, 186400, "X", "/missing", "/points", "/at", "/price", 3600
        )
        .is_err()
    );
    assert!(
        omamonero_core::market::parse_custom_json(
            &raw, 186400, "X", "/price", "/points", "/at", "/price", 3600
        )
        .is_err()
    );
    assert!(
        omamonero_core::market::parse_custom_json(
            &raw, 186400, "X", "price", "/points", "/at", "/price", 3600
        )
        .is_err()
    );
}

#[test]
fn custom_market_configuration_requires_credential_free_https_and_known_interval() {
    let mut config = omamonero_core::config::Config::default();
    config.market_source.url = "http://api.example/market.json".into();
    assert!(config.validate().is_err());
    config.market_source.url = "https://user:secret@api.example/market.json".into();
    assert!(config.validate().is_err());
    config.market_source.url = "https://api.example/market.json#fragment".into();
    assert!(config.validate().is_err());
    config.market_source.url = "https://api.example/market.json".into();
    config.market_source.interval_secs = 600;
    assert!(config.validate().is_err());
    config.market_source.interval_secs = 900;
    assert!(config.validate().is_ok());
}
