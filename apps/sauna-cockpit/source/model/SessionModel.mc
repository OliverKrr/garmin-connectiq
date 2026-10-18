import Toybox.Lang;

// Phase codes, also written to the FIT "phase" field.
const PHASE_HEAT = 0;
const PHASE_COOL = 1;

// Event bits returned by SessionModel.tick().
const EV_HEAT_DONE = 1;   // heat phase reached its target time
const EV_COOL_DONE = 2;   // cool-down phase reached its target time
const EV_TEMP_HIGH = 4;   // watch temperature reached the warning limit
const EV_HR_HIGH = 8;     // heart rate reached the warning limit
const EV_TEMP_WARN = 16;  // watch temperature reached the pre-warning (cover the watch)

// A sauna session: alternating heat and cool-down phases, one round per heat phase.
// Time advances only through tick() (once per recorded second), so the whole state machine
// is deterministic and unit-tested; SessionController feeds it sensor readings.
class SessionModel {
    var phase as Number = PHASE_HEAT;
    var round as Number = 1;
    var total as PhaseStats;
    var current as PhaseStats;
    // Completed phases in order, each [phaseCode, PhaseStats].
    var done as Array<Array> = [] as Array<Array>;
    var lastHr as Number or Null = null;
    var lastTemp as Float or Null = null;
    private var _heatTarget as Number;
    private var _coolTarget as Number;
    private var _tempAlarm as ThresholdAlarm;
    private var _tempWarn as ThresholdAlarm;
    private var _hrAlarm as ThresholdAlarm;
    // The phase the last switchPhase() closed, [phaseCode, PhaseStats or null when it was dropped
    // empty], until undoSwitch() reopens it or the next switch replaces it.
    private var _undo as Array or Null = null;

    // Targets in seconds (0 = no target alert); limits in °C and bpm (0 = off). The temperature
    // pre-warning fires below the limit; one at or above the limit is ignored.
    function initialize(heatTargetSec as Number, coolTargetSec as Number, tempWarn as Number, tempLimit as Number,
                        hrLimit as Number) {
        total = new PhaseStats();
        current = new PhaseStats();
        _heatTarget = 0;
        _coolTarget = 0;
        _tempWarn = new ThresholdAlarm(0, 1);
        _tempAlarm = new ThresholdAlarm(0, 2);
        _hrAlarm = new ThresholdAlarm(0, 5);
        setLimits(heatTargetSec, coolTargetSec, tempWarn, tempLimit, hrLimit);
    }

    // New targets and limits mid-session (settings changed on the watch). The alarms re-arm, so a
    // reading already over a new limit alerts on the next tick. A target already passed gives no
    // event; the phase simply shows overtime.
    function setLimits(heatTargetSec as Number, coolTargetSec as Number, tempWarn as Number, tempLimit as Number,
                       hrLimit as Number) as Void {
        _heatTarget = heatTargetSec;
        _coolTarget = coolTargetSec;
        // 1 °C re-arm: covering the watch drops the reading, and the next rise warns again.
        _tempWarn = new ThresholdAlarm((tempLimit > 0 && tempWarn >= tempLimit) ? 0 : tempWarn, 1);
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
        if (_tempWarn.check(temp)) { ev |= EV_TEMP_WARN; }
        if (_hrAlarm.check(hr)) { ev |= EV_HR_HIGH; }
        return ev;
    }

    // Beat-to-beat intervals (ms) from the HR sensor, for HRV.
    function addBeats(ivs as Array<Number>) as Void {
        current.addBeats(ivs);
        total.addBeats(ivs);
    }

    // Lap button: close the current phase and start the other one. A phase left before its first
    // second is dropped, and the round number counts only heat phases that actually ran.
    function switchPhase() as Void {
        _undo = [phase, current.seconds > 0 ? current : null];
        if (current.seconds > 0) { done.add([phase, current]); }
        current = new PhaseStats();
        phase = phase == PHASE_HEAT ? PHASE_COOL : PHASE_HEAT;
        countRound();
    }

    // Reverts the last switchPhase(): the closed phase reopens with the seconds since appended to
    // it, as if the switch never happened. Returns false when there is nothing to undo.
    function undoSwitch() as Boolean {
        if (_undo == null) { return false; }
        var u = _undo as Array;
        _undo = null;
        phase = u[0] as Number;
        if (u[1] != null) {
            var prev = u[1] as PhaseStats;
            done.remove(done[done.size() - 1]);
            prev.merge(current);
            current = prev;
        }
        countRound();
        return true;
    }

    // The round is the number of heat phases that ran before, plus one while in heat.
    private function countRound() as Void {
        var n = 0;
        for (var i = 0; i < done.size(); i++) {
            if (done[i][0] == PHASE_HEAT) { n++; }
        }
        round = phase == PHASE_HEAT ? n + 1 : (n > 0 ? n : 1);
    }

    function targetSec() as Number {
        return phase == PHASE_HEAT ? _heatTarget : _coolTarget;
    }

    function tempHigh() as Boolean {
        return _tempAlarm.exceeded(lastTemp);
    }

    function tempWarm() as Boolean {
        return _tempWarn.exceeded(lastTemp);
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
    // before the first heat phase is dropped; a session without heat yields no rows. The rest
    // columns come from the first cool-down after the heat phase; further ones only add time.
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
                       History.t10(s.maxTemp), 0, History.NONE, History.NONE, History.n(s.rmssd()),
                       History.NONE, History.NONE, History.NONE, History.NONE, History.n(s.rise())] as Array<Number>;
            } else if (row != null) {
                var r = row as Array<Number>;
                if (r[History.R_COOL] == 0) {
                    r[History.R_HRR] = History.n(s.hrr60);
                    r[History.R_CAVG] = History.n(s.avgHr());
                    r[History.R_CMIN] = History.n(s.minHr);
                    r[History.R_CHRV] = History.n(s.rmssd());
                    if (s.firstTemp != null && s.lastTemp != null) {
                        r[History.R_CDROP] = History.t10((s.firstTemp as Float) - (s.lastTemp as Float));
                    }
                }
                r[History.R_COOL] = r[History.R_COOL] + s.seconds;
            }
        }
        if (row != null) { rows.add(row); }
        return rows;
    }
}
