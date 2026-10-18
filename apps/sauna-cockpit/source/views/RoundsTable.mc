import Toybox.Lang;
import Toybox.Graphics;

const TABLE_HEAT = 0;
const TABLE_REST = 1;
const TABLE_HRV = 2;

// Per-round tables over History round rows, shared by the live session pages, the post-session
// summary and the history detail:
//   heat: round, heat time, avg / max HR, peak watch temperature, HR rise (peak minus start)
//   rest: round, rest time, avg / min HR, HRR (HR drop in the first minute), watch-temperature drop
//   hrv:  round, HRV (RMSSD, ms) in the heat phase and in the following rest
module RoundsTable {
    // Widest expected cell per column, measured against its header to size the column.
    const SAMPLES = [
        ["9", "88:88", "888", "888", "88°", "+88"],
        ["9", "88:88", "888", "888", "-88", "-88°"],
        ["9", "888", "888"],
    ];
    // Share of the screen width each table spreads over.
    const SPREAD = [80, 80, 60];

    // Column right edges per table, cached: fonts and headers are fixed while the app runs.
    var _edges as Array = [null, null, null];

    function heads(kind as Number) as Array<String> {
        if (kind == TABLE_HEAT) {
            return ["#", "heat", "avg", "max", "°C", "rise"];
        }
        return kind == TABLE_REST ? ["#", "rest", "avg", "min", "HRR", "drop"] : ["", "HRV heat", "HRV rest"];
    }

    // Right-aligned columns sized to their widest content, spread over SPREAD % of the width
    // (rows sit near the middle, where a round screen is widest), then centred.
    function edges(dc as Graphics.Dc, f as Graphics.FontType, kind as Number) as Array<Number> {
        if (_edges[kind] != null) { return _edges[kind] as Array<Number>; }
        var w = dc.getWidth();
        var hs = heads(kind);
        var ss = SAMPLES[kind] as Array<String>;
        var n = hs.size();
        var widths = new [n] as Array<Number>;
        var sum = 0;
        for (var c = 0; c < n; c++) {
            var a = dc.getTextWidthInPixels(hs[c], f);
            var b = dc.getTextWidthInPixels(ss[c], f);
            widths[c] = a > b ? a : b;
            sum += widths[c];
        }
        var gap = (w * SPREAD[kind] / 100 - sum) / (n - 1);
        if (gap < 4) { gap = 4; }
        if (gap > w * 6 / 100) { gap = w * 6 / 100; }
        var x = (w - sum - gap * (n - 1)) / 2;
        var out = new [n] as Array<Number>;
        for (var c = 0; c < n; c++) {
            x += widths[c];
            out[c] = x;
            x += gap;
        }
        _edges[kind] = out;
        return out;
    }

    // Draws rows[first..] of one table from y down, at most `maxRows`; returns the y below it.
    function draw(dc as Graphics.Dc, kind as Number, rows as Array<Array<Number>>, first as Number, y as Number, maxRows as Number) as Number {
        var w = dc.getWidth();
        var f = Graphics.FONT_XTINY;
        var lh = dc.getFontHeight(f);
        var x = edges(dc, f, kind);
        var hs = heads(kind);
        var right = Graphics.TEXT_JUSTIFY_RIGHT;
        for (var c = 0; c < hs.size(); c++) {
            Theme.text(dc, x[c], y, f, hs[c], Theme.DIM, right);
        }
        y += lh;
        var last = first + maxRows < rows.size() ? first + maxRows : rows.size();
        for (var i = first; i < last; i++) {
            var r = rows[i];
            Theme.text(dc, x[0], y, f, (i + 1).format("%d"), Theme.HEAT, right);
            if (kind == TABLE_HEAT) {
                Theme.text(dc, x[1], y, f, Fmt.clock(r[History.R_HEAT]), Theme.FG, right);
                hr(dc, x[2], y, f, History.at(r, History.R_AVG));
                hr(dc, x[3], y, f, History.at(r, History.R_MAX));
                Theme.text(dc, x[4], y, f, Fmt.temp10(History.at(r, History.R_TEMP)), Theme.FG, right);
                var rise = History.at(r, History.R_RISE);
                Theme.text(dc, x[5], y, f, rise == History.NONE ? "--" : "+" + rise.format("%d"), Theme.HEAT, right);
            } else if (kind == TABLE_REST) {
                var cool = History.at(r, History.R_COOL);
                Theme.text(dc, x[1], y, f, cool <= 0 ? "--" : Fmt.clock(cool), Theme.FG, right);
                hr(dc, x[2], y, f, History.at(r, History.R_CAVG));
                hr(dc, x[3], y, f, History.at(r, History.R_CMIN));
                Theme.text(dc, x[4], y, f, Fmt.num(History.at(r, History.R_HRR)), Theme.COOL, right);
                Theme.text(dc, x[5], y, f, Fmt.temp10(History.at(r, History.R_CDROP)), Theme.COOL, right);
            } else {
                Theme.text(dc, x[1], y, f, Fmt.num(History.at(r, History.R_HRV)), Theme.HEAT, right);
                Theme.text(dc, x[2], y, f, Fmt.num(History.at(r, History.R_CHRV)), Theme.COOL, right);
            }
            y += lh;
        }
        if (rows.size() > maxRows) {
            Theme.text(dc, w / 2, y, f, (first + 1) + "-" + last + " of " + rows.size(), Theme.DIM, Graphics.TEXT_JUSTIFY_CENTER);
            y += lh;
        }
        return y;
    }

    // An HR cell in zone colour.
    function hr(dc as Graphics.Dc, x as Number, y as Number, f as Graphics.FontType, v as Number) as Void {
        Theme.text(dc, x, y, f, Fmt.num(v), Theme.zoneColor(v == History.NONE ? null : v), Graphics.TEXT_JUSTIFY_RIGHT);
    }
}
