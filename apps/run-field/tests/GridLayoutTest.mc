import Toybox.Test;
import Toybox.Lang;

(:test)
function gridLayout_sidebarFlushRight(logger as Test.Logger) as Boolean {
    var g = new GridLayout(280, 280);
    var s = g.sidebar();
    return s[0] + s[2] == 280 && s[2] > 0 && s[3] > 0;
}

(:test)
function gridLayout_rowsStacked(logger as Test.Logger) as Boolean {
    var g = new GridLayout(280, 280);
    var p = g.paceCells();
    var h = g.hrCells();
    var b = g.bottomCells();
    return p.size() == 3 && h.size() == 3 && b.size() == 2
        && h[0][1] == p[0][1] + p[0][3]
        && b[0][1] == h[0][1] + h[0][3];
}

(:test)
function gridLayout_gridLeftOfSidebar(logger as Test.Logger) as Boolean {
    var g = new GridLayout(280, 280);
    var p = g.paceCells();
    var s = g.sidebar();
    var c = g.clock();
    return (p[2][0] + p[2][2]) <= s[0]
        && c[1] + c[3] <= p[0][1];
}

(:test)
function gridLayout_inBoundsSmallRound(logger as Test.Logger) as Boolean {
    var g = new GridLayout(240, 240);
    var all = [g.clock(), g.sidebar()];
    var rows = [g.paceCells(), g.hrCells(), g.bottomCells()];
    for (var i = 0; i < all.size(); i++) {
        if (!_inBounds(all[i], 240, 240)) { return false; }
    }
    for (var r = 0; r < rows.size(); r++) {
        var cells = rows[r];
        for (var c = 0; c < cells.size(); c++) {
            if (!_inBounds(cells[c], 240, 240)) { return false; }
        }
    }
    return true;
}

function _inBounds(rect as Array, w as Number, h as Number) as Boolean {
    return rect[0] >= 0 && rect[1] >= 0 && rect[2] > 0 && rect[3] > 0
        && rect[0] + rect[2] <= w && rect[1] + rect[3] <= h;
}
