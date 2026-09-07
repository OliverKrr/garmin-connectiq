import Toybox.Lang;
import Toybox.Math;

// Computes the run-cockpit layout rectangles once per onLayout(). A rect is
// [x, y, w, h]. On a round screen each horizontal band is only as wide as fits
// inside the inscribed circle at that band's height, and is horizontally centred.
// On a rectangular screen (Venu Sq 2, Venu X1) the bands take the full width minus
// the inset. The circle rule would starve the top and bottom rows there: on a
// 320x360 screen it leaves the clock band 22 px wide.
class GridLayout {
    private var _clock as Array<Number>;
    private var _pace as Array;
    private var _hr as Array;
    private var _bottom as Array;
    private var _zone as Array<Number>;

    function initialize(w as Number, h as Number, rectangular as Boolean) {
        var cx = w / 2;
        var cy = h / 2;
        var radius = ((w < h) ? w : h) / 2;
        var inset = 6;

        var clockH = (h * 8) / 100;
        var rowH = (h * 15) / 100;
        var zoneH = (h * 17) / 100;
        var gap = (h * 4) / 100;              // breathing room so big values don't touch the next label

        var yClock = (h * 6) / 100;           // clock near the top
        var yPace = (h * 16) / 100;           // value rows start higher, using the space under the clock
        var yHr = yPace + rowH + gap;
        var yBottom = yHr + rowH + gap;
        var yZone = yBottom + rowH + gap;

        _clock = _band(cx, cy, radius, inset, yClock, clockH, rectangular);
        _zone = _band(cx, cy, radius, inset, yZone, zoneH, rectangular);
        _pace = _columns(_band(cx, cy, radius, inset, yPace, rowH, rectangular), 3);
        _hr = _columns(_band(cx, cy, radius, inset, yHr, rowH, rectangular), 3);
        _bottom = _columns(_band(cx, cy, radius, inset, yBottom, rowH, rectangular), 3);
    }

    // Largest centred [x,y,w,h] band over [y, y+h]: the full inset width on a
    // rectangular screen, else the widest strip whose corners stay inside the circle.
    private function _band(cx as Number, cy as Number, radius as Number, inset as Number, y as Number, h as Number, rectangular as Boolean) as Array<Number> {
        var half = cx - inset;
        if (!rectangular) {
            var dyTop = (y - cy).abs();
            var dyBot = (y + h - cy).abs();
            var dy = (dyTop > dyBot) ? dyTop : dyBot;
            var r2 = radius * radius - dy * dy;
            half = (r2 > 0) ? Math.sqrt(r2).toNumber() - inset : 0;
        }
        if (half < 1) {
            half = 1;
        }
        return [cx - half, y, 2 * half, h];
    }

    // Split a band into n equal-width column rects with a gutter between them so adjacent
    // values don't touch. The gutter is ~3% of the band width (min 6 px).
    private function _columns(band as Array<Number>, n as Number) as Array {
        var g = (band[2] * 5) / 100;
        if (g < 8) {
            g = 8;
        }
        var colW = (band[2] - (n - 1) * g) / n;
        var cells = new [n];
        for (var i = 0; i < n; i++) {
            var x = band[0] + i * (colW + g);
            cells[i] = [x, band[1], colW, band[3]];
        }
        return cells;
    }

    function clock() as Array<Number> { return _clock; }
    function paceCells() as Array { return _pace; }
    function hrCells() as Array { return _hr; }
    function bottomCells() as Array { return _bottom; }
    function zoneBar() as Array<Number> { return _zone; }
}
