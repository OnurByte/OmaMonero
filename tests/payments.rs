use omamonero_core::config::Network;
use omamonero_core::payments::{Request, build};
const ADDRESS: &str = "44AFFq5kSiGBoZ4NMDwYtN18obc8AemS33DBLWs3H7otXft3XjrpDtQGv7SqSsaBYBb98uNbr2VBBEt7f2wfn3RVGQBEP3A";
#[test]
fn receive_request_validates_and_encodes_amount_and_label() {
    let p = build(
        Request {
            address: Some(ADDRESS.into()),
            uri: None,
            amount: Some("1.250000000000".into()),
            label: Some("Invoice #1".into()),
        },
        Network::Mainnet,
    )
    .unwrap();
    assert!(p.uri.starts_with(&format!("monero:{ADDRESS}?")));
    assert!(p.uri.contains("tx_amount=1.25"));
    assert!(p.uri.contains("recipient_name=Invoice%20%231"));
    assert!(p.qr_svg.contains("<svg"));
}
#[test]
fn bad_checksum_wrong_network_and_ambiguous_requests_fail() {
    let bad = format!("{}B", &ADDRESS[..ADDRESS.len() - 1]);
    for a in [&bad, "bad-address"] {
        assert!(
            build(
                Request {
                    address: Some(a.to_string()),
                    uri: None,
                    amount: None,
                    label: None
                },
                Network::Mainnet
            )
            .is_err()
        );
    }
    assert!(
        build(
            Request {
                address: Some(ADDRESS.into()),
                uri: None,
                amount: None,
                label: None
            },
            Network::Stagenet
        )
        .is_err()
    );
    for query in [
        "tx_amount=-1",
        "tx_amount=1e3",
        "tx_amount=1.0000000000001",
        "req-unknown=1",
        "tx_amount=1&tx_amount=2",
        "payment_id=123",
    ] {
        assert!(
            build(
                Request {
                    address: None,
                    uri: Some(format!("monero:{ADDRESS}?{query}")),
                    amount: None,
                    label: None
                },
                Network::Mainnet
            )
            .is_err()
        );
    }
}
#[test]
fn incoming_uri_is_parsed_without_spending_or_launching() {
    let p = build(
        Request {
            address: None,
            uri: Some(format!(
                "monero:{ADDRESS}?tx_amount=0.1&recipient_name=Test%20Shop"
            )),
            amount: None,
            label: None,
        },
        Network::Mainnet,
    )
    .unwrap();
    assert_eq!(p.address, ADDRESS);
    assert_eq!(p.amount.as_deref(), Some("0.1"));
    assert_eq!(p.label.as_deref(), Some("Test Shop"));
    assert!(
        build(
            Request {
                address: None,
                uri: Some("https://example.com".into()),
                amount: None,
                label: None
            },
            Network::Mainnet
        )
        .is_err()
    );
}
