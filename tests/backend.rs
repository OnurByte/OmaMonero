use serde_json::{Value, json};
use std::{
    fs,
    io::{BufRead, BufReader, Read, Write},
    net::TcpListener,
    os::unix::fs::{PermissionsExt, symlink},
    process::{Command, Output},
    thread,
    time::Duration,
};
use tempfile::TempDir;

fn private_tempdir() -> TempDir {
    tempfile::Builder::new()
        .permissions(fs::Permissions::from_mode(0o700))
        .tempdir()
        .unwrap()
}
fn info() -> Value {
    json!({"status":"OK","height":3200000,"target_height":3200000,"synchronized":true,"busy_syncing":false,"nettype":"mainnet","incoming_connections_count":3,"outgoing_connections_count":8,"database_size":123456789,"free_space":456789,"version":"0.18.4.0","untrusted":false})
}
fn server(body: String, delay: u64, status: &str) -> String {
    let socket = TcpListener::bind("127.0.0.1:0").unwrap();
    let endpoint = format!("http://{}", socket.local_addr().unwrap());
    let status = status.to_owned();
    thread::spawn(move || {
        let (mut stream, _) = socket.accept().unwrap();
        stream
            .set_read_timeout(Some(Duration::from_secs(5)))
            .unwrap();
        let mut reader = BufReader::new(stream.try_clone().unwrap());
        let mut len = 0;
        loop {
            let mut line = String::new();
            reader.read_line(&mut line).unwrap();
            if line == "\r\n" {
                break;
            }
            if let Some(v) = line.to_lowercase().strip_prefix("content-length:") {
                len = v.trim().parse::<usize>().unwrap();
            }
        }
        let mut request = vec![0; len];
        reader.read_exact(&mut request).unwrap();
        let request: Value = serde_json::from_slice(&request).unwrap();
        assert_eq!(request["method"], "get_info");
        thread::sleep(Duration::from_millis(delay));
        let _ = write!(
            stream,
            "HTTP/1.1 {status}\r\nContent-Length: {}\r\nContent-Type: application/json\r\nConnection: close\r\n\r\n{body}",
            body.len()
        );
    });
    endpoint
}
fn config(dir: &TempDir, endpoint: &str, extra: &str) {
    fs::write(
        dir.path().join("config.toml"),
        format!("endpoint = {endpoint:?}\ntimeout_ms = 100\npoll_interval_secs = 1\n{extra}\n"),
    )
    .unwrap();
}
fn run(dir: &TempDir, command: &str) -> Output {
    Command::new(env!("CARGO_BIN_EXE_omamonero-core"))
        .args([
            "--config",
            dir.path().join("config.toml").to_str().unwrap(),
            "--runtime-dir",
            dir.path().to_str().unwrap(),
            command,
        ])
        .output()
        .unwrap()
}
fn snapshot(dir: &TempDir) -> Value {
    serde_json::from_slice(&fs::read(dir.path().join("omamonero/status.json")).unwrap()).unwrap()
}
fn healthy_server() -> String {
    server(
        json!({"jsonrpc":"2.0","id":"0","result":info()}).to_string(),
        0,
        "200 OK",
    )
}

