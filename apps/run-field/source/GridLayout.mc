import Toybox.Lang;
import Toybox.Math;

// Computes the run-field layout rectangles once per onLayout(). A rect is
// [x, y, w, h]. Rows are sized round-aware: each horizontal band is only as wide
// as fits inside the screen's inscribed circle at that band's height, and is
// horizontally centred. Tuned for round screens (Enduro 3); on a rectangular
// screen it degrades to a centred, slightly inset stack of bands.
class GridLayout {
    private var _clock as Array<Number>;
    private var _pace as Array;
    private var _hr as Array;
    private var _bottom as Array;
    private var _zone as Array<Number>;

    function initialize(w as Number, h as Number) {
        var cx = w / 2;
        var cy = h / 2;
        var radius = ((w < h) ? w : h) / 2;
        var inset = 6;

        var clockH = (h * 10) / 100;
        var rowH = (h * 15) / 100;
        var zoneH = (h * 12) / 100;
        var gap = (h * 1) / 100;

        var yClock = (h * 11) / 100;          // clock near the top
        var yPace = (h * 26) / 100;           // value rows start below the clock
        var yHr = yPace + rowH + gap;
        var yBottom = yHr + rowH + gap;
        var yZone = yBottom + rowH + gap;

        _clock = _band(cx, cy, radius, inset, yClock, clockH);
        _zone = _band(cx, cy, radius, inset, yZone, zoneH);
        _pace = _columns(_band(cx, cy, radius, inset, yPace, rowH), 3);
        _hr = _columns(_band(cx, cy, radius, inset, yHr, rowH), 3);
        _bottom = _columns(_band(cx, cy, radius, inset, yBottom, rowH), 2);
    }

    // Largest centred [x,y,w,h] band over [y, y+h] that fits inside the circle.
    private function _band(cx as Number, cy as Number, radius as Number, inset as Number, y as Number, h as Number) as Array<Number> {
        var dyTop = (y - cy).abs();
        var dyBot = (y + h - cy).abs();
        var dy = (dyTop > dyBot) ? dyTop : dyBot;
        var r2 = radius * radius - dy * dy;
        var half = (r2 > 0) ? Math.sqrt(r2).toNumber() - inset : 0;
        if (half < 1) {
            half = 1;
        }
        return [cx - half, y, 2 * half, h];
    }

    // Split a band into n equal-width column rects (last cell absorbs rounding).
    private function _columns(band as Array<Number>, n as Number) as Array {
        var colW = band[2] / n;
        var cells = new [n];
        for (var i = 0; i < n; i++) {
            var x = band[0] + i * colW;
            var wi = (i < n - 1) ? colW : (band[0] + band[2]) - x;
            cells[i] = [x, band[1], wi, band[3]];
        }
        return cells;
    }

    function clock() as Array<Number> { return _clock; }
    function paceCells() as Array { return _pace; }
    function hrCells() as Array { return _hr; }
    function bottomCells() as Array { return _bottom; }
    function zoneBar() as Array<Number> { return _zone; }
}
