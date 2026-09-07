import Toybox.Test;
import Toybox.Lang;

(:test)
function gridLayout_bandsOrderedAndStacked(logger as Test.Logger) as Boolean {
    var g = new GridLayout(280, 280, false);
    var c = g.clock();
    var p = g.paceCells()[0];
    var h = g.hrCells()[0];
    var b = g.bottomCells()[0];
    var z = g.zoneBar();
    return c[1] + c[3] <= p[1]
        && p[1] + p[3] <= h[1]
        && h[1] + h[3] <= b[1]
        && b[1] + b[3] <= z[1];
}

(:test)
function gridLayout_cellCounts(logger as Test.Logger) as Boolean {
    var g = new GridLayout(280, 280, false);
    return g.paceCells().size() == 3 && g.hrCells().size() == 3 && g.bottomCells().size() == 3;
}

(:test)
function gridLayout_bandsCentered(logger as Test.Logger) as Boolean {
    var g = new GridLayout(280, 280, false);
    return _centered(g.clock(), 280)
        && _centered(g.zoneBar(), 280)
        && _rowCentered(g.paceCells(), 280)
        && _rowCentered(g.hrCells(), 280)
        && _rowCentered(g.bottomCells(), 280);
}

(:test)
function gridLayout_cornersInCircle280(logger as Test.Logger) as Boolean {
    return _allInCircle(new GridLayout(280, 280, false), 280);
}

(:test)
function gridLayout_cornersInCircle240(logger as Test.Logger) as Boolean {
    return _allInCircle(new GridLayout(240, 240, false), 240);
}

// Rectangular screens (Venu Sq 2 320x360, Venu X1 448x486) drop the circle rule: bands
// take the full inset width, so the clock and zone strip stay usable.
(:test)
function gridLayout_rectangleBandsSpanFullWidth(logger as Test.Logger) as Boolean {
    var g = new GridLayout(320, 360, true);
    return _spansWidth(g.clock(), 320)
        && _spansWidth(g.zoneBar(), 320)
        && _rowSpansWidth(g.paceCells(), 320)
        && _rowSpansWidth(g.bottomCells(), 320);
}

(:test)
function gridLayout_rectangleBandsStackedInsideScreen(logger as Test.Logger) as Boolean {
    var g = new GridLayout(448, 486, true);
    var c = g.clock();
    var p = g.paceCells()[0];
    var h = g.hrCells()[0];
    var b = g.bottomCells()[0];
    var z = g.zoneBar();
    return c[1] + c[3] <= p[1]
        && p[1] + p[3] <= h[1]
        && h[1] + h[3] <= b[1]
        && b[1] + b[3] <= z[1]
        && z[1] + z[3] <= 486
        && c[0] >= 0
        && z[0] + z[2] <= 448;
}

// A band is "full width" when it loses at most the 6 px inset on each side.
function _spansWidth(rect as Array, w as Number) as Boolean {
    return rect[2] >= w - 12 && _centered(rect, w);
}

// A row also loses up to 1 px per column to the integer split of the band width.
function _rowSpansWidth(cells as Array, w as Number) as Boolean {
    var first = cells[0];
    var last = cells[cells.size() - 1];
    return last[0] + last[2] - first[0] >= w - 12 - cells.size() && _rowCentered(cells, w);
}

function _centered(rect as Array, w as Number) as Boolean {
    return (rect[0] + rect[2] / 2 - w / 2).abs() <= 1;
}

function _rowCentered(cells as Array, w as Number) as Boolean {
    var first = cells[0];
    var last = cells[cells.size() - 1];
    return ((first[0] + last[0] + last[2]) / 2 - w / 2).abs() <= 1;
}

function _allInCircle(g as GridLayout, w as Number) as Boolean {
    var rects = [g.clock(), g.zoneBar()];
    var rows = [g.paceCells(), g.hrCells(), g.bottomCells()];
    for (var i = 0; i < rects.size(); i++) {
        if (!_cornersInCircle(rects[i], w)) { return false; }
    }
    for (var r = 0; r < rows.size(); r++) {
        var cells = rows[r];
        for (var c = 0; c < cells.size(); c++) {
            if (!_cornersInCircle(cells[c], w)) { return false; }
        }
    }
    return true;
}

function _cornersInCircle(rect as Array, w as Number) as Boolean {
    var c = w / 2;
    var r2 = (w / 2) * (w / 2);
    var xs = [rect[0], rect[0] + rect[2]];
    var ys = [rect[1], rect[1] + rect[3]];
    for (var i = 0; i < 2; i++) {
        for (var j = 0; j < 2; j++) {
            var dx = xs[i] - c;
            var dy = ys[j] - c;
            if (dx * dx + dy * dy > r2) { return false; }
        }
    }
    return true;
}
