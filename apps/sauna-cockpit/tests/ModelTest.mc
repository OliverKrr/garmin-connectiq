import Toybox.Test;
import Toybox.Lang;

// Ticks `n` seconds at a constant HR and temperature; returns the OR of all events.
function tickN(m as SessionModel, n as Number, hr as Number or Null, temp as Float or Null) as Number {
    var ev = 0;
    for (var i = 0; i < n; i++) { ev |= m.tick(hr, temp); }
    return ev;
}

(:test)
function phaseStats_minAvgMax(logger as Test.Logger) as Boolean {
    var s = new PhaseStats();
    s.add(100, 30.0); s.add(null, null); s.add(140, 41.5); s.add(120, 39.0);
    return s.seconds == 4 && s.minHr == 100 && s.maxHr == 140 && s.avgHr() == 120 && s.maxTemp == 41.5;
}

(:test)
function phaseStats_emptyIsNull(logger as Test.Logger) as Boolean {
    var s = new PhaseStats();
    s.add(null, null);
    return s.avgHr() == null && s.minHr == null && s.maxTemp == null && s.hrr60 == null;
}

(:test)
function phaseStats_hrr60IsDropAfterOneMinute(logger as Test.Logger) as Boolean {
    var s = new PhaseStats();
    s.add(150, null);
    for (var i = 0; i < 59; i++) { s.add(140, null); }
    var before = s.hrr60;
    s.add(118, null); // second 61: one minute after the first sample
    return before == null && s.hrr60 == 32;
}

(:test)
function thresholdAlarm_firesOnceWithHysteresis(logger as Test.Logger) as Boolean {
    var a = new ThresholdAlarm(44, 2);
    var r = [a.check(43.0), a.check(44.0), a.check(44.5), a.check(42.5), a.check(44.0), a.check(41.9), a.check(44.0)];
    return r[0] == false && r[1] == true && r[2] == false && r[3] == false && r[4] == false && r[5] == false && r[6] == true;
}

(:test)
function thresholdAlarm_zeroIsOff(logger as Test.Logger) as Boolean {
    var a = new ThresholdAlarm(0, 2);
    return !a.check(99.0) && !a.exceeded(99.0);
}

(:test)
function session_heatTargetFiresOnceAtTarget(logger as Test.Logger) as Boolean {
    var m = new SessionModel(10, 0, 0, 0, 0);
    var early = tickN(m, 9, 120, null);
    var at = m.tick(120, null);
    var later = tickN(m, 5, 120, null);
    return early == 0 && at == EV_HEAT_DONE && later == 0;
}

(:test)
function session_switchPhaseCountsRounds(logger as Test.Logger) as Boolean {
    var m = new SessionModel(0, 0, 0, 0, 0);
    tickN(m, 5, 120, null);
    m.switchPhase();               // -> cool, round 1
    var coolOk = m.phase == PHASE_COOL && m.round == 1 && m.current.seconds == 0;
    tickN(m, 3, 90, null);
    m.switchPhase();               // -> heat, round 2
    tickN(m, 4, 130, null);
    return coolOk && m.phase == PHASE_HEAT && m.round == 2 && m.roundsDone() == 2 && m.heatSeconds() == 9 && m.total.seconds == 12;
}

(:test)
function session_coolTargetUsesCoolEvent(logger as Test.Logger) as Boolean {
    var m = new SessionModel(0, 3, 0, 0, 0);
    tickN(m, 2, 120, null);
    m.switchPhase();
    return tickN(m, 3, 90, null) == EV_COOL_DONE;
}

(:test)
function session_tempAndHrAlarms(logger as Test.Logger) as Boolean {
    var m = new SessionModel(0, 0, 0, 44, 160);
    var ev = m.tick(165, 44.2);
    return (ev & EV_TEMP_HIGH) != 0 && (ev & EV_HR_HIGH) != 0 && m.tempHigh() && m.hrHigh();
}

