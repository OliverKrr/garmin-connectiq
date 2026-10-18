import Toybox.Lang;
import Toybox.Activity;
import Toybox.System;
import Toybox.Graphics;

// Per-second state for the running data field. update(info) reads Activity.Info,
// feeds the metric classes, and caches display-ready values that onUpdate() reads
// without allocating. Session averages are native (Activity.Info); lap values are
// accumulated here and reset on lap. With GAP as the climb metric, a second set of values (current,
// lap, average GAP) runs the same pipeline on flat-equivalent distance; pace stays raw pace.
class RunModel {
    // Current pace and current GAP are rolling averages over this many seconds of timer time.
    private const ROLLING_SEC = 10;

    private var _zones as HrZoneModel;
    private var _rollingPace as RollingPace;
    private var _lapHr as RunningAverage;
    private var _tiz as TimeInZone;

    private var _lapStartMs as Number = 0;
    private var _lapStartDist as Float = 0.0;

    private var _paceCur as Float or Null = null;
    private var _paceLap as Float or Null = null;
    private var _paceAvg as Float or Null = null;
    private var _hrCur as Number or Null = null;
    private var _hrAvg as Number or Null = null;
    private var _lapPower as RunningAverage = new RunningAverage();
    private var _powerCur as Number or Null = null;
    private var _powerAvg as Number or Null = null;
    private var _powerZones as HrZoneModel or Null = null;
    private var _paceZones as PaceZoneModel or Null = null;
    private var _distM as Float = 0.0;
    private var _timerMs as Number = 0;
    private var _zoneCur as Number = 0;
    private var _grade as GradeModel = new GradeModel();
    private var _paceVsPower as Number = 0;
    private var _gradeThreshold as Number = 3;
    private var _climbActive as Boolean = false;
    private var _gap as Boolean = false; // climb metric: GAP (true) or power (false)
    private var _flat as GapDistance = new GapDistance();
    private var _rollingGap as RollingPace or Null = null;
    private var _lapStartFlat as Float = 0.0;
    private var _gapCur as Float or Null = null;
    private var _gapLap as Float or Null = null;
    private var _gapAvg as Float or Null = null;

    function initialize(zones as HrZoneModel) {
        _zones = zones;
        _rollingPace = new RollingPace(ROLLING_SEC);
        _lapHr = new RunningAverage();
        _tiz = new TimeInZone();
    }

    function update(info as Activity.Info) as Void {
        var timer = (info has :timerTime) ? info.timerTime : null;
        var dist = (info has :elapsedDistance) ? info.elapsedDistance : null;
        var hr = (info has :currentHeartRate) ? info.currentHeartRate : null;
        var avgSpeed = (info has :averageSpeed) ? info.averageSpeed : null;
        var spd = (info has :currentSpeed) ? info.currentSpeed : null;

        if (timer != null) { _timerMs = timer; }
        if (dist != null) { _distM = dist; }

        // Only accumulate stats while the timer is running. compute() also fires
        // before the activity starts and while paused, when the timer is not
        // advancing — accumulating then would (e.g.) grow the time-in-zone bars.
        var running = (info has :timerState) ? (info.timerState == Activity.TIMER_STATE_ON) : true;

        if (running && dist != null && (info has :altitude)) {
            _grade.update(_distM, info.altitude);
        }

        // Rolling while the timer runs; before the start, while paused and for the first sample,
        // Garmin's own current speed stands in.
        var cur = null as Float or Null;
        if (running && timer != null && dist != null) {
            _rollingPace.add(timer, dist);
            cur = _rollingPace.paceSecPerKm();
            _paceLap = Pace.secPerKmFromDelta(dist - _lapStartDist, timer - _lapStartMs);
        }
        _paceCur = (cur != null) ? cur : Pace.secPerKmFromSpeed(spd);
        _paceAvg = Pace.secPerKmFromSpeed(avgSpeed);

        if (_gap) {
            // GAP: the pace pipeline on flat-equivalent distance; speed * factor stands in like above.
            var f = GapModel.factor(_grade.grade());
            var rg = _rollingGap;
            var gcur = null as Float or Null;
            if (running && timer != null && dist != null) {
                _flat.add(dist, f);
                if (rg != null) { rg.add(timer, _flat.flatM()); gcur = rg.paceSecPerKm(); }
                _gapLap = Pace.secPerKmFromDelta(_flat.flatM() - _lapStartFlat, timer - _lapStartMs);
            }
            if (gcur == null && spd != null) { gcur = Pace.secPerKmFromSpeed(spd * f); }
            _gapCur = gcur;
            _gapAvg = Pace.secPerKmFromDelta(_flat.flatM(), _timerMs);
        }

        if (hr != null) {
            _hrCur = hr;
            _zoneCur = _zones.zone(hr);
            if (running) {
                _lapHr.add(hr);
                _tiz.addSecond(_zoneCur < 1 ? 1 : _zoneCur);
            }
        } else {
            _hrCur = null;
        }
        _hrAvg = (info has :averageHeartRate) ? info.averageHeartRate : null;

        var power = (info has :currentPower) ? info.currentPower : null;
        if (power != null) {
            _powerCur = power;
            if (running) {
                _lapPower.add(power);
            }
        } else {
            _powerCur = null;
        }
        _powerAvg = (info has :averagePower) ? info.averagePower : null;
    }

