import Toybox.Lang;
import Toybox.Graphics;

// Zone colour palettes. Each has a dark/saturated variant for a WHITE background
// (MIP, sunlight) and a bright variant for a BLACK background (AMOLED/night).
// Select with onWhite = (getBackgroundColor() == Graphics.COLOR_WHITE). Zone <= 1 -> grey.
// MIP rounds RGB to a 64-colour palette; verify/tune these on the physical watch.
module ZoneColor {
    function of(zone as Number, onWhite as Boolean) as Graphics.ColorType {
        if (onWhite) {
            if (zone <= 1) { return 0x555555; }
            else if (zone == 2) { return 0x0000AA; }
            else if (zone == 3) { return 0x006600; }
            else if (zone == 4) { return 0xAA5500; }
            return 0xAA0000;
        }
        if (zone <= 1) { return 0xAAAAAA; }
        else if (zone == 2) { return 0x00AAFF; }
        else if (zone == 3) { return 0x00CC00; }
        else if (zone == 4) { return 0xFFAA00; }
        return 0xFF3333;
    }

    function of7(zone as Number, onWhite as Boolean) as Graphics.ColorType {
        if (onWhite) {
            if (zone <= 1) { return 0x555555; }
            else if (zone == 2) { return 0x0000AA; }
            else if (zone == 3) { return 0x00AAAA; }
            else if (zone == 4) { return 0x006600; }
            else if (zone == 5) { return 0xAA5500; }
            else if (zone == 6) { return 0xCC6600; }
            return 0xAA0000;
        }
        if (zone <= 1) { return 0xAAAAAA; }
        else if (zone == 2) { return 0x3B82F6; }
        else if (zone == 3) { return 0x00CCCC; }
        else if (zone == 4) { return 0x22C55E; }
        else if (zone == 5) { return 0xF59E0B; }
        else if (zone == 6) { return 0xFF8800; }
        return 0xFF3333;
    }
}
