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

// Steady 3 m/s (5:33/km) up a 5 % grade for 300 s, then a lap and 300 s on the flat.
(:test)
function runModel_gapModeClimbThenFlatLap(l as Logger) as Boolean {
    var m = new RunModel(0, new HrZoneModel([93, 111, 130, 148, 167, 185]));
    m.setPaceVsPower(3);
    var info = new Activity.Info();
    info.timerState = Activity.TIMER_STATE_ON;
    info.currentSpeed = 3.0;
    for (var t = 0; t <= 300; t++) {
        info.timerTime = t * 1000;
        info.elapsedDistance = t * 3.0;
        info.altitude = 100.0 + t * 3.0 * 0.05;
        m.update(info);
    }
    // 333.3 s/km / 1.16 = 287.4 s/km once the grade has settled; the lap includes the ramp-up.
    var climbOk = _near(m.paceCurSec(), 287.4, 2.0) && _near(m.paceLapSec(), 289.0, 4.0);
    l.debug("climb cur=" + m.paceCurSec() + " lap=" + m.paceLapSec());
    m.onLap();
    for (var t = 301; t <= 600; t++) {
        info.timerTime = t * 1000;
        info.elapsedDistance = t * 3.0;
        info.altitude = 145.0;
        m.update(info);
    }
    var flatOk = _near(m.paceLapSec(), 333.3, 5.0) && _near(m.paceCurSec(), 333.3, 1.0);
    // Average spans both halves: 1800 m over 600 s, half of it worth 1.16x.
    var avgOk = _near(m.paceAvgSec(), 1000.0 / ((900.0 * 1.16 + 900.0) / 600.0), 6.0);
    l.debug("flat lap=" + m.paceLapSec() + " avg=" + m.paceAvgSec());
    return climbOk && flatOk && avgOk && !m.showPowerForCurLap();
}
