import Toybox.Lang;
import Toybox.Application;

// App settings (Application.Properties, edited in Garmin Connect) with clamped defaults.
module Config {
    // Heat-phase target in seconds; 0 when its alert is off.
    function heatTargetSec() as Number {
        return _bool("warnHeatEnd", true) ? _clamp(_num("heatMin", 12), 1, 60) * 60 : 0;
    }

    // Cool-down target in seconds; 0 when its alert is off.
    function coolTargetSec() as Number {
        return _bool("warnCoolEnd", false) ? _clamp(_num("coolMin", 15), 1, 60) * 60 : 0;
    }

    // Watch-temperature warning in °C; 0 = off.
    function tempLimit() as Number {
        var v = _num("tempLimit", 44);
        return v <= 0 ? 0 : _clamp(v, 30, 70);
    }

    // Heart-rate warning in bpm; 0 = off.
    function hrLimit() as Number {
        var v = _num("hrLimit", 0);
        return v <= 0 ? 0 : _clamp(v, 80, 230);
    }

    function alertVibrate() as Boolean { return _bool("alertVibrate", true); }
    function alertTone() as Boolean { return _bool("alertTone", false); }
    function alertLight() as Boolean { return _bool("alertLight", true); }
    function recordActivity() as Boolean { return _bool("recordActivity", true); }

    function _clamp(v as Number, lo as Number, hi as Number) as Number {
        return v < lo ? lo : (v > hi ? hi : v);
    }

    function _num(key as String, dflt as Number) as Number {
        var v = null;
        try { v = Application.Properties.getValue(key); } catch (e) { }
        return v instanceof Number ? v : dflt;
    }

    function _bool(key as String, dflt as Boolean) as Boolean {
        var v = null;
        try { v = Application.Properties.getValue(key); } catch (e) { }
        return v instanceof Boolean ? v : dflt;
    }
}