    function onLap() as Void {
        _lapStartMs = _timerMs;
        _lapStartDist = _distM;
        _lapStartFlat = _flat.flatM();
        _lapHr.reset();
        _lapPower.reset();
    }

    function onReset() as Void {
        _lapStartMs = 0;
        _lapStartDist = 0.0;
        _lapStartFlat = 0.0;
        _flat.reset();
        var rg = _rollingGap;
        if (rg != null) { rg.reset(); }
        _rollingPace.reset();
        _lapHr.reset();
        _lapPower.reset();
        _tiz.reset();
        _grade.reset();
    }

    function paceCurSec() as Float or Null { return _paceCur; }
    function paceLapSec() as Float or Null { return _paceLap; }
    function paceAvgSec() as Float or Null { return _paceAvg; }
    function gapCurSec() as Float or Null { return _gapCur; }
    function gapLapSec() as Float or Null { return _gapLap; }
    function gapAvgSec() as Float or Null { return _gapAvg; }

    function paceCurStr() as String { return PaceFormat.paceSecPerKm(_paceCur); }
    function paceLapStr() as String { return PaceFormat.paceSecPerKm(_paceLap); }
    function paceAvgStr() as String { return PaceFormat.paceSecPerKm(_paceAvg); }

    function hrCur() as Number or Null { return _hrCur; }
    function hrLap() as Number or Null { return _lapHr.average(); }
    function hrAvg() as Number or Null { return _hrAvg; }

    function distanceStr() as String { return (_distM / 1000.0).format("%.2f"); }
    function durationStr() as String { return PaceFormat.durationMs(_timerMs); }

    function clockStr() as String {
        var t = System.getClockTime();
        return t.hour.format("%02d") + ":" + t.min.format("%02d");
    }

    // Fractional zone (e.g. 2.5) for any HR value; "--" when null.
    function fractionalZoneStrFor(hr as Number or Null) as String {
        if (hr == null) { return "--"; }
        return _zones.fractionalZone(hr).format("%.1f");
    }

    function hrColor(hr as Number or Null, fallback as Graphics.ColorType, onWhite as Boolean) as Graphics.ColorType {
        if (hr == null) { return fallback; }
        return _zones.color(_zones.zone(hr), onWhite);
    }

    function setPowerZones(z as HrZoneModel or Null) as Void { _powerZones = z; }
    function setPaceZones(z as PaceZoneModel or Null) as Void { _paceZones = z; }

    function setPaceVsPower(m as Number) as Void { _paceVsPower = m; }
    function setGradeThreshold(t as Number) as Void { _gradeThreshold = t; }

    // Climb metric: GAP (true) or power (false). Rolling GAP needs its own buffer.
    function setClimbMetricGap(gap as Boolean) as Void {
        _gap = gap;
        _rollingGap = gap ? new RollingPace(ROLLING_SEC) : null;
    }
    function climbMetricGap() as Boolean { return _gap; }

