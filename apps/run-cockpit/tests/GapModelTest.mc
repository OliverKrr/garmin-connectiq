import Toybox.Lang;
import Toybox.Test;
import Toybox.Activity;

function _near(a as Float or Null, b as Float, tol as Float) as Boolean {
    return a != null && (a - b).abs() <= tol;
}

(:test) function gapModel_flatIsOne(l as Logger) as Boolean { return GapModel.factor(0.0) == 1.0; }
(:test) function gapModel_uphillFaster(l as Logger) as Boolean { return _near(GapModel.factor(5.0), 1.16, 0.001); }
(:test) function gapModel_moderateDownhillSlower(l as Logger) as Boolean { return _near(GapModel.factor(-10.0), 0.89, 0.001); }
(:test) function gapModel_steepDownhillCostsAgain(l as Logger) as Boolean { return GapModel.factor(-25.0) > 1.0; }
(:test) function gapModel_clamped(l as Logger) as Boolean {
    return GapModel.factor(45.0) == GapModel.factor(30.0) && GapModel.factor(-45.0) == GapModel.factor(-30.0);
}

(:test)
function gapDistance_scalesDeltas(l as Logger) as Boolean {
    var g = new GapDistance();
    g.add(0.0, 1.16);      // first sample: no delta
    g.add(100.0, 1.16);
    g.add(100.0, 2.0);     // no movement adds nothing
    g.add(150.0, 1.0);
    return _near(g.flatM(), 166.0, 0.01);
}

(:test)
function gapDistance_ignoresShrinkAndResets(l as Logger) as Boolean {
    var g = new GapDistance();
    g.add(50.0, 1.0);
    g.add(40.0, 1.0);
    var shrinkOk = g.flatM() == 0.0;
    g.add(60.0, 1.0);
    var resumeOk = _near(g.flatM(), 20.0, 0.01);
    g.reset();
    g.add(500.0, 1.0);
    return shrinkOk && resumeOk && g.flatM() == 0.0;
}

// Feeds one sample per second from t0 to t1 at 3 m/s (5:33/km); altitude climbs at `grade` %
// from `alt0`. Returns the altitude reached.
function _runSegment(m as RunModel, info as Activity.Info, t0 as Number, t1 as Number, grade as Float, alt0 as Float) as Float {
    var alt = alt0;
    for (var t = t0; t <= t1; t++) {
        alt = alt0 + (t - t0) * 3.0 * grade / 100.0;
        info.timerTime = t * 1000;
        info.elapsedDistance = t * 3.0;
        info.altitude = alt;
        m.update(info);
    }
    return alt;
}

function _gapModel(paceVsPower as Number) as Array {
    var m = new RunModel(0, new HrZoneModel([93, 111, 130, 148, 167, 185]));
    m.setPaceVsPower(paceVsPower);
    m.setClimbMetricGap(true);
    var info = new Activity.Info();
    info.timerState = Activity.TIMER_STATE_ON;
    info.currentSpeed = 3.0;
    return [m, info];
}

// Always GAP: 300 s up 5 %, a lap, 300 s flat. Pace stays raw pace; GAP runs alongside it.
(:test)
function runModel_gapAlwaysClimbThenFlatLap(l as Logger) as Boolean {
    var mi = _gapModel(2);
    var m = mi[0] as RunModel;
    var info = mi[1] as Activity.Info;
    var top = _runSegment(m, info, 0, 300, 5.0, 100.0);
    // 333.3 s/km / 1.16 = 287.4 s/km once the grade has settled; the lap includes the ramp-up.
    var climbOk = _near(m.gapCurSec(), 287.4, 2.0) && _near(m.gapLapSec(), 289.0, 4.0)
        && _near(m.paceLapSec(), 333.3, 1.0) && m.showClimbForCurLap();
    l.debug("climb gapCur=" + m.gapCurSec() + " gapLap=" + m.gapLapSec() + " paceLap=" + m.paceLapSec());
    m.onLap();
    _runSegment(m, info, 301, 600, 0.0, top);
    var flatOk = _near(m.gapLapSec(), 333.3, 5.0) && _near(m.gapCurSec(), 333.3, 1.0);
    // Average spans both halves: 1800 m over 600 s, half of it worth 1.16x.
    var avgOk = _near(m.gapAvgSec(), 1000.0 / ((900.0 * 1.16 + 900.0) / 600.0), 6.0);
    l.debug("flat gapLap=" + m.gapLapSec() + " gapAvg=" + m.gapAvgSec());
    return climbOk && flatOk && avgOk;
}

// Auto with GAP: pace on the flat, GAP from the 3 % threshold up, pace again once the grade
// falls below the hysteresis band. No power reading is needed.
(:test)
function runModel_gapAutoSwitchesOnClimb(l as Logger) as Boolean {
    var mi = _gapModel(0);
    var m = mi[0] as RunModel;
    var info = mi[1] as Activity.Info;
    m.setGradeThreshold(3);
    var alt = _runSegment(m, info, 0, 100, 0.0, 100.0);
    var flat1 = m.showClimbForCurLap();
    alt = _runSegment(m, info, 101, 200, 5.0, alt);
    var climb = m.showClimbForCurLap();
    _runSegment(m, info, 201, 300, 0.0, alt);
    var flat2 = m.showClimbForCurLap();
    return !flat1 && climb && !flat2;
}

// Power as climb metric keeps the old rule: no live power, no switch; and no GAP is computed.
(:test)
function runModel_powerMetricNeedsLivePower(l as Logger) as Boolean {
    var m = new RunModel(0, new HrZoneModel([93, 111, 130, 148, 167, 185]));
    m.setPaceVsPower(2);
    m.setClimbMetricGap(false);
    var info = new Activity.Info();
    info.timerState = Activity.TIMER_STATE_ON;
    info.currentSpeed = 3.0;
    _runSegment(m, info, 0, 60, 5.0, 100.0);
    return !m.showClimbForCurLap() && m.gapCurSec() == null && m.gapAvgSec() == null;
}

// Same placeholder altitude through RunModel: average GAP on the flat must equal average pace.
(:test)
function runModel_gapIgnoresStartAltitudeJump(l as Logger) as Boolean {
    var mi = _gapModel(0);
    var m = mi[0] as RunModel;
    var info = mi[1] as Activity.Info;
    info.timerTime = 0;
    info.elapsedDistance = 0.0;
    info.altitude = 0.0;
    m.update(info);
    _runSegment(m, info, 1, 300, 0.0, 640.0);
    l.debug("gapAvg after a start jump=" + m.gapAvgSec());
    return _near(m.gapAvgSec(), 333.3, 1.0);
}
