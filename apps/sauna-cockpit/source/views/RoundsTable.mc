import Toybox.Lang;
import Toybox.Graphics;

// Per-round table (History round rows): round, heat time, avg / max HR, peak watch temperature
// and the HR drop in the first minute of the following cool-down. Shared by the live rounds
// page, the post-session summary and the history detail.
module RoundsTable {
    // Column right edges as % of width; the round number is left-aligned at COL_X[0].
    const COL_X = [15, 37, 52, 66, 77, 87];
    const HEADS = ["#", "heat", "avg", "max", "°C", "HRR"];

    // Draws rows[first..] from y down, at most `maxRows`; returns the y below the last row.
    function draw(dc as Graphics.Dc, rows as Array<Array<Number>>, first as Number, y as Number, maxRows as Number) as Number {
        var w = dc.getWidth();
        var f = Graphics.FONT_XTINY;
        var lh = dc.getFontHeight(f);
        for (var c = 0; c < HEADS.size(); c++) {
            Theme.text(dc, w * COL_X[c] / 100, y, f, HEADS[c], Theme.DIM,
                c == 0 ? Graphics.TEXT_JUSTIFY_LEFT : Graphics.TEXT_JUSTIFY_RIGHT);
        }
        y += lh;
        var last = first + maxRows < rows.size() ? first + maxRows : rows.size();
        for (var i = first; i < last; i++) {
            var r = rows[i];
            var cells = [
                (i + 1).format("%d"),
                Fmt.clock(r[History.R_HEAT]),
                Fmt.num(r[History.R_AVG]),
                Fmt.num(r[History.R_MAX]),
                Fmt.temp10(r[History.R_TEMP]),
                Fmt.num(r[History.R_HRR]),
            ];
            var colors = [Theme.HEAT, Theme.FG, Theme.zoneColor(nn(r[History.R_AVG])), Theme.zoneColor(nn(r[History.R_MAX])), Theme.FG, Theme.COOL];
            for (var c = 0; c < cells.size(); c++) {
                Theme.text(dc, w * COL_X[c] / 100, y, f, cells[c], colors[c],
                    c == 0 ? Graphics.TEXT_JUSTIFY_LEFT : Graphics.TEXT_JUSTIFY_RIGHT);
            }
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
