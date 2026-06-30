import Toybox.Lang;
import Toybox.Graphics;

// Maps a pace (seconds/km) to a zone 1..5 using 4 boundary paces (slow->fast,
// strictly decreasing). Faster pace (smaller s/km) => higher zone. 0 if null.
class PaceZoneModel {
    private var _b as Array<Number>;

    function initialize(boundaries as Array<Number>) {
        _b = boundaries;
    }

    function zone(paceSecPerKm as Number or Null) as Number {
        if (paceSecPerKm == null) {
            return 0;
        }
        for (var i = 0; i < _b.size(); i++) {
            if (paceSecPerKm > _b[i]) {
                return i + 1;
            }
        }
        return _b.size() + 1;
    }

    function color(paceSecPerKm as Number or Null) as Graphics.ColorType {
        var z = zone(paceSecPerKm);
        return (_b.size() == 6) ? ZoneColor.of7(z) : ZoneColor.of(z);
    }

    // Fractional zone, e.g. 30% from zone 2 toward zone 3 -> 2.3. Zone 1 and the
    // highest zone are open-ended so they clamp to 1.0 / (N+1).0. 0.0 if null.
    function fractionalZone(paceSecPerKm as Number or Null) as Float {
        if (paceSecPerKm == null) {
            return 0.0;
        }
        if (paceSecPerKm > _b[0]) {
            return 1.0;
        }
        for (var i = 1; i < _b.size(); i++) {
            if (paceSecPerKm > _b[i]) {
                return (i + 1).toFloat() + (_b[i - 1] - paceSecPerKm).toFloat() / (_b[i - 1] - _b[i]);
            }
        }
        return (_b.size() + 1).toFloat();
    }
}
