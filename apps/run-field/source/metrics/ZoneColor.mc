import Toybox.Lang;
import Toybox.Graphics;

// The shared 1..5 zone colour palette (zone 0/1 -> grey).
module ZoneColor {
    function of(zone as Number) as Graphics.ColorType {
        if (zone <= 1) {
            return Graphics.COLOR_LT_GRAY;
        } else if (zone == 2) {
            return Graphics.COLOR_BLUE;
        } else if (zone == 3) {
            return Graphics.COLOR_GREEN;
        } else if (zone == 4) {
            return Graphics.COLOR_ORANGE;
        }
        return Graphics.COLOR_RED;
    }
}
