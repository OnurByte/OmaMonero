use omamonero_core::modules::*;
use serde_json::json;
use std::{
    io::{Read, Write},
    net::TcpListener,
};
#[test]
fn endpoints_are_numeric_loopback_origins_only() {
    for url in [
        "http://localhost:18082",
        "https://127.0.0.1:18082",
        "http://127.0.0.1/a",
        "http://user:secret@127.0.0.1",
        "http://192.168.1.2",
        "http://127.0.0.1/?x=1",
    ] {
        assert!(
            ModulesConfig {
                wallet_rpc: Some(url.into()),
                ..Default::default()
            }
            .validate()
            .is_err(),
            "{url}"
        );
    }
    for url in ["http://127.0.0.1:18082", "http://[::1]:18082"] {
        ModulesConfig {
            wallet_rpc: Some(url.into()),
            ..Default::default()
        }
        .validate()
        .unwrap();
    }
}
#[tokio::test]
async fn wallet_requires_explicit_attestation() {
    let state = poll(&ModulesConfig {
        wallet_rpc: Some("http://127.0.0.1:1".into()),
        ..Default::default()
    })
    .await;
    assert_eq!(state.wallet.state, "confirmation_required");
}
fn server(replies: Vec<serde_json::Value>) -> (String, std::thread::JoinHandle<Vec<String>>) {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let url = format!("http://{}", listener.local_addr().unwrap());
    let handle = std::thread::spawn(move || {
        let mut requests = Vec::new();
        for reply in replies {
            let (mut stream, _) = listener.accept().unwrap();
            stream
                .set_read_timeout(Some(std::time::Duration::from_secs(3)))
                .unwrap();
            let mut bytes = Vec::new();
            let mut b = [0; 4096];
            loop {
                let n = stream.read(&mut b).unwrap();
                bytes.extend_from_slice(&b[..n]);
                if let Some(i) = bytes.windows(4).position(|s| s == b"\r\n\r\n") {
                    let head = String::from_utf8_lossy(&bytes[..i]);
                    let len = head
                        .lines()
                        .find_map(|s| {
                            s.to_ascii_lowercase()
                                .strip_prefix("content-length: ")
                                .map(str::to_owned)
                        })
                        .and_then(|s| s.parse::<usize>().ok())
                        .unwrap_or(0);
                    if bytes.len() >= i + 4 + len {
                        break;
                    }
                }
            }
            requests.push(String::from_utf8(bytes).unwrap());
            let body = reply.to_string();
            write!(stream,"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",body.len(),body).unwrap();
        }
        requests
    });
    (url, handle)
}
#[tokio::test]
async fn reads_fixed_wallet_methods_and_real_miner_fields() {
    let (url, handle) = server(vec![
        json!({"result":{"balance":123,"unlocked_balance":100}}),
        json!({"result":{"address":"address"}}),
        json!({"result":{"height":10000}}),
        json!({"result":{"in":[{"txid":"a".repeat(64),"amount":23,"confirmations":12,"timestamp":42}],"pool":[]}}),
    ]);
    let state = poll(&ModulesConfig {
        wallet_rpc: Some(url),
        watch_only_confirmed: true,
        ..Default::default()
    })
    .await;
    assert_eq!(state.wallet.state, "ready");
    assert_eq!(state.wallet.balance_atomic, Some(123));
    assert_eq!(state.wallet.incoming[0].confirmations, Some(12));
    let requests = handle.join().unwrap();
    for (r, m) in requests
        .iter()
        .zip(["get_balance", "get_address", "get_height", "get_transfers"])
    {
        assert!(r.contains(m));
    }
    assert!(requests[3].contains("\"out\":false"));
    let (url, handle) = server(vec![
        json!({"hashrate":{"total":[123.5,null,null]},"results":{"shares_good":12,"shares_total":13},"connection":{"uptime":42}}),
    ]);
    let state = poll(&ModulesConfig {
        xmrig_url: Some(url),
        ..Default::default()
    })
    .await;
    assert_eq!(state.xmrig.hashrate, Some(123.5));
    assert_eq!(state.xmrig.shares_good, Some(12));
    assert!(handle.join().unwrap()[0].starts_with("GET /2/summary"));
}
#[tokio::test]
async fn p2pool_reads_actual_local_stratum_and_marks_stale() {
    let d = tempfile::tempdir().unwrap();
    std::fs::create_dir(d.path().join("local")).unwrap();
    std::fs::write(d.path().join("local/stratum"),json!({"hashrate_15m":123,"hashrate_1h":100,"hashrate_24h":90,"shares_found":4,"connections":2}).to_string()).unwrap();
    let state = poll(&ModulesConfig {
        p2pool_directory: Some(d.path().into()),
        ..Default::default()
    })
    .await;
    assert_eq!(state.p2pool.state, "ready");
    assert_eq!(state.p2pool.hashrate_15m, Some(123));
    assert!(state.p2pool.updated_at.is_some());
}
#[tokio::test]
async fn upstream_secrets_never_escape_and_proofs_are_fixed() {
    let (url, handle) = server(vec![json!({"error":{"message":"private-secret"}})]);
    let state = poll(&ModulesConfig {
        wallet_rpc: Some(url),
        watch_only_confirmed: true,
        ..Default::default()
    })
    .await;
    assert!(
        !serde_json::to_string(&state)
            .unwrap()
            .contains("private-secret")
    );
    handle.join().unwrap();
    let (url, handle) = server(vec![
        json!({"result":{"good":true,"received":40,"in_pool":false,"confirmations":8,"secret":"hidden"}}),
    ]);
    let result = check_proof(
        &ModulesConfig {
            wallet_rpc: Some(url),
            watch_only_confirmed: true,
            ..Default::default()
        },
        ProofRequest {
            txid: "a".repeat(64),
            address: "4".repeat(95),
            message: String::new(),
            signature: "OutProofV2abc".into(),
        },
    )
    .await
    .unwrap();
    assert_eq!(result["good"], true);
    assert!(result.get("secret").is_none());
    assert!(handle.join().unwrap()[0].contains("check_tx_proof"));
}