#[test]
fn healthy_snapshot_is_private_and_typed() {
    let dir = private_tempdir();
    config(&dir, &healthy_server(), "");
    let output = run(&dir, "once");
    assert!(
        output.status.success(),
        "{}",
        String::from_utf8_lossy(&output.stderr)
    );
    let s = snapshot(&dir);
    assert_eq!(s["api_version"], 1);
    assert_eq!(s["node"]["state"], "online");
    assert_eq!(s["node"]["height"], 3200000);
    assert_eq!(s["node"]["sync_percent"], 100.0);
    assert_eq!(s["privacy"]["p2p_verified"], false);
    assert_eq!(
        fs::metadata(dir.path().join("omamonero"))
            .unwrap()
            .permissions()
            .mode()
            & 0o777,
        0o700
    );
    assert_eq!(
        fs::metadata(dir.path().join("omamonero/status.json"))
            .unwrap()
            .permissions()
            .mode()
            & 0o777,
        0o600
    );
}
#[test]
fn offline_replaces_old_success_without_metrics() {
    let dir = private_tempdir();
    config(&dir, &healthy_server(), "");
    assert!(run(&dir, "once").status.success());
    let closed = TcpListener::bind("127.0.0.1:0").unwrap();
    let url = format!("http://{}", closed.local_addr().unwrap());
    drop(closed);
    config(&dir, &url, "");
    assert_eq!(run(&dir, "once").status.code(), Some(2));
    let s = snapshot(&dir);
    assert_eq!(s["node"]["state"], "offline");
    assert!(s["node"].get("height").is_none());
    assert!(s["node"].get("sync_percent").is_none());
}
#[test]
fn malformed_busy_and_slow_responses_are_not_success() {
    for (body, delay, error) in [
        ("not json".to_owned(), 0, "invalid_response"),
        (
            json!({"result":{"status":"BUSY"},"jsonrpc":"2.0","id":"0"}).to_string(),
            0,
            "rpc_error",
        ),
        (
            json!({"result":info(),"jsonrpc":"2.0","id":"0"}).to_string(),
            500,
            "timeout",
        ),
    ] {
        let dir = private_tempdir();
        config(&dir, &server(body, delay, "200 OK"), "");
        assert_eq!(run(&dir, "once").status.code(), Some(2));
        assert_eq!(snapshot(&dir)["node"]["error"], error);
    }
}
#[test]
fn sync_and_network_mismatch_are_explicit() {
    let mut i = info();
    i["synchronized"] = json!(false);
    i["height"] = json!(1600000);
    let dir = private_tempdir();
    config(
        &dir,
        &server(
            json!({"result":i,"jsonrpc":"2.0","id":"0"}).to_string(),
            0,
            "200 OK",
        ),
        "",
    );
    assert!(run(&dir, "once").status.success());
    assert_eq!(snapshot(&dir)["node"]["state"], "syncing");
    assert_eq!(snapshot(&dir)["node"]["sync_percent"], 50.0);
    let mut i = info();
    i["nettype"] = json!("stagenet");
    config(
        &dir,
        &server(
            json!({"result":i,"jsonrpc":"2.0","id":"0"}).to_string(),
            0,
            "200 OK",
        ),
        "",
    );
    assert_eq!(run(&dir, "once").status.code(), Some(2));
    assert_eq!(snapshot(&dir)["node"]["error"], "network_mismatch");
}
#[test]
fn remote_credentials_and_unknown_config_are_rejected_without_leaking() {
    for text in [
        "endpoint='http://example.com:18081'",
        "endpoint='http://user:TOPSECRET@127.0.0.1:18081'",
        "endpoint='http://127.0.0.1:18081'\nprivte_key='TOPSECRET'",
        "transport='tor'",
        "poll_interval_secs=0",
    ] {
        let dir = private_tempdir();
        fs::write(dir.path().join("config.toml"), text).unwrap();
        let o = run(&dir, "once");
        assert!(!o.status.success());
        assert!(!String::from_utf8_lossy(&o.stderr).contains("TOPSECRET"));
        assert!(!dir.path().join("omamonero/status.json").exists());
    }
}
#[test]
fn failed_proxy_never_contacts_endpoint_directly() {
    let node = TcpListener::bind("127.0.0.1:0").unwrap();
    node.set_nonblocking(true).unwrap();
    let proxy = TcpListener::bind("127.0.0.1:0").unwrap();
    let proxy_url = format!("socks5h://{}", proxy.local_addr().unwrap());
    drop(proxy);
    let dir = private_tempdir();
    config(
        &dir,
        &format!("http://{}", node.local_addr().unwrap()),
        &format!("transport='tor'\nproxy={proxy_url:?}"),
    );
    assert_eq!(run(&dir, "once").status.code(), Some(2));
    assert!(node.accept().is_err());
    assert_eq!(snapshot(&dir)["privacy"]["transport"], "tor");
}
#[test]
fn rejects_symlinks_and_broad_runtime_permissions() {
    let dir = private_tempdir();
    config(&dir, &healthy_server(), "");
    let other = private_tempdir();
    symlink(other.path(), dir.path().join("omamonero")).unwrap();
    assert!(!run(&dir, "once").status.success());
    assert!(!other.path().join("status.json").exists());
    fs::remove_file(dir.path().join("omamonero")).unwrap();
    fs::create_dir(dir.path().join("omamonero")).unwrap();
    fs::set_permissions(
        dir.path().join("omamonero"),
        fs::Permissions::from_mode(0o755),
    )
    .unwrap();
    assert!(!run(&dir, "once").status.success());
}
#[test]
fn doctor_distinguishes_missing_snapshot_and_live_rpc() {
    let dir = private_tempdir();
    config(&dir, &healthy_server(), "");
    let o = run(&dir, "doctor");
    assert_eq!(o.status.code(), Some(2));
    let report: Value = serde_json::from_slice(&o.stdout).unwrap();
    assert_eq!(report["rpc"]["node"]["state"], "online");
    assert_eq!(report["snapshot"]["state"], "missing");
    assert!(!dir.path().join("omamonero").exists());
}
#[test]
fn rejects_http_errors_redirects_and_oversized_data() {
    for (status, body) in [
        (
            "503 Service Unavailable",
            "private upstream details".to_owned(),
        ),
        ("302 Found", "".to_owned()),
        ("200 OK", "x".repeat(1048577)),
    ] {
        let dir = private_tempdir();
        config(&dir, &server(body, 0, status), "");
        assert_eq!(run(&dir, "once").status.code(), Some(2));
        assert_eq!(snapshot(&dir)["node"]["state"], "offline");
        assert!(
            !fs::read_to_string(dir.path().join("omamonero/status.json"))
                .unwrap()
                .contains("private upstream")
        );
    }
}
#[test]
fn duplicate_daemon_is_refused_and_sigterm_is_clean() {
    let dir = private_tempdir();
    config(&dir, "http://127.0.0.1:1", "");
    let mut child = Command::new(env!("CARGO_BIN_EXE_omamonero-core"))
        .args([
            "--config",
            dir.path().join("config.toml").to_str().unwrap(),
            "--runtime-dir",
            dir.path().to_str().unwrap(),
            "daemon",
        ])
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .spawn()
        .unwrap();
    for _ in 0..100 {
        if dir.path().join("omamonero/status.json").exists() {
            break;
        }
        thread::sleep(Duration::from_millis(20));
    }
    let o = run(&dir, "once");
    assert!(!o.status.success());
    assert!(String::from_utf8_lossy(&o.stderr).contains("already running"));
    Command::new("kill")
        .args(["-TERM", &child.id().to_string()])
        .status()
        .unwrap();
    assert!(child.wait().unwrap().success());
    assert_eq!(snapshot(&dir)["node"]["state"], "stopped");
}

