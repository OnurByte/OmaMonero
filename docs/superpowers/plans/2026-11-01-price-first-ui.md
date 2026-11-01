# Price-first Native UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Make the plugin useful by default with prices on and clear native hierarchy.
**Architecture:** Keep the backend-free TS/QML core. Market state owns bar presentation; optional telemetry stays on its own page. Native disclosure groups organize settings.
**Tech Stack:** strict TypeScript, QML/Quickshell, qs.Ui, esbuild, Vitest.
**Spec:** docs/superpowers/specs/2026-11-01-price-first-design.md

## Global Constraints

- Default prices on is the user's latest explicit correction; retain truthful USD/24h source/freshness.
- Keep selected proxy fail-closed behavior and local read-only optional modules.
- No new backend, standalone window, replacement artwork or loss of advanced features.

## Review Focus

- Node absent must not produce a global Offline widget.
- Price failure/loading must not fabricate numerical data.
- Existing explicit market-off configuration must remain usable.
- Three primary tabs and collapsed settings must fit native panel width.
- Advanced features, keyboard navigation and confirmed removal must remain reachable.

### Task 1: Price-led defaults and state
- [ ] Add failing tests for default-on and node-independent market labels.
- [ ] Change defaults, loading state and bar presentation; record the latest preference.
- [ ] Verify TS, display and generated-QML compatibility tests.

### Task 2: Native hierarchy
- [x] Add native three-destination navigation and runtime assertions.
- [x] Group optional tools; disclose advanced settings/maintenance.
- [x] Add tested real OHLC/volume data, bounded chart viewport/zoom, native candle/line rendering, legible axes and pointer/keyboard interaction.
- [x] Restrict About hit area to logo/title and enrich the About information.
- [ ] Capture the actual native panel, add the image to README and inspect final layout.
- [ ] Verify native QML load/layout, all action wiring and lint.

### Task 3: Delivery
- [ ] Version the QML snapshot, run full tests and real official-manager lifecycle.
- [ ] Publish after CI, update the installed widget and verify its actual bar/panel.
- [ ] Submit the exact final commit for marketplace review; never invent approval.
