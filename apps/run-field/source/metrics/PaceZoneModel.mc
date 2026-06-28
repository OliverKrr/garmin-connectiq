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
        if (paceSecPerKm > _b[0]) { return 1; }
        if (paceSecPerKm > _b[1]) { return 2; }
        if (paceSecPerKm > _b[2]) { return 3; }
        if (paceSecPerKm > _b[3]) { return 4; }
        return 5;
    }

    function color(paceSecPerKm as Number or Null) as Graphics.ColorType {
        return ZoneColor.of(zone(paceSecPerKm));
    }
}
