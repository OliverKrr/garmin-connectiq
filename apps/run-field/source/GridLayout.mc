import Toybox.Lang;

// Computes the screen rectangles for the run-field layout once per onLayout().
// A rect is [x, y, w, h] (Numbers). Geometry is proportional to the device size,
// so it adapts to any screen; pixel ratios are tuned for 280x280 round.
class GridLayout {
    private var _clock as Array<Number>;
    private var _pace as Array;
    private var _hr as Array;
    private var _bottom as Array;
    private var _sidebar as Array<Number>;

    function initialize(w as Number, h as Number) {
        var m = (w * 3) / 100;
        var sidebarW = (w * 18) / 100;
        var sidebarX = w - sidebarW;
        var gridX = m;
        var gridRight = sidebarX - m;
        var gridW = gridRight - gridX;
        var clockH = (h * 12) / 100;
        var gridTop = m + clockH;
        var gridBottom = h - m;
        var rowsH = gridBottom - gridTop;
        var rowH = rowsH / 3;

        _clock = [gridX, m, gridW, clockH];
        _sidebar = [sidebarX, gridTop, sidebarW, rowsH];

        var col3 = gridW / 3;
        var col2 = gridW / 2;
        _pace = [
            [gridX, gridTop, col3, rowH],
            [gridX + col3, gridTop, col3, rowH],
            [gridX + 2 * col3, gridTop, gridRight - (gridX + 2 * col3), rowH]
        ];
        var hrY = gridTop + rowH;
        _hr = [
            [gridX, hrY, col3, rowH],
            [gridX + col3, hrY, col3, rowH],
            [gridX + 2 * col3, hrY, gridRight - (gridX + 2 * col3), rowH]
        ];
        var botY = gridTop + 2 * rowH;
        _bottom = [
            [gridX, botY, col2, rowH],
            [gridX + col2, botY, gridRight - (gridX + col2), rowH]
        ];
    }

    function clock() as Array<Number> { return _clock; }
    function paceCells() as Array { return _pace; }
    function hrCells() as Array { return _hr; }
    function bottomCells() as Array { return _bottom; }
    function sidebar() as Array<Number> { return _sidebar; }
}
