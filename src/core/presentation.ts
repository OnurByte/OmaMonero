import {integer, type Dict} from './privacy';
export function bytes(value: unknown) {
    if (!integer(value)) return "Unavailable"
    if (value >= 1073741824) return (value / 1073741824).toFixed(1) + " GiB"
    if (value >= 1048576) return (value / 1048576).toFixed(1) + " MiB"
    return value + " B"
}

export function marketView(m: Dict | null | undefined, now: number): Dict {
    if (!m || m.state === "disabled") return {state: "disabled"}
    if (m.state === "loading") return {state: "loading"}
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
    if (m.candles !== undefined) {
        if (!Array.isArray(m.candles) || m.candles.length < 2 || m.candles.length > 721) return {state:"invalid"}
        var last=0
        for (var c=0;c<m.candles.length;c++) {
            var candle=m.candles[c]
            if (!candle || !integer(candle.timestamp) || candle.timestamp<=last || candle.timestamp>m.fetched_at+5 || typeof candle.complete!=="boolean"
                || typeof candle.volume!=="number" || !isFinite(candle.volume) || candle.volume<0 || candle.volume>1e18) return {state:"invalid"}
            for (var k=0;k<4;k++) {var v=candle[["open","high","low","close"][k]];if(typeof v!=="number" || !isFinite(v) || v<=0 || v>1e9)return {state:"invalid"}}
            if(candle.high<Math.max(candle.open,candle.close) || candle.low>Math.min(candle.open,candle.close))return {state:"invalid"}
            last=candle.timestamp
        }
    }
    return m
}
export function changeLabel(value: unknown) {
    if (typeof value !== "number" || !isFinite(value)) return "—"
    return (value > 0 ? "+" : value < 0 ? "−" : "") + Math.abs(value).toFixed(2) + "%"
}

export function trendColor(change: unknown) {
    if (typeof change !== "number" || !isFinite(change)) return "#9ca3af"
    return change < 0 ? "#ef4444" : "#22c55e"
}

export function atomicLabel(value: unknown) {
    if (typeof value === "number" && (!integer(value) || value > 9007199254740991)) return "Unavailable"
    if (value === null || value === undefined) return "—"
    var digits = String(value)
    if (!/^[0-9]{1,20}$/.test(digits)) return "Unavailable"
    while (digits.length < 13) digits = "0" + digits
    var whole = digits.slice(0, -12).replace(/^0+(?=[0-9])/, "")
    var fraction = digits.slice(-12).replace(/0+$/, "")
    return whole + (fraction ? "." + fraction : "") + " XMR"
}

export function marketLabel(m: Dict | null | undefined) {
    if (m && m.state === "ready") return "$" + m.price.toFixed(2) + " " + changeLabel(m.change_percent)
    if (m && m.state === "loading") return "Loading…"
    if (m && m.state === "disabled") return "Paused"
    if (m && m.state === "stale") return "Stale"
    return "—"
}
