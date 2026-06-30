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

    // Selected pace-zone model code: 0=Off, 1=80/20, 2=Friel, 3=CTS, 4=MyProCoach, 5=Custom.
    // Out of range -> 1 (80/20). "Off"/"Custom" are handled by the caller.
    function paceZoneModel() as Number {
        var m = _num("paceZoneModel", 1);
        return (m < 0 || m > 5) ? 1 : m;
    }

    function paceZones() as Array<Number> or Null {
        return parsePaceZones(_str("paceZonesCsv", ""));
    }

    // Parse "s,s,..." paces (seconds/km, strictly slow->fast i.e. strictly decreasing).
    // Accepts 4 values (5 zones) or 6 (7 zones). Returns the Numbers or null on any problem. Pure.
    function parsePaceZones(csv as String or Null) as Array<Number> or Null {
        if (csv == null) { return null; }
        var parts = _split(csv, ',');
        if (parts.size() != 4 && parts.size() != 6) { return null; }
        var out = new [parts.size()] as Array<Number>;
        var prev = -1 as Number;
        for (var i = 0; i < parts.size(); i++) {
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

    // Descending pace boundaries (sec/km) from a threshold pace + preset model code. The model's
    // percentages are of threshold pace (100% = threshold, higher % = faster). Unknown code -> 80/20.
    function derivePaceBoundaries(thresholdSec as Number, modelCode as Number) as Array<Number> {
        var pcts = (modelCode == 2) ? [77.5, 87.7, 94.3, 100.0, 103.4, 111.5]  // Joe Friel
                 : (modelCode == 3) ? [72.0, 91.0, 97.0, 102.0]                 // CTS
                 : (modelCode == 4) ? [80.0, 90.0, 95.0, 100.0]                 // MyProCoach
                 :                    [76.0, 87.0, 93.0, 100.0, 102.0, 115.0];  // 80/20 + fallback
        var out = new [pcts.size()] as Array<Number>;
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
