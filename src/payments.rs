//! Local public-address requests only. Never opens a wallet or handles secret keys.
use crate::config::Network;
use monero::util::address::Address;
use qrcode::{QrCode, render::svg};
use serde::{Deserialize, Serialize};
use std::{collections::HashSet, str::FromStr};

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Request {
    pub address: Option<String>,
    pub uri: Option<String>,
    pub amount: Option<String>,
    pub label: Option<String>,
}
#[derive(Serialize)]
pub struct Payment {
    pub address: String,
    pub amount: Option<String>,
    pub label: Option<String>,
    pub description: Option<String>,
    pub uri: String,
    pub qr_svg: String,
}
type Result<T> = std::result::Result<T, &'static str>;
fn amount(value: &str) -> Result<String> {
    if value.len() > 32
        || value.is_empty()
        || !value.bytes().all(|b| b.is_ascii_digit() || b == b'.')
    {
        return Err("Invalid XMR amount; use at most 12 decimal places");
    }
    let parts: Vec<_> = value.split('.').collect();
    if parts.len() > 2
        || parts[0].is_empty()
        || parts.get(1).is_some_and(|v| v.len() > 12 || v.is_empty())
    {
        return Err("Invalid XMR amount; use at most 12 decimal places");
    }
    let whole = parts[0].parse::<u64>().map_err(|_| "Invalid XMR amount")?;
    if whole > 1_000_000_000 {
        return Err("XMR amount is too large");
    }
    let fraction = parts.get(1).copied().unwrap_or("").trim_end_matches('0');
    if whole == 0 && fraction.is_empty() {
        return Err("Amount must be positive, or left empty");
    }
    Ok(if fraction.is_empty() {
        whole.to_string()
    } else {
        format!("{whole}.{fraction}")
    })
}
fn text(value: Option<String>) -> Result<Option<String>> {
    match value {
        Some(v) if v.len() > 160 || v.chars().any(|c| c.is_control() || c == '\u{fffd}') => {
            Err("Request text is invalid")
        }
        Some(v) if v.is_empty() => Ok(None),
        other => Ok(other),
    }
}
pub fn validate_address(value: &str, network: Network) -> Result<()> {
    let address = Address::from_str(value).map_err(|_| "Invalid Monero address or checksum")?;
    let expected = match network {
        Network::Mainnet => monero::Network::Mainnet,
        Network::Testnet => monero::Network::Testnet,
        Network::Stagenet => monero::Network::Stagenet,
    };
    if address.network != expected {
        return Err("The address belongs to a different Monero network");
    }
    Ok(())
}
pub fn build(request: Request, network: Network) -> Result<Payment> {
    let (address, raw_amount, label, description) = match (request.address, request.uri) {
        (Some(address), None) => (address, request.amount, request.label, None),
        (None, Some(uri)) => {
            if uri.len() > 2048 || request.amount.is_some() || request.label.is_some() {
                return Err("Ambiguous payment request");
            }
            let parsed = reqwest::Url::parse(&uri).map_err(|_| "Invalid monero: request")?;
            if parsed.scheme() != "monero" || parsed.host().is_some() || parsed.fragment().is_some()
            {
                return Err("Only monero: payment links are supported");
            }
            let mut seen = HashSet::new();
            let mut raw_amount = None;
            let mut label = None;
            let mut description = None;
            for (key, value) in parsed.query_pairs() {
                if !seen.insert(key.to_string()) {
                    return Err("Duplicate payment parameters");
                }
                match key.as_ref() {
                    "tx_amount" => raw_amount = Some(value.into_owned()),
                    "recipient_name" => label = Some(value.into_owned()),
                    "tx_description" => description = Some(value.into_owned()),
                    _ => return Err("Unsupported payment parameter"),
                }
            }
            (parsed.path().to_string(), raw_amount, label, description)
        }
        _ => return Err("Provide one public address or one monero: link"),
    };
    validate_address(&address, network)?;
    let amount = raw_amount
        .filter(|v| !v.is_empty())
        .map(|v| amount(&v))
        .transpose()?;
    let label = text(label)?;
    let description = text(description)?;
    let mut url =
        reqwest::Url::parse(&format!("monero:{address}")).map_err(|_| "Invalid address")?;
    if amount.is_some() || label.is_some() || description.is_some() {
        let mut pairs = url.query_pairs_mut();
        if let Some(v) = &amount {
            pairs.append_pair("tx_amount", v);
        }
        if let Some(v) = &label {
            pairs.append_pair("recipient_name", v);
        }
        if let Some(v) = &description {
            pairs.append_pair("tx_description", v);
        }
    }
    let uri = url.to_string().replace('+', "%20");
    let qr = QrCode::new(uri.as_bytes()).map_err(|_| "Request is too long for a QR code")?;
    let qr_svg = qr
        .render::<svg::Color>()
        .min_dimensions(320, 320)
        .quiet_zone(true)
        .dark_color(svg::Color("#111111"))
        .light_color(svg::Color("#ffffff"))
        .build();
    Ok(Payment {
        address,
        amount,
        label,
        description,
        uri,
        qr_svg,
    })
}