    // True when Current/Lap show the climb metric instead of pace: Always, or Auto with the grade
    // over the threshold (hysteresis). Power also needs a live reading; GAP needs none.
    function showClimbForCurLap() as Boolean {
        if (_paceVsPower == 1) { return false; }
        if (!_gap && _powerCur == null) { return false; }
        if (_paceVsPower == 2) { return true; }
        _climbActive = PowerSwitch.active(_grade.grade(), _gradeThreshold.toFloat(), _climbActive);
        return _climbActive;
    }

    // Fractional pace zone as " x.x" for a label, or "" when pace zones aren't set.
    function paceZoneStrFor(secPerKm as Float or Null) as String {
        if (secPerKm == null || _paceZones == null) { return ""; }
        return " " + _paceZones.label(secPerKm.toNumber());
    }
    function paceCurZone() as String { return paceZoneStrFor(_paceCur); }
    function paceLapZone() as String { return paceZoneStrFor(_paceLap); }
    function paceAvgZone() as String { return paceZoneStrFor(_paceAvg); }
    function gapCurZone() as String { return paceZoneStrFor(_gapCur); }
    function gapLapZone() as String { return paceZoneStrFor(_gapLap); }
    function gapAvgZone() as String { return paceZoneStrFor(_gapAvg); }

    // Fractional power zone as " x.x" for a label, or "" when power zones aren't available.
    function powerZoneStrFor(w as Number or Null) as String {
        if (w == null || _powerZones == null) { return ""; }
        return " " + _powerZones.fractionalZone(w).format("%.1f");
    }

    // Colour for a pace value (seconds/km) by pace zone; fallback when no zones/null.
    function paceColor(secPerKm as Float or Null, fallback as Graphics.ColorType, onWhite as Boolean) as Graphics.ColorType {
        if (secPerKm == null || _paceZones == null) { return fallback; }
        return _paceZones.color(secPerKm.toNumber(), onWhite);
    }
    function paceCurColor(fb as Graphics.ColorType, onWhite as Boolean) as Graphics.ColorType { return paceColor(_paceCur, fb, onWhite); }
    function paceLapColor(fb as Graphics.ColorType, onWhite as Boolean) as Graphics.ColorType { return paceColor(_paceLap, fb, onWhite); }
    function paceAvgColor(fb as Graphics.ColorType, onWhite as Boolean) as Graphics.ColorType { return paceColor(_paceAvg, fb, onWhite); }
    function gapCurColor(fb as Graphics.ColorType, onWhite as Boolean) as Graphics.ColorType { return paceColor(_gapCur, fb, onWhite); }
    function gapLapColor(fb as Graphics.ColorType, onWhite as Boolean) as Graphics.ColorType { return paceColor(_gapLap, fb, onWhite); }
    function gapAvgColor(fb as Graphics.ColorType, onWhite as Boolean) as Graphics.ColorType { return paceColor(_gapAvg, fb, onWhite); }

    function gapCurStr() as String { return PaceFormat.paceSecPerKm(_gapCur); }
    function gapLapStr() as String { return PaceFormat.paceSecPerKm(_gapLap); }
    function gapAvgStr() as String { return PaceFormat.paceSecPerKm(_gapAvg); }

    function powerCur() as Number or Null { return _powerCur; }
    function powerLap() as Number or Null { return _lapPower.average(); }
    function powerAvg() as Number or Null { return _powerAvg; }

    function powerStr(w as Number or Null) as String {
        return (w == null) ? "--" : w.format("%d");
    }

    function powerColor(w as Number or Null, fallback as Graphics.ColorType, onWhite as Boolean) as Graphics.ColorType {
        if (w == null || _powerZones == null) { return fallback; }
        return _powerZones.color(_powerZones.zone(w), onWhite);
    }

    function zoneCounts() as Array<Number> { return _tiz.counts(); }
    function zoneMax() as Number { return _tiz.maxCount(); }
    function zoneTotal() as Number { return _tiz.total(); }
    function zoneColor(zoneIndex as Number, onWhite as Boolean) as Graphics.ColorType { return _zones.color(zoneIndex, onWhite); }
}
