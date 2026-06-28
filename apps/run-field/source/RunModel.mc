import Toybox.Lang;
import Toybox.Activity;
import Toybox.System;
import Toybox.Graphics;

// Per-second state for the running data field. update(info) reads Activity.Info,
// feeds the metric classes, and caches display-ready values that onUpdate() reads
// without allocating. Session averages are native (Activity.Info); lap values are
// accumulated here and reset on lap.
class RunModel {
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
    private var _usePower as Boolean = false;
    private var _distM as Float = 0.0;
    private var _timerMs as Number = 0;
    private var _zoneCur as Number = 0;

    function initialize(windowSec as Number, zones as HrZoneModel) {
        _zones = zones;
        _rollingPace = new RollingPace(windowSec);
        _lapHr = new RunningAverage();
        _tiz = new TimeInZone();
    }

    function update(info as Activity.Info) as Void {
        var timer = (info has :timerTime) ? info.timerTime : null;
        var dist = (info has :elapsedDistance) ? info.elapsedDistance : null;
        var hr = (info has :currentHeartRate) ? info.currentHeartRate : null;
        var avgSpeed = (info has :averageSpeed) ? info.averageSpeed : null;

        if (timer != null) { _timerMs = timer; }
        if (dist != null) { _distM = dist; }

        if (timer != null && dist != null) {
            _rollingPace.add(timer, dist);
            _paceCur = _rollingPace.paceSecPerKm();
            _paceLap = Pace.secPerKmFromDelta(dist - _lapStartDist, timer - _lapStartMs);
        }
        _paceAvg = Pace.secPerKmFromSpeed(avgSpeed);

        if (hr != null) {
            _hrCur = hr;
            _lapHr.add(hr);
            _zoneCur = _zones.zone(hr);
            _tiz.addSecond(_zoneCur < 1 ? 1 : _zoneCur);
        } else {
            _hrCur = null;
        }
        _hrAvg = (info has :averageHeartRate) ? info.averageHeartRate : null;

        var power = (info has :currentPower) ? info.currentPower : null;
        if (power != null) {
            _powerCur = power;
            _lapPower.add(power);
        } else {
            _powerCur = null;
        }
        _powerAvg = (info has :averagePower) ? info.averagePower : null;
    }

    function onLap() as Void {
        _lapStartMs = _timerMs;
        _lapStartDist = _distM;
        _lapHr.reset();
        _lapPower.reset();
    }

    function onReset() as Void {
        _lapStartMs = 0;
        _lapStartDist = 0.0;
        _rollingPace.reset();
        _lapHr.reset();
        _lapPower.reset();
        _tiz.reset();
    }

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

    function hrColor(hr as Number or Null, fallback as Graphics.ColorType) as Graphics.ColorType {
        if (hr == null) { return fallback; }
        return _zones.color(_zones.zone(hr));
    }

    function setUsePower(use as Boolean) as Void { _usePower = use; }
    function setPowerZones(z as HrZoneModel or Null) as Void { _powerZones = z; }
    function usePower() as Boolean { return _usePower; }

    function powerCur() as Number or Null { return _powerCur; }
    function powerLap() as Number or Null { return _lapPower.average(); }
    function powerAvg() as Number or Null { return _powerAvg; }

    function powerStr(w as Number or Null) as String {
        return (w == null) ? "--" : w.format("%d");
    }

    function powerColor(w as Number or Null, fallback as Graphics.ColorType) as Graphics.ColorType {
        if (w == null || _powerZones == null) { return fallback; }
        return _powerZones.color(_powerZones.zone(w));
    }

    function zoneCounts() as Array<Number> { return _tiz.counts(); }
    function zoneMax() as Number { return _tiz.maxCount(); }
    function zoneTotal() as Number { return _tiz.total(); }
    function zoneColor(zoneIndex as Number) as Graphics.ColorType { return _zones.color(zoneIndex); }
}
