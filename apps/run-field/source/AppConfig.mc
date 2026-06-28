import Toybox.Lang;
import Toybox.Application;

// Reads app settings (Application.Properties) with safe defaults. parsePaceZones
// is a pure function and is unit-tested; the property readers need runtime.
module AppConfig {

    function rollingWindowSec() as Number {
        var v = _num("rollingWindowSec", 25);
        if (v < 5) { v = 5; }
        if (v > 120) { v = 120; }
        return v;
    }

    function usePower() as Boolean { return _bool("usePower", false); }
    function paceZonesEnabled() as Boolean { return _bool("paceZonesEnabled", false); }

    function paceZones() as Array<Number> or Null {
        return parsePaceZones(_str("paceZonesCsv", ""));
    }

    // Parse "s,s,s,s" (4 paces in seconds/km, strictly slow->fast i.e. strictly
    // decreasing). Returns the 4 Numbers or null on any problem. Pure.
    function parsePaceZones(csv as String or Null) as Array<Number> or Null {
        if (csv == null) { return null; }
        var parts = _split(csv, ',');
        if (parts.size() != 4) { return null; }
        var out = new [4] as Array<Number>;
        var prev = -1 as Number;
        for (var i = 0; i < 4; i++) {
            var n = parts[i].toNumber();
            if (n == null || n <= 0) { return null; }
            if (i > 0 && n >= prev) { return null; }
            out[i] = n;
            prev = n;
        }
        return out;
    }

    function _split(s as String, sep as Char) as Array<String> {
        var res = [] as Array<String>;
        var cur = "";
        var chars = s.toCharArray();
        for (var i = 0; i < chars.size(); i++) {
            var c = chars[i];
            if (c == sep) {
                res.add(cur);
                cur = "";
            } else if (c != ' ') {
                cur += c.toString();
            }
        }
        res.add(cur);
        return res;
    }

    function _num(key as String, dflt as Number) as Number {
        var v = Properties.getValue(key);
        return (v instanceof Number) ? v : dflt;
    }
    function _bool(key as String, dflt as Boolean) as Boolean {
        var v = Properties.getValue(key);
        return (v instanceof Boolean) ? v : dflt;
    }
    function _str(key as String, dflt as String) as String {
        var v = Properties.getValue(key);
        return (v instanceof String) ? v : dflt;
    }
}
