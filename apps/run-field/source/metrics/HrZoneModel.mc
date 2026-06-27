import Toybox.Lang;
import Toybox.Graphics;

// Maps a heart rate to zone / fractional zone / colour using the 6 thresholds
// from UserProfile.getHeartRateZones(): [minZ1, maxZ1, maxZ2, maxZ3, maxZ4, maxZ5].
class HrZoneModel {
    private var _t as Array<Number>;

    function initialize(thresholds as Array<Number>) {
        _t = thresholds;
    }

    // Integer zone 1..5; 0 if below zone 1.
    function zone(hr as Number) as Number {
        if (hr < _t[0]) {
            return 0;
        }
        for (var z = 1; z <= 5; z++) {
            if (hr < _t[z]) {
                return z;
            }
        }
        return 5;
    }

    // Fractional zone, e.g. 30% through zone 2 -> 2.3. Clamped to [1.0, 5.0].
    function fractionalZone(hr as Number) as Float {
        if (hr <= _t[0]) {
            return 1.0;
        }
        if (hr >= _t[5]) {
            return 5.0;
        }
        for (var z = 1; z <= 5; z++) {
            var lo = _t[z - 1];
            var hi = _t[z];
            if (hr < hi) {
                return z + (hr - lo).toFloat() / (hi - lo).toFloat();
            }
        }
        return 5.0;
    }

    // Garmin-style zone colour. Zone 0/1 share the grey of zone 1.
    function color(zone as Number) as Graphics.ColorType {
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
