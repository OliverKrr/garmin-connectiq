import Toybox.Lang;
import Toybox.Math;
import Toybox.Test;

(:test)
function markers_saveSitsUpperRightDiscardLowerRight(logger as Test.Logger) as Boolean {
    var s = Markers.center(466, 466, Markers.SAVE_DEG);
    var d = Markers.center(466, 466, Markers.DISCARD_DEG);
    logger.debug("save " + s + " discard " + d);
    return s[0] > 350 && s[1] < 233 && d[0] > 350 && d[1] > 233 && s[0] == d[0];
}

(:test)
function markers_hitOnEachMarkerAndNowhereElse(logger as Test.Logger) as Boolean {
    var s = Markers.center(466, 466, Markers.SAVE_DEG);
    var d = Markers.center(466, 466, Markers.DISCARD_DEG);
    return Markers.hit(s[0], s[1], 466, 466) == Markers.SAVE
        && Markers.hit(d[0] + 20, d[1] - 20, 466, 466) == Markers.DISCARD
        && Markers.hit(233, 233, 466, 466) == 0
        && Markers.hit(40, 233, 466, 466) == 0;
}

(:test)
function markers_rectangleHugsTheRightEdge(logger as Test.Logger) as Boolean {
    // Venu X1: 448 x 486, START and BACK on the right edge above and below the middle.
    var s = Markers.center(448, 486, Markers.SAVE_DEG);
    var d = Markers.center(448, 486, Markers.DISCARD_DEG);
    logger.debug("save " + s + " discard " + d);
    return s[0] == d[0] && s[0] > 400 && s[0] + Markers.radius(448, 486) < 448
        && s[1] < 243 && d[1] > 243 && Markers.hit(s[0], s[1], 448, 486) == Markers.SAVE;
}

(:test)
function markers_smallRoundStaysOnScreen(logger as Test.Logger) as Boolean {
    // fenix 8 Solar 47 mm: 260 x 260 MIP, the smallest supported screen.
    var s = Markers.center(260, 260, Markers.SAVE_DEG);
    var r = Markers.radius(260, 260);
    var dx = s[0] - 130;
    var dy = s[1] - 130;
    var reach = Math.sqrt(dx * dx + dy * dy) + r;
    logger.debug("save " + s + " reach " + reach);
    return reach < 130 && r >= 16;
}
