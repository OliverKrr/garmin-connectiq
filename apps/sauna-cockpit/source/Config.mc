import Toybox.Lang;
import Toybox.Application;

const SCREEN_NORMAL = 0;
const SCREEN_DIM = 1;

// App settings (Application.Properties, edited in Garmin Connect or on the watch through
// SettingsMenu) with clamped defaults.
module Config {
    // Heat-phase target in seconds; 0 when its alert is off.
    function heatTargetSec() as Number {
        return _bool("warnHeatEnd", true) ? _clamp(_num("heatMin", 12), 1, 60) * 60 : 0;
    }

    // Cool-down target in seconds; 0 when its alert is off.
    function coolTargetSec() as Number {
        return _bool("warnCoolEnd", false) ? _clamp(_num("coolMin", 15), 1, 60) * 60 : 0;
    }

    // Watch-temperature alert ("leave now") in °C; 0 = off.
    function tempLimit() as Number {
        var v = _num("tempLimit", 44);
        return v <= 0 ? 0 : _clamp(v, 30, 70);
    }

    // Watch-temperature pre-warning ("cover the watch") in °C; 0 = off.
    function tempWarn() as Number {
        var v = _num("tempWarn", 42);
        return v <= 0 ? 0 : _clamp(v, 30, 70);
    }

    // Heart-rate warning in bpm; 0 = off.
    function hrLimit() as Number {
        var v = _num("hrLimit", 0);
        return v <= 0 ? 0 : _clamp(v, 80, 230);
    }

    // Session screen between button presses, per phase: SCREEN_NORMAL or SCREEN_DIM (every colour
    // at about 40 %). A button press or an alert shows it at full brightness for a few seconds.
    // A black screen is a page of its own (SessionView), chosen on demand. 0.2.0's Dark (2) reads
    // as Dim.
    function heatScreen() as Number { return _clamp(_num("heatScreen", SCREEN_DIM), 0, 1); }
    function restScreen() as Number { return _clamp(_num("restScreen", SCREEN_DIM), 0, 1); }

    function alertVibrate() as Boolean { return _bool("alertVibrate", true); }
    function alertTone() as Boolean { return _bool("alertTone", false); }
    function alertLight() as Boolean { return _bool("alertLight", true); }
    function recordActivity() as Boolean { return _bool("recordActivity", true); }

    // Activity type: false = Other (calories counted), true = Meditation (Garmin keeps measuring
    // stress during the session, but counts no calories and books the sauna's stress into the day).
    function recordAsMeditation() as Boolean { return _num("recordAs", 0) == 1; }

    // Phase targets as the on-watch menu shows them: whole minutes, 0 = no target alert.
    function heatTargetMin() as Number { return heatTargetSec() / 60; }
    function coolTargetMin() as Number { return coolTargetSec() / 60; }

    function setHeatTargetMin(v as Number) as Void { _setTarget("heatMin", "warnHeatEnd", v); }
    function setCoolTargetMin(v as Number) as Void { _setTarget("coolMin", "warnCoolEnd", v); }

    function set(key as String, v as Number or Boolean) as Void {
        try { Application.Properties.setValue(key, v); } catch (e) { }
    }

    function _setTarget(minKey as String, onKey as String, v as Number) as Void {
        set(onKey, v > 0);
        if (v > 0) { set(minKey, v); }
    }

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
