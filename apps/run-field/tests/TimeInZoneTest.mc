import Toybox.Test;
import Toybox.Lang;

(:test)
function timeInZone_tallyAndMax(logger as Test.Logger) as Boolean {
    var t = new TimeInZone();
    t.addSecond(1); t.addSecond(1); t.addSecond(3);
    var c = t.counts();
    return c[0] == 2 && c[1] == 0 && c[2] == 1 && c[3] == 0 && c[4] == 0 && t.maxCount() == 2;
}

(:test)
function timeInZone_clamps(logger as Test.Logger) as Boolean {
    var t = new TimeInZone();
    t.addSecond(0); t.addSecond(9);
    var c = t.counts();
    return c[0] == 1 && c[4] == 1;
}

(:test)
function timeInZone_reset(logger as Test.Logger) as Boolean {
    var t = new TimeInZone();
    t.addSecond(2); t.addSecond(4);
    t.reset();
    return t.maxCount() == 0;
}
