import Toybox.Lang;

// Phase codes, also written to the FIT "phase" field.
const PHASE_HEAT = 0;
const PHASE_COOL = 1;

// Event bits returned by SessionModel.tick().
const EV_HEAT_DONE = 1;   // heat phase reached its target time
const EV_COOL_DONE = 2;   // cool-down phase reached its target time
const EV_TEMP_HIGH = 4;   // watch temperature reached the warning limit
const EV_HR_HIGH = 8;     // heart rate reached the warning limit

// A sauna session: alternating heat and cool-down phases, one round per heat phase.
// Time advances only through tick() (once per recorded second), so the whole state machine
// is deterministic and unit-tested; SessionController feeds it sensor readings.
class SessionModel {
    var phase as Number = PHASE_HEAT;
    var round as Number = 1;
    var total as PhaseStats = new PhaseStats();
    var current as PhaseStats = new PhaseStats();
    // Completed phases in order, each [phaseCode, PhaseStats].
    var done as Array<Array> = [] as Array<Array>;
    var lastHr as Number or Null = null;
    var lastTemp as Float or Null = null;
    private var _heatTarget as Number;
    private var _coolTarget as Number;
    private var _tempAlarm as ThresholdAlarm;
    private var _hrAlarm as ThresholdAlarm;

    // Targets in seconds (0 = no target alert); limits in °C and bpm (0 = off).
    function initialize(heatTargetSec as Number, coolTargetSec as Number, tempLimit as Number, hrLimit as Number) {
        _heatTarget = heatTargetSec;
        _coolTarget = coolTargetSec;
        _tempAlarm = new ThresholdAlarm(tempLimit, 2);
        _hrAlarm = new ThresholdAlarm(hrLimit, 5);
    }

    // One recorded second. Returns a bitmask of EV_* events to alert on.
    function tick(hr as Number or Null, temp as Float or Null) as Number {
        lastHr = hr;
        lastTemp = temp;
        current.add(hr, temp);
        total.add(hr, temp);
        var ev = 0;
        var t = targetSec();
        if (t > 0 && current.seconds == t) {
            ev |= (phase == PHASE_HEAT) ? EV_HEAT_DONE : EV_COOL_DONE;
        }
        if (_tempAlarm.check(temp)) { ev |= EV_TEMP_HIGH; }
        if (_hrAlarm.check(hr)) { ev |= EV_HR_HIGH; }
        return ev;
    }

    // Lap button: close the current phase and start the other one. A phase left before its first
    // second is dropped, and the round number counts only heat phases that actually ran.
    function switchPhase() as Void {
        if (current.seconds > 0) { done.add([phase, current]); }
        current = new PhaseStats();
        if (phase == PHASE_HEAT) {
            phase = PHASE_COOL;
        } else {
            phase = PHASE_HEAT;
            round = 1;
            for (var i = 0; i < done.size(); i++) {
                if (done[i][0] == PHASE_HEAT) { round++; }
            }
        }
    }

    function targetSec() as Number {
        return phase == PHASE_HEAT ? _heatTarget : _coolTarget;
    }

    function tempHigh() as Boolean {
        return _tempAlarm.exceeded(lastTemp);
    }

    function hrHigh() as Boolean {
        return _hrAlarm.exceeded(lastHr);
    }

    // Seconds spent in heat phases so far, including the running one.
    function heatSeconds() as Number {
        var s = phase == PHASE_HEAT ? current.seconds : 0;
        for (var i = 0; i < done.size(); i++) {
            if (done[i][0] == PHASE_HEAT) { s += (done[i][1] as PhaseStats).seconds; }
        }
        return s;
    }

    // Completed heat phases plus the running one if it has started (a round counts once heated).
    function roundsDone() as Number {
        var n = 0;
        for (var i = 0; i < done.size(); i++) {
            if (done[i][0] == PHASE_HEAT) { n++; }
        }
        if (phase == PHASE_HEAT && current.seconds > 0) { n++; }
        return n;
    }

    // Rounds as History rows (see History.mc), closing the running phase into them. A cool-down
    // before the first heat phase is dropped; a session without heat yields no rows.
    function roundRows() as Array<Array<Number>> {
        var phases = done.slice(0, null);
        if (current.seconds > 0) { phases.add([phase, current]); }
        var rows = [] as Array<Array<Number>>;
        var row = null as Array<Number> or Null;
        for (var i = 0; i < phases.size(); i++) {
            var s = phases[i][1] as PhaseStats;
            if (phases[i][0] == PHASE_HEAT) {
                if (row != null) { rows.add(row); }
                row = [s.seconds, History.n(s.minHr), History.n(s.avgHr()), History.n(s.maxHr),
                       History.t10(s.maxTemp), 0, History.NONE] as Array<Number>;
            } else if (row != null) {
                row[5] = row[5] + s.seconds;
                if (row[6] == History.NONE && s.hrr60 != null) { row[6] = s.hrr60; }
            }
        }
        if (row != null) { rows.add(row); }
        return rows;
    }
}
