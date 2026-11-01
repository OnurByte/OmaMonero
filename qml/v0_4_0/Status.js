.pragma library

function integer(value) {
    return typeof value === "number" && isFinite(value) && value >= 0 && value <= 9007199254740991 && Math.floor(value) === value
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
    return change < 0 ? "#ef4444" : "#22c55e"
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
