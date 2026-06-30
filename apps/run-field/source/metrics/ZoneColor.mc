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

    // 7-zone palette (intervals.icu-style) for pace; zone 0/1 -> grey.
    function of7(zone as Number) as Graphics.ColorType {
        if (zone <= 1) { return 0x9E9E9E; }
        else if (zone == 2) { return 0x3B82F6; }
        else if (zone == 3) { return 0x06B6D4; }
        else if (zone == 4) { return 0x22C55E; }
        else if (zone == 5) { return 0xA3E635; }
        else if (zone == 6) { return 0xF59E0B; }
        return 0xEF4444;
    }
}
