import Toybox.Lang;
import Toybox.Graphics;

// Maps a pace (seconds/km) to a zone 1..5 using 4 boundary paces (slow->fast,
// strictly decreasing). Faster pace (smaller s/km) => higher zone. 0 if null.
class PaceZoneModel {
    // 80/20 Run zone names (7 zones): 1, 2, X, 3, Y, 4, 5. X and Y are the "avoid" zones.
    private const NAMES_8020 = ["1", "2", "X", "3", "Y", "4", "5"];

    private var _b as Array<Number>;
    // Pace-zone model code (matches AppConfig: 1=80/20, 2=Friel, ...). Only 1 (80/20) is special
    // (X/Y names + its own grey-heavy palette); everything else uses numeric names + size-based palette.
    private var _modelCode as Number = 0;

    function initialize(boundaries as Array<Number>) {
        _b = boundaries;
    }

    function setModelCode(code as Number) as Void { _modelCode = code; }

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

    function color(paceSecPerKm as Number or Null, onWhite as Boolean) as Graphics.ColorType {
        var z = zone(paceSecPerKm);
        if (_modelCode == 1 && _b.size() == 6) {
            return ZoneColor.of8020(z, onWhite);
        }
        return (_b.size() == 6) ? ZoneColor.of7(z, onWhite) : ZoneColor.of(z, onWhite);
    }

    // Zone label: the fractional zone as "name.decimal" (e.g. "2.3"), using the 80/20 names
    // (1, 2, X, 3, Y, 4, 5) when this is the 80/20 model, else the numeric zone. "" if null.
    function label(paceSecPerKm as Number or Null) as String {
        if (paceSecPerKm == null) {
            return "";
        }
        var f = fractionalZone(paceSecPerKm);
        var iz = f.toNumber();
        var dec = (((f - iz) * 10) + 0.5).toNumber();
        if (dec > 9) {
            iz += 1;
            dec = 0;
        }
        var namePart;
        if (_modelCode == 1 && _b.size() == 6 && iz >= 1 && iz <= 7) {
            namePart = NAMES_8020[iz - 1];
        } else {
            namePart = iz.toString();
        }
        return namePart + "." + dec.toString();
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