#[tokio::test]
async fn invalid_proofs_and_unattested_requests_never_connect() {
    let config = ModulesConfig {
        wallet_rpc: Some("http://127.0.0.1:1".into()),
        watch_only_confirmed: true,
        ..Default::default()
    };
    for txid in [String::new(), "g".repeat(64), "a".repeat(65)] {
        let result = check_proof(
            &config,
            ProofRequest {
                txid,
                address: "4".repeat(95),
                message: String::new(),
                signature: "OutProofV2abc".into(),
            },
        )
        .await;
        assert_eq!(result.unwrap_err(), "Invalid transaction proof input");
    }
}

#[tokio::test]
async fn oversized_and_wrong_shapes_are_unavailable() {
    for body in [
        json!({"padding":"x".repeat(600_000)}),
        json!({"result":{"balance":"secret","unlocked_balance":1}}),
    ] {
        let (url, handle) = server(vec![body]);
        let state = poll(&ModulesConfig {
            wallet_rpc: Some(url),
            watch_only_confirmed: true,
            ..Default::default()
        })
        .await;
        assert_eq!(state.wallet.state, "unavailable");
        // An early response-size rejection may close before the fixture finishes writing.
        let _ = handle.join();
    }
}

#[tokio::test]
async fn authentication_and_redirects_are_explicitly_unavailable() {
    for (status, header) in [
        (
            "401 Unauthorized",
            "WWW-Authenticate: Basic realm=secret\r\n",
        ),
        ("302 Found", "Location: http://127.0.0.1:1/private\r\n"),
    ] {
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let url = format!("http://{}", listener.local_addr().unwrap());
        let handle = std::thread::spawn(move || {
            let (mut stream, _) = listener.accept().unwrap();
            let mut b = [0; 4096];
            let count = stream.read(&mut b).unwrap();
            assert!(count > 0);
            write!(
                stream,
                "HTTP/1.1 {status}\r\n{header}Content-Length: 0\r\nConnection: close\r\n\r\n"
            )
            .unwrap();
        });
        let state = poll(&ModulesConfig {
            xmrig_url: Some(url),
            ..Default::default()
        })
        .await;
        assert_eq!(state.xmrig.state, "unavailable");
        if status.starts_with("401") {
            assert_eq!(
                state.xmrig.error.as_deref(),
                Some("Endpoint authentication is unsupported")
            );
        }
        assert!(!state.xmrig.error.unwrap().contains("secret"));
        handle.join().unwrap();
    }
}

#[tokio::test]
async fn stale_p2pool_and_nonregular_inputs_stay_truthful() {
    let d = tempfile::tempdir().unwrap();
    std::fs::create_dir(d.path().join("local")).unwrap();
    let path = d.path().join("local/stratum");
    std::fs::write(
        &path,
        json!({"hashrate_15m":0,"hashrate_1h":0,"hashrate_24h":0,"shares_found":0,"connections":0})
            .to_string(),
    )
    .unwrap();
    let file = std::fs::OpenOptions::new().write(true).open(&path).unwrap();
    file.set_times(
        std::fs::FileTimes::new()
            .set_modified(std::time::SystemTime::UNIX_EPOCH + std::time::Duration::from_secs(1)),
    )
    .unwrap();
    let config = ModulesConfig {
        p2pool_directory: Some(d.path().into()),
        ..Default::default()
    };
    let state = poll(&config).await;
    assert_eq!(state.p2pool.state, "stale");
    assert_eq!(state.p2pool.hashrate_15m, Some(0));
    std::fs::remove_file(&path).unwrap();
    std::os::unix::fs::symlink("/dev/zero", &path).unwrap();
    assert_eq!(poll(&config).await.p2pool.state, "unavailable");
}

