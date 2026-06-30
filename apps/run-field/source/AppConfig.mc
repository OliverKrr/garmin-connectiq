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
    function paceZonesEnabled() as Boolean { return _bool("paceZonesEnabled", true); }

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

    function autoToggleSec() as Number {
        var v = _num("autoToggleSec", 0);
        return (v < 0) ? 0 : v;
    }

    function paceZoneCount() as Number {
        return (_num("paceZoneCount", 5) == 7) ? 7 : 5;
    }

    function thresholdPaceSec() as Number or Null {
        return parseClock(_str("thresholdPace", ""));
    }

    // Parse "m:ss" -> seconds; null if blank/invalid.
    function parseClock(s as String or Null) as Number or Null {
        if (s == null) { return null; }
        var parts = _split(s, ':');
        if (parts.size() != 2) { return null; }
        var m = parts[0].toNumber();
        var sec = parts[1].toNumber();
        if (m == null || sec == null || m < 0 || sec < 0 || sec > 59) { return null; }
        return m * 60 + sec;
    }

    // Descending pace boundaries (sec/km) from threshold + zone count (5 or 7).
    function derivePaceBoundaries(thresholdSec as Number, count as Number) as Array<Number> {
        var pcts = (count == 7) ? [76, 87, 93, 100, 102, 115] : [78, 88, 95, 100];
        var out = new [pcts.size()];
        for (var i = 0; i < pcts.size(); i++) {
            out[i] = (thresholdSec * 100.0 / pcts[i] + 0.5).toNumber();
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