#[test]
fn explicit_missing_config_is_not_silently_defaulted() {
    let dir = private_tempdir();
    let output = run(&dir, "once");
    assert_eq!(output.status.code(), Some(1));
    assert!(String::from_utf8_lossy(&output.stderr).contains("configuration could not be read"));
}

#[test]
fn unknown_target_and_bootstrap_status_do_not_invent_certainty() {
    let dir = private_tempdir();
    let mut i = info();
    i["target_height"] = json!(0);
    i["synchronized"] = json!(false);
    i["untrusted"] = json!(true);
    config(
        &dir,
        &server(
            json!({"jsonrpc":"2.0","id":"0","result":i}).to_string(),
            0,
            "200 OK",
        ),
        "",
    );
    assert!(run(&dir, "once").status.success());
    let s = snapshot(&dir);
    assert_eq!(s["node"]["state"], "syncing");
    assert!(s["node"]["sync_percent"].is_null());
    assert_eq!(s["node"]["untrusted"], true);
}

#[test]
fn status_is_read_only_and_stale_data_returns_unhealthy() {
    let dir = private_tempdir();
    config(&dir, &healthy_server(), "");
    assert!(run(&dir, "once").status.success());
    let path = dir.path().join("omamonero/status.json");
    let mut s = snapshot(&dir);
    s["generated_at"] = json!(1);
    fs::write(&path, serde_json::to_vec(&s).unwrap()).unwrap();
    assert_eq!(run(&dir, "status").status.code(), Some(2));
    assert_eq!(snapshot(&dir)["generated_at"], 1);
    fs::write(&path, b"{broken").unwrap();
    assert_eq!(run(&dir, "status").status.code(), Some(1));
}

#[test]
fn rpc_response_identity_and_types_are_checked() {
    for body in [
        json!({"jsonrpc":"2.0","id":"different","result":info()}),
        json!({"jsonrpc":"2.0","id":"0","error":{"code":-1,"message":"TOPSECRET"}}),
        json!({"jsonrpc":"2.0","id":"0","result":{"status":"OK","height":"bad"}}),
    ] {
        let dir = private_tempdir();
        config(&dir, &server(body.to_string(), 0, "200 OK"), "");
        assert_eq!(run(&dir, "once").status.code(), Some(2));
        assert!(
            !fs::read_to_string(dir.path().join("omamonero/status.json"))
                .unwrap()
                .contains("TOPSECRET")
        );
    }
}
