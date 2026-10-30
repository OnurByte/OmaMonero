# OmaMonero Native Companion Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task-by-task. The user requested completion in this session.

**Goal:** Deliver the supplied v0.1 native node companion.
**Architecture:** A single Rust user service polls read-only monerod get_info and publishes an atomic, private, versioned snapshot. Quickshell displays it using native Omarchy components, without starting a backend or doing network work.
**Tech Stack:** Rust, Tokio, Serde, reqwest, TOML, Quickshell/QML, systemd.
**Spec:** ../specs/2026-10-30-omamonero-design.md

## Global Constraints
- ID io.github.onurbyte.omamonero, schemaVersion 1, version 0.1.0; bar-widget only.
- No ShellRoot, service auto-start, root hooks, shell configuration edits, or symlinks.
- Runtime directory 0700 and files 0600; no secrets in snapshots/logs.
- No wallet keys or spending RPC, no stale success after RPC failure.
- v0.2 payment/privacy verification and v0.3 mining remain explicitly future work.

## Review Focus
- Offline, malformed, busy, oversized, redirecting, and slow RPC endpoints must fail visibly.
- Proxy failure must never cause a direct retry; monerod P2P route remains unverified.
- Runtime symlinks, unsafe modes and duplicate daemons must fail safely.
- Missing/corrupt/incompatible/future/stale snapshots must never show a healthy node.
- Atomic replacement must keep producing FileView updates, including late file creation.

### Task 1: Typed backend and private publication
**Files:** Cargo.toml, src/{main,lib,config,app}.rs, src/rpc/daemon.rs, src/state/{snapshot,writer}.rs, src/cli/doctor.rs, tests/backend.rs.
**Interfaces:** Config::load(path), RpcClient::poll(), Snapshot, StateWriter::new(runtime)/write(snapshot), CLI daemon/once/doctor/status.
- [x] Write executable integration tests for healthy sync, offline/invalid/slow RPC, policy validation, private files, single-instance lock and safe redaction. Run before implementation and confirm missing binary/feature failures.
- [x] Implement strict config, bounded RPC, typed state and atomic writer with lock; doctor reports current RPC and cached snapshot independently.
- [x] Run cargo test, fmt and clippy; build release binary.

### Task 2: Native frontend
**Files:** manifest.json, qml/{BarWidget,Panel,StatusStore}.qml, qml/Status.js, qml/components/*.qml, tests/status.test.cjs.
**Interfaces:** API version 1 JSON snapshot; JS classify(raw, now), singleton StatusStore; Omarchy bar and panel interfaces from installed source.
- [x] Test missing, malformed, wrong API, future, stale, offline, healthy and incompatible fields before writing classifier.
- [x] Implement shared FileView, event reload plus bounded recovery timer, theme-aware widget and keyboard panel with Escape, close and refresh.
- [x] Run official plugin validator and qmllint; validate actual FileView atomic replacement in an isolated test harness without creating another production shell.

### Task 3: Distribution and verification
**Files:** packaging/omamonero.service, packaging/PKGBUILD, config.example.toml, scripts/*, .github/workflows/*, README.md, docs/{architecture,verification}.md, LICENSE.
- [x] Package binary separately from QML, without installation hooks or activation; make source and package installation instructions concrete.
- [x] Add locked Rust checks, audit/dependency review, version synchronization, frontend tests, official plugin validation, reproducibility check.
- [x] Run final checks, review failure paths, record evidence and real-session limitations, and resolve important findings.
