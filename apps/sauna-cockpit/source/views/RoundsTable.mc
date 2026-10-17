import Toybox.Lang;
import Toybox.Graphics;

// Per-round table (History round rows): round, heat time, avg / max HR, peak watch temperature
// and the HR drop in the first minute of the following cool-down. Shared by the live rounds
// page, the post-session summary and the history detail.
module RoundsTable {
    const HEADS = ["#", "heat", "avg", "max", "°C", "HRR"];
    // Widest expected cell per column, measured against its header to size the column.
    const SAMPLES = ["9", "88:88", "888", "888", "88°", "-88"];

    // Column right edges for a screen width and font, cached: fonts are fixed per device.
    var _edges as Array<Number> or Null = null;

    // Right-aligned columns sized to their widest content, spread over 80 % of the width
    // (rows sit near the middle, where a round screen is widest), then centred.
    function edges(dc as Graphics.Dc, f as Graphics.FontType) as Array<Number> {
        if (_edges != null) { return _edges as Array<Number>; }
        var w = dc.getWidth();
        var n = HEADS.size();
        var widths = new [n] as Array<Number>;
        var sum = 0;
        for (var c = 0; c < n; c++) {
            var a = dc.getTextWidthInPixels(HEADS[c], f);
            var b = dc.getTextWidthInPixels(SAMPLES[c], f);
            widths[c] = a > b ? a : b;
            sum += widths[c];
        }
        var gap = (w * 80 / 100 - sum) / (n - 1);
        if (gap < 4) { gap = 4; }
        if (gap > w * 6 / 100) { gap = w * 6 / 100; }
        var x = (w - sum - gap * (n - 1)) / 2;
        var out = new [n] as Array<Number>;
        for (var c = 0; c < n; c++) {
            x += widths[c];
            out[c] = x;
            x += gap;
        }
        _edges = out;
        return out;
    }

    // Draws rows[first..] from y down, at most `maxRows`; returns the y below the last row.
    function draw(dc as Graphics.Dc, rows as Array<Array<Number>>, first as Number, y as Number, maxRows as Number) as Number {
        var w = dc.getWidth();
        var f = Graphics.FONT_XTINY;
        var lh = dc.getFontHeight(f);
        var x = edges(dc, f);
        var right = Graphics.TEXT_JUSTIFY_RIGHT;
        for (var c = 0; c < HEADS.size(); c++) {
            Theme.text(dc, x[c], y, f, HEADS[c], Theme.DIM, right);
        }
        y += lh;
        var last = first + maxRows < rows.size() ? first + maxRows : rows.size();
        for (var i = first; i < last; i++) {
            var r = rows[i];
            Theme.text(dc, x[0], y, f, (i + 1).format("%d"), Theme.HEAT, right);
            Theme.text(dc, x[1], y, f, Fmt.clock(r[History.R_HEAT]), Theme.FG, right);
            Theme.text(dc, x[2], y, f, Fmt.num(r[History.R_AVG]), Theme.zoneColor(nn(r[History.R_AVG])), right);
            Theme.text(dc, x[3], y, f, Fmt.num(r[History.R_MAX]), Theme.zoneColor(nn(r[History.R_MAX])), right);
            Theme.text(dc, x[4], y, f, Fmt.temp10(r[History.R_TEMP]), Theme.FG, right);
            Theme.text(dc, x[5], y, f, Fmt.num(r[History.R_HRR]), Theme.COOL, right);
            y += lh;
        }
        if (rows.size() > maxRows) {
            Theme.text(dc, w / 2, y, f, (first + 1) + "-" + last + " of " + rows.size(), Theme.DIM, Graphics.TEXT_JUSTIFY_CENTER);
            y += lh;
        }
        return y;
    }

    function nn(v as Number) as Number or Null {
        return v == History.NONE ? null : v;
    }
}
