.pragma library

function integer(value) {
    return typeof value === "number" && isFinite(value) && value >= 0 && value <= 9007199254740991 && Math.floor(value) === value
}
function empty(state, message) {
    return { state: state, message: message, node: null, privacy: null, generatedAt: 0, market: { state: "unavailable" } }
}
function classify(raw, now) {
    if (!raw) return empty("missing", "Backend not installed / inactive")
    if (raw.length > 1048576) return empty("invalid", "Invalid backend data")
    var s
    try { s = JSON.parse(raw) } catch (e) { return empty("invalid", "Invalid backend data") }
    if (!s || typeof s !== "object") return empty("invalid", "Invalid backend data")
    if (s.api_version !== 1) return empty("incompatible", "Backend API mismatch")
    if (!integer(s.generated_at) || !integer(s.stale_after_secs) || s.stale_after_secs < 1 || s.stale_after_secs > 1000 || s.generated_at > now + 5)
        return empty("invalid", "Invalid backend timestamp")
    if (now - s.generated_at > s.stale_after_secs) return empty("stale", "Backend data is stale")
    var n = s.node
    var p = s.privacy
    if (!n || !p || ["local", "direct", "tor", "i2p"].indexOf(p.transport) < 0 || p.p2p_verified !== false)
        return empty("invalid", "Invalid backend data")
    if (["online", "syncing", "offline", "stopped"].indexOf(n.state) < 0)
        return empty("invalid", "Invalid node state")
    if (n.state === "online" || n.state === "syncing") {
        if (!integer(n.height) || !integer(n.target_height) || !integer(n.incoming_peers) || !integer(n.outgoing_peers) || !integer(n.latency_ms)
            || ["mainnet", "testnet", "stagenet"].indexOf(n.network) < 0 || typeof n.untrusted !== "boolean"
            || (n.sync_percent !== null && (typeof n.sync_percent !== "number" || !isFinite(n.sync_percent) || n.sync_percent < 0 || n.sync_percent > 100))
            || (n.version !== null && (typeof n.version !== "string" || n.version.length > 64 || !/^[a-zA-Z0-9._+\-]*$/.test(n.version)))
            || (n.database_bytes !== undefined && n.database_bytes !== null && !integer(n.database_bytes))
            || (n.free_bytes !== undefined && n.free_bytes !== null && !integer(n.free_bytes)))
            return empty("invalid", "Invalid node metrics")
    } else if (n.state === "offline") {
        if (["connection", "timeout", "http_error", "invalid_response", "rpc_error", "network_mismatch", "response_too_large"].indexOf(n.error) < 0)
            return empty("invalid", "Invalid node error")
        n = {state: "offline", error: n.error}
    } else n = {state: "stopped"}
    var message = n.state === "online" ? "Node online" : n.state === "syncing" ? "Node syncing" : n.state === "offline" ? "Node offline" : "Backend stopped"
    return {state:n.state, message:message, node:n, privacy:p, generatedAt:s.generated_at, market:marketView(s.market, now), modules:s.modules || null}
}
function bytes(value) {
    if (!integer(value)) return "Unavailable"
    if (value >= 1073741824) return (value / 1073741824).toFixed(1) + " GiB"
    if (value >= 1048576) return (value / 1048576).toFixed(1) + " MiB"
    return value + " B"
}

function marketView(m, now) {
    if (!m || m.state === "disabled") return {state: "disabled"}
    if (m.state === "unavailable") return {state: "unavailable"}
    if (m.state !== "ready" || typeof m.source !== "string" || !m.source.trim() || m.source.length > 48 || m.currency !== "USD"
        || !integer(m.fetched_at) || m.fetched_at > now + 5 || m.stale_after_secs !== 360
        || typeof m.price !== "number" || !isFinite(m.price) || m.price <= 0 || m.price > 1000000000
        || typeof m.change_percent !== "number" || !isFinite(m.change_percent)
        || [300, 900, 1800, 3600].indexOf(m.sample_interval_secs) < 0
        || !Array.isArray(m.points) || m.points.length < 2 || m.points.length > 400)
        return {state: "invalid"}
    if (now - m.fetched_at > m.stale_after_secs) return {state: "stale"}
    var previous = -1
    for (var i = 0; i < m.points.length; i++) {
        var point = m.points[i]
        if (!point || !integer(point.timestamp) || point.timestamp <= previous || point.timestamp > m.fetched_at + 5
            || typeof point.price !== "number" || !isFinite(point.price) || point.price <= 0 || point.price > 1000000000)
            return {state: "invalid"}
        previous = point.timestamp
    }
    return m
}
function changeLabel(value) {
    if (typeof value !== "number" || !isFinite(value)) return "—"
    return (value > 0 ? "+" : value < 0 ? "−" : "") + Math.abs(value).toFixed(2) + "%"
}

function trendColor(change) {
    if (typeof change !== "number" || !isFinite(change)) return "#9ca3af"
    return change < 0 ? "#ef4444" : change > 0 ? "#22c55e" : "#9ca3af"
}

function atomicLabel(value) {
    if (typeof value === "number" && (!integer(value) || value > 9007199254740991)) return "Unavailable"
    if (value === null || value === undefined) return "—"
    var digits = String(value)
    if (!/^[0-9]{1,20}$/.test(digits)) return "Unavailable"
    while (digits.length < 13) digits = "0" + digits
    var whole = digits.slice(0, -12).replace(/^0+(?=[0-9])/, "")
    var fraction = digits.slice(-12).replace(/0+$/, "")
    return whole + (fraction ? "." + fraction : "") + " XMR"
}