(:test)
function session_tempWarnBeforeLimit(logger as Test.Logger) as Boolean {
    var m = new SessionModel(0, 0, 42, 44, 0);
    var a = m.tick(120, 42.1);     // pre-warning
    var b = m.tick(120, 42.5);     // latched
    var c = m.tick(120, 40.9);     // covered: re-arms below 41
    var d = m.tick(120, 42.0);     // warns again
    var e = m.tick(120, 44.0);     // limit
    return a == EV_TEMP_WARN && b == 0 && c == 0 && d == EV_TEMP_WARN && e == EV_TEMP_HIGH && m.tempWarm() && m.tempHigh();
}

(:test)
function session_tempWarnAtOrAboveLimitIsIgnored(logger as Test.Logger) as Boolean {
    var m = new SessionModel(0, 0, 44, 44, 0);
    return m.tick(120, 44.5) == EV_TEMP_HIGH;
}

(:test)
function session_roundRowsPairHeatWithCool(logger as Test.Logger) as Boolean {
    var m = new SessionModel(0, 0, 0, 0, 0);
    tickN(m, 10, 140, 40.0);
    m.switchPhase();
    m.tick(150, 41.0);
    tickN(m, 60, 110, 38.0);       // HRR60 = 150 - 110
    m.switchPhase();
    tickN(m, 7, 130, 42.0);        // running heat phase becomes round 2
    var rows = m.roundRows();
    var r0 = rows[0];
    var r1 = rows[1];
    return rows.size() == 2
        && r0[History.R_HEAT] == 10 && r0[History.R_AVG] == 140 && r0[History.R_TEMP] == 400
        && r0[History.R_COOL] == 61 && r0[History.R_HRR] == 40
        && r1[History.R_HEAT] == 7 && r1[History.R_COOL] == 0 && r1[History.R_HRR] == History.NONE;
}

(:test)
function session_coolBeforeHeatIsDropped(logger as Test.Logger) as Boolean {
    var m = new SessionModel(0, 0, 0, 0, 0);
    m.switchPhase();               // straight to cool: the empty heat phase is dropped
    tickN(m, 5, 100, null);
    m.switchPhase();               // back to heat, still round 1
    tickN(m, 5, 120, null);
    var rows = m.roundRows();
    return m.round == 1 && rows.size() == 1 && rows[0][History.R_HEAT] == 5;
}

(:test)
function history_prependCapsAndOrders(logger as Test.Logger) as Boolean {
    var list = [] as Array<Array>;
    for (var i = 0; i < History.MAX_SESSIONS + 5; i++) {
        list = History.prepend(list, [i, 0, 0, 0, 0, 0, []]);
    }
    return list.size() == History.MAX_SESSIONS && list[0][0] == History.MAX_SESSIONS + 4;
}

(:test)
function history_totalsSince(logger as Test.Logger) as Boolean {
    var list = [
        [1000, 0, 0, 0, 0, 0, [[600, 0, 0, 0, 0, 0, 0], [540, 0, 0, 0, 0, 0, 0]]],
        [500, 0, 0, 0, 0, 0, [[700, 0, 0, 0, 0, 0, 0]]],
    ] as Array<Array>;
    var t = History.totalsSince(list, 900);
    return t[0] == 1 && t[1] == 2 && t[2] == 1140;
}

(:test)
function history_entryFromModel(logger as Test.Logger) as Boolean {
    var m = new SessionModel(0, 0, 0, 0, 0);
    tickN(m, 3, 120, 36.0);
    var e = History.entry(m, 1234, null);
    return e[History.S_START] == 1234 && e[History.S_TOTAL] == 3 && e[History.S_AVG] == 120
        && e[History.S_TEMP] == 360 && (e[History.S_ROUNDS] as Array).size() == 1 && e[History.S_KCAL] == History.NONE;
}

(:test)
function fmt_clockAndValues(logger as Test.Logger) as Boolean {
    return Fmt.clock(75).equals("1:15") && Fmt.clock(3725).equals("1:02:05") && Fmt.clock(-5).equals("0:00")
        && Fmt.minutes(754).equals("13'") && Fmt.num(History.NONE).equals("--") && Fmt.num(-12).equals("-12")
        && Fmt.temp10(446).equals("45°") && Fmt.temp10(History.NONE).equals("--");
}