#[test]
fn notifications_skip_history_and_deduplicate_confirmations() {
    use omamonero_core::modules::{Incoming, IncomingTracker, Wallet};
    let mut tracker = IncomingTracker::default();
    let mut wallet = Wallet {
        state: "ready".into(),
        ..Default::default()
    };
    wallet.incoming.push(Incoming {
        txid: "a".repeat(64),
        amount_atomic: 1,
        confirmations: Some(0),
        timestamp: None,
        in_pool: true,
    });
    assert!(!tracker.observe(&wallet));
    assert!(!tracker.observe(&wallet));
    wallet.incoming.push(Incoming {
        txid: "b".repeat(64),
        amount_atomic: 2,
        confirmations: Some(0),
        timestamp: None,
        in_pool: true,
    });
    assert!(tracker.observe(&wallet));
    wallet.incoming[1].confirmations = Some(10);
    assert!(!tracker.observe(&wallet));
    wallet.balance_atomic = Some(9007199254740993);
    let encoded = serde_json::to_value(&wallet).unwrap();
    assert_eq!(encoded["balance_atomic"], "9007199254740993");
    let decoded: Wallet = serde_json::from_value(encoded).unwrap();
    assert_eq!(decoded.balance_atomic, wallet.balance_atomic);
}

#[tokio::test]
async fn history_is_height_bounded_and_failure_preserves_balance_and_address() {
    for history in [
        json!({"result":{"in":[],"pool":[]}}),
        json!({"error":{"message":"secret-history-denied"}}),
        json!({"result":{"secret":"x".repeat(600_000)}}),
    ] {
        let (url, handle) = server(vec![
            json!({"result":{"balance":900,"unlocked_balance":800}}),
            json!({"result":{"address":"address"}}),
            json!({"result":{"height":10000}}),
            history.clone(),
        ]);
        let state = poll(&ModulesConfig {
            wallet_rpc: Some(url),
            watch_only_confirmed: true,
            ..Default::default()
        })
        .await;
        assert_eq!(state.wallet.state, "ready");
        assert_eq!(state.wallet.balance_atomic, Some(900));
        assert_eq!(state.wallet.address.as_deref(), Some("address"));
        assert_eq!(state.wallet.coverage_from_height, Some(9280));
        assert_eq!(
            state.wallet.incoming_error.is_some(),
            history.get("error").is_some() || history.pointer("/result/secret").is_some()
        );
        assert!(!serde_json::to_string(&state).unwrap().contains("secret"));
        let requests = handle.join().unwrap();
        let body = requests[3].split("\r\n\r\n").nth(1).unwrap();
        let request: serde_json::Value = serde_json::from_str(body).unwrap();
        assert_eq!(request["method"], "get_transfers");
        assert_eq!(request["params"]["filter_by_height"], true);
        assert_eq!(request["params"]["min_height"], 9280);
        assert_eq!(request["params"]["max_height"], 10000);
    }
}
#[tokio::test]
async fn unavailable_height_never_requests_unbounded_history() {
    let (url, handle) = server(vec![
        json!({"result":{"balance":900,"unlocked_balance":800}}),
        json!({"result":{"address":"address"}}),
        json!({"error":{"message":"secret-height-denied"}}),
    ]);
    let state = poll(&ModulesConfig {
        wallet_rpc: Some(url),
        watch_only_confirmed: true,
        ..Default::default()
    })
    .await;
    assert_eq!(state.wallet.state, "ready");
    assert!(state.wallet.incoming_error.is_some());
    assert!(state.wallet.coverage_from_height.is_none());
    assert_eq!(handle.join().unwrap().len(), 3);
}

#[test]
fn notification_tracker_does_not_prime_from_failed_history() {
    let mut tracker = IncomingTracker::default();
    let mut wallet = Wallet {
        state: "ready".into(),
        incoming_error: Some("unavailable".into()),
        ..Default::default()
    };
    assert!(!tracker.observe(&wallet));
    wallet.incoming_error = None;
    wallet.incoming.push(Incoming {
        txid: "a".repeat(64),
        amount_atomic: 1,
        confirmations: Some(1),
        timestamp: Some(1),
        in_pool: false,
    });
    assert!(!tracker.observe(&wallet));
}
