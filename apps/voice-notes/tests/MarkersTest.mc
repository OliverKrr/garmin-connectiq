import Toybox.Lang;
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
