import Toybox.Lang;
import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.Attention;
import Toybox.FitContributor;
import Toybox.Math;
import Toybox.Sensor;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

const STATE_IDLE = 0;
const STATE_RUNNING = 1;
const STATE_PAUSED = 2;

// A phase switch stays undoable this long; its FIT lap is written only once the window closes.
const UNDO_MS = 3000;
// A button press or an alert shows a dimmed or dark screen at full brightness this long.
const WAKE_MS = 10000;

// Vibration patterns, each with its own feel so the wrist tells them apart without looking:
// a short tap acknowledges a button, three quick taps mean a phase timer ran out, two long buzzes
// are the temperature pre-warning, and a long-short-long buzz is an alarm (leave, or HR).
const VIBE_ACK = 0;
const VIBE_TIMER = 1;
const VIBE_WARN = 2;
const VIBE_ALARM = 3;

// Owns one sauna session: the FIT recording, the HR/temperature sensors, the 1 s clock that
// feeds SessionModel, and the alerts. GPS is never enabled, and stop() switches the sensors
// off again, so nothing keeps draining the battery after the app exits.
class SessionController {
    var state as Number = STATE_IDLE;
    var model as SessionModel or Null = null;
    // Short banner text for the view after an alert, and when it expires (System.getTimer ms).
    var banner as String or Null = null;
    // The entry the last Save produced, until SessionView.onShow hands it to the summary screen.
    var lastEntry as Array or Null = null;
    var bannerUntil as Number = 0;
    // Until when (System.getTimer ms) a dimmed or dark session screen shows at full brightness.
    var wakeUntil as Number = 0;
    // The phase the last switch closed, [phaseCode, round, PhaseStats], until its FIT lap is
    // written at undoUntil, or the switch is undone.
    private var _pendingLap as Array or Null = null;
    private var _undoUntil as Number = 0;
    private var _session as ActivityRecording.Session or Null = null;
    private var _timer as Timer.Timer or Null = null;
    private var _lastMs as Number = 0;
    private var _startEpoch as Number = 0;
    private var _hr as Number or Null = null;
    private var _temp as Float or Null = null;
    private var _fPhase as FitContributor.Field or Null = null;
    private var _fTemp as FitContributor.Field or Null = null;
    private var _fLapRound as FitContributor.Field or Null = null;
    private var _fLapPhase as FitContributor.Field or Null = null;
    private var _fLapTemp as FitContributor.Field or Null = null;
    private var _fRounds as FitContributor.Field or Null = null;
    private var _fHeat as FitContributor.Field or Null = null;
    private var _fLapRise as FitContributor.Field or Null = null;
    private var _fLapHrr as FitContributor.Field or Null = null;
    private var _fLapHrv as FitContributor.Field or Null = null;
    private var _fBb0 as FitContributor.Field or Null = null;
    private var _fBb1 as FitContributor.Field or Null = null;
    private var _fStress0 as FitContributor.Field or Null = null;
    private var _fStress1 as FitContributor.Field or Null = null;
    // Body Battery and stress when the session started (null when the watch has none).
    private var _bb0 as Number or Null = null;
    private var _stress0 as Number or Null = null;

    function initialize() {
    }

    // Sensors on from app start, so the start screen already shows HR and temperature.
    function enableSensors() as Void {
        Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE, Sensor.SENSOR_TEMPERATURE] as Array<Sensor.SensorType>);
        Sensor.enableSensorEvents(method(:onSensor));
    }

    // Beat-to-beat intervals for HRV, only while a session runs: the listener keeps the optical
    // sensor in its high-rate mode, which costs battery.
    private function enableBeats(on as Boolean) as Void {
        if (!(Sensor has :registerSensorDataListener)) { return; }
        if (on) {
            try {
                Sensor.registerSensorDataListener(method(:onSensorData), {
                    :period => 1,
                    :heartBeatIntervals => {:enabled => true},
                });
            } catch (e) { }
        } else {
            Sensor.unregisterSensorDataListener();
        }
    }

    function onSensorData(data as Sensor.SensorData) as Void {
        var hd = data.heartRateData;
        if (state == STATE_RUNNING && model != null && hd != null && hd.heartBeatIntervals != null) {
            (model as SessionModel).addBeats(hd.heartBeatIntervals as Array<Number>);
        }
    }

    // Newest valid Body Battery and stress samples taken at or after `notBefore` (epoch seconds),
    // rounded; null when there is none or the watch does not offer them.
    function bodyBattery(notBefore as Number) as Number or Null {
        if (!(Toybox has :SensorHistory) || !(SensorHistory has :getBodyBatteryHistory)) { return null; }
        return newest(SensorHistory.getBodyBatteryHistory({:order => SensorHistory.ORDER_NEWEST_FIRST}), notBefore);
    }

    function stress(notBefore as Number) as Number or Null {
        if (!(Toybox has :SensorHistory) || !(SensorHistory has :getStressHistory)) { return null; }
        return newest(SensorHistory.getStressHistory({:order => SensorHistory.ORDER_NEWEST_FIRST}), notBefore);
    }

    // The newest sample often carries no value (stress is not measured while the wrist moves or
    // during an activity), so walk back to the first one that does, but no further than notBefore.
    private function newest(it as SensorHistory.SensorHistoryIterator or Null, notBefore as Number) as Number or Null {
        if (it == null) { return null; }
        for (var s = it.next(); s != null; s = it.next()) {
            if (s.when != null && (s.when as Time.Moment).value() < notBefore) { return null; }
            if (s.data != null) { return Math.round(s.data as Numeric).toNumber(); }
        }
        return null;
    }

    function onSensor(info as Sensor.Info) as Void {
        _hr = info.heartRate;
        _temp = info.temperature;
        if (_temp == null) { _temp = historyTemp(); }
        if (state == STATE_IDLE) { WatchUi.requestUpdate(); }
    }

    function hr() as Number or Null { return _hr; }
    function temp() as Float or Null { return _temp; }

    // Newest internal-sensor sample, for devices whose Sensor.Info carries no temperature.
    function historyTemp() as Float or Null {
        if (!(Toybox has :SensorHistory) || !(SensorHistory has :getTemperatureHistory)) { return null; }
        var it = SensorHistory.getTemperatureHistory({:period => 1});
        var s = it != null ? it.next() : null;
        return (s != null && s.data != null) ? (s.data as Numeric).toFloat() : null;
    }

    function start() as Void {
        model = new SessionModel(Config.heatTargetSec(), Config.coolTargetSec(), Config.tempWarn(), Config.tempLimit(),
            Config.hrLimit());
        _startEpoch = Time.now().value();
        // Values up to 30 min old still describe the state before the session.
        _bb0 = bodyBattery(_startEpoch - 1800);
        _stress0 = stress(_startEpoch - 1800);
        if (Config.recordActivity()) {
            // "Other" by default: Garmin counts calories and keeps the session out of stress and
            // meditation statistics. "Meditation" keeps the stress measurement running instead.
            _session = ActivityRecording.createSession({
                :name => "Sauna",
                :sport => Config.recordAsMeditation() ? Activity.SPORT_MEDITATION : Activity.SPORT_GENERIC,
                :subSport => Activity.SUB_SPORT_GENERIC,
            });
            createFields();
            _session.start();
        }
        state = STATE_RUNNING;
        _lastMs = System.getTimer();
        _timer = new Timer.Timer();
        _timer.start(method(:onTimer), 1000, true);
        enableBeats(true);
        wake();
        vibe(VIBE_ACK);
    }

    // Settings changed on the watch: the running session takes the new targets and limits.
    function applySettings() as Void {
        if (model != null) {
            (model as SessionModel).setLimits(Config.heatTargetSec(), Config.coolTargetSec(), Config.tempWarn(),
                Config.tempLimit(), Config.hrLimit());
        }
    }

    private function createFields() as Void {
        var s = _session as ActivityRecording.Session;
        _fPhase = s.createField("phase", 0, FitContributor.DATA_TYPE_UINT8, {:mesgType => FitContributor.MESG_TYPE_RECORD});
        _fTemp = s.createField("watch_temp", 1, FitContributor.DATA_TYPE_FLOAT, {:mesgType => FitContributor.MESG_TYPE_RECORD, :units => "C"});
        _fLapRound = s.createField("round", 2, FitContributor.DATA_TYPE_UINT8, {:mesgType => FitContributor.MESG_TYPE_LAP});
        _fLapPhase = s.createField("lap_phase", 3, FitContributor.DATA_TYPE_UINT8, {:mesgType => FitContributor.MESG_TYPE_LAP});
        _fLapTemp = s.createField("lap_max_temp", 4, FitContributor.DATA_TYPE_FLOAT, {:mesgType => FitContributor.MESG_TYPE_LAP, :units => "C"});
        _fRounds = s.createField("rounds", 5, FitContributor.DATA_TYPE_UINT8, {:mesgType => FitContributor.MESG_TYPE_SESSION});
        _fHeat = s.createField("heat_time", 6, FitContributor.DATA_TYPE_UINT32, {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => "s"});
        // Field 7 (lap_effect_time, 0.1.x) is retired; its id is not reused.
        _fLapRise = s.createField("lap_hr_rise", 13, FitContributor.DATA_TYPE_SINT16, {:mesgType => FitContributor.MESG_TYPE_LAP, :units => "bpm"});
        _fLapHrr = s.createField("lap_hrr60", 14, FitContributor.DATA_TYPE_SINT16, {:mesgType => FitContributor.MESG_TYPE_LAP, :units => "bpm"});
        _fLapHrv = s.createField("lap_rmssd", 8, FitContributor.DATA_TYPE_UINT16, {:mesgType => FitContributor.MESG_TYPE_LAP, :units => "ms"});
        _fBb0 = s.createField("body_battery_start", 9, FitContributor.DATA_TYPE_UINT8, {:mesgType => FitContributor.MESG_TYPE_SESSION});
        _fBb1 = s.createField("body_battery_end", 10, FitContributor.DATA_TYPE_UINT8, {:mesgType => FitContributor.MESG_TYPE_SESSION});
        _fStress0 = s.createField("stress_start", 11, FitContributor.DATA_TYPE_UINT8, {:mesgType => FitContributor.MESG_TYPE_SESSION});
        _fStress1 = s.createField("stress_end", 12, FitContributor.DATA_TYPE_UINT8, {:mesgType => FitContributor.MESG_TYPE_SESSION});
    }

    // Timer callbacks can arrive late; advance the model by every whole second that passed.
    function onTimer() as Void {
        var now = System.getTimer();
        if (state == STATE_RUNNING && model != null) {
            var ev = 0;
            while (now - _lastMs >= 1000) {
                _lastMs += 1000;
                ev |= (model as SessionModel).tick(_hr, _temp);
            }
            if (_fPhase != null) {
                (_fPhase as FitContributor.Field).setData((model as SessionModel).phase);
                if (_temp != null) { (_fTemp as FitContributor.Field).setData(_temp); }
            }
            if (ev != 0) { alert(ev); }
            if (_pendingLap != null && now >= _undoUntil) { commitLap(); }
        } else {
            _lastMs = now;
        }
        WatchUi.requestUpdate();
    }

    // Back/lap button: switch to the other phase. Pressed again within UNDO_MS it undoes the
    // switch instead (a mistaken or double press). The FIT lap waits until the window closes, so
    // an undone switch leaves no trace in the recording; the lap boundary lands up to
    // UNDO_MS late, while the on-watch tables use the exact switch time.
    function lap() as Void {
        if (state != STATE_RUNNING || model == null) { return; }
        var m = model as SessionModel;
        wake();
        if (canUndo()) {
            m.undoSwitch();
            _pendingLap = null;
            showBanner((m.phase == PHASE_HEAT ? "Heat R" : "Cool R") + m.round + " again", null, 3000);
            vibe(VIBE_ACK);
            return;
        }
        commitLap();
        _pendingLap = [m.phase, m.round, m.current];
        _undoUntil = System.getTimer() + UNDO_MS;
        m.switchPhase();
        showBanner(m.phase == PHASE_HEAT ? "Round " + m.round : "Cool down", "BACK again: undo", UNDO_MS);
        vibe(VIBE_ACK);
    }

    function canUndo() as Boolean {
        return _pendingLap != null && System.getTimer() < _undoUntil;
    }

    // Writes the pending phase switch to the FIT file as a lap. A phase dropped before its first
    // second gets no lap.
    private function commitLap() as Void {
        var p = _pendingLap;
        _pendingLap = null;
        if (p == null || _session == null) { return; }
        var s = p[2] as PhaseStats;
        if (s.seconds == 0) { return; }
        writeLapFields(p[0] as Number, p[1] as Number, s);
        (_session as ActivityRecording.Session).addLap();
    }

    private function writeLapFields(phase as Number, round as Number, s as PhaseStats) as Void {
        if (_fLapRound == null) { return; }
        (_fLapRound as FitContributor.Field).setData(round);
        (_fLapPhase as FitContributor.Field).setData(phase);
        if (s.maxTemp != null) { (_fLapTemp as FitContributor.Field).setData(s.maxTemp); }
        var hrv = s.rmssd();
        if (hrv != null) { (_fLapHrv as FitContributor.Field).setData(hrv); }
        var v = phase == PHASE_HEAT ? s.rise() : s.hrr60;
        if (v != null) { ((phase == PHASE_HEAT ? _fLapRise : _fLapHrr) as FitContributor.Field).setData(v); }
    }

    function pause() as Void {
        if (state != STATE_RUNNING) { return; }
        commitLap();
        state = STATE_PAUSED;
        if (_session != null) { (_session as ActivityRecording.Session).stop(); }
        wake();
        vibe(VIBE_ACK);
    }

    function resume() as Void {
        if (state != STATE_PAUSED) { return; }
        if (_session != null) { (_session as ActivityRecording.Session).start(); }
        state = STATE_RUNNING;
        _lastMs = System.getTimer();
        wake();
    }

    // Saves the recording and the history entry; returns the entry for the summary screen.
    function save() as Array {
        var m = model as SessionModel;
        commitLap();
        // Only samples taken during the session count: Body Battery and (in an "Other" recording)
        // stress pause while recording, and an older sample would read as "no change".
        var bb1 = bodyBattery(_startEpoch);
        var stress1 = Config.recordAsMeditation() ? stress(_startEpoch) : null;
        if (_session != null) {
            var s = _session as ActivityRecording.Session;
            if (s.isRecording()) { s.stop(); }
            writeLapFields(m.phase, m.round, m.current);
            (_fRounds as FitContributor.Field).setData(m.roundsDone());
            (_fHeat as FitContributor.Field).setData(m.heatSeconds());
            if (_bb0 != null) { (_fBb0 as FitContributor.Field).setData(_bb0); }
            if (bb1 != null) { (_fBb1 as FitContributor.Field).setData(bb1); }
            if (_stress0 != null) { (_fStress0 as FitContributor.Field).setData(_stress0); }
            if (stress1 != null) { (_fStress1 as FitContributor.Field).setData(stress1); }
            s.save();
        }
        var info = Activity.getActivityInfo();
        var e = History.entry(m, _startEpoch, [info != null ? info.calories : null, _bb0, bb1, _stress0, stress1]);
        if (m.roundsDone() > 0) { History.add(e); }
        reset();
        lastEntry = e;
        return e;
    }

    function discard() as Void {
        if (_session != null) {
            var s = _session as ActivityRecording.Session;
            if (s.isRecording()) { s.stop(); }
            s.discard();
        }
        reset();
    }

    private function reset() as Void {
        _pendingLap = null;
        enableBeats(false);
        if (_timer != null) { (_timer as Timer.Timer).stop(); }
        _timer = null;
        _session = null;
        _fPhase = null;
        model = null;
        state = STATE_IDLE;
    }

    // App exit: a running session is saved rather than lost (the back button exits only when idle,
    // but the system can still close the app), and the sensors are released.
    function shutdown() as Void {
        if (state != STATE_IDLE) { save(); }
        Sensor.enableSensorEvents(null);
        Sensor.setEnabledSensors([] as Array<Sensor.SensorType>);
    }

    function alert(ev as Number) as Void {
        var m = model as SessionModel;
        wake();
        if ((ev & EV_TEMP_HIGH) != 0) {
            showBanner("Watch " + (m.lastTemp as Float).format("%.0f") + "°C - leave", null, 5000);
            vibe(VIBE_ALARM);
        } else if ((ev & EV_TEMP_WARN) != 0) {
            showBanner("Watch " + (m.lastTemp as Float).format("%.0f") + "°C - cover", null, 5000);
            vibe(VIBE_WARN);
        } else if ((ev & EV_HR_HIGH) != 0) {
            showBanner("HR " + m.lastHr + " - high", null, 5000);
            vibe(VIBE_ALARM);
        } else if ((ev & EV_HEAT_DONE) != 0) {
            showBanner("Heat time up", null, 5000);
            vibe(VIBE_TIMER);
        } else if ((ev & EV_COOL_DONE) != 0) {
            showBanner("Rest done", null, 5000);
            vibe(VIBE_TIMER);
        }
    }

    // A banner across the middle of the session screen, with an optional smaller line below.
    var bannerSub as String or Null = null;

    function showBanner(text as String, sub as String or Null, ms as Number) as Void {
        banner = text;
        bannerSub = sub;
        bannerUntil = System.getTimer() + ms;
    }

    // Full brightness for WAKE_MS (see Config.heatScreen).
    function wake() as Void {
        wakeUntil = System.getTimer() + WAKE_MS;
    }

    function awake() as Boolean {
        return System.getTimer() < wakeUntil;
    }

    // One of the VIBE_* patterns, plus the optional tone and screen light from settings for
    // everything but the acknowledgement tap.
    function vibe(kind as Number) as Void {
        if (Config.alertVibrate() && Attention has :vibrate) {
            Attention.vibrate(vibeProfile(kind));
        }
        if (kind == VIBE_ACK) { return; }
        if (Config.alertTone() && Attention has :playTone) {
            Attention.playTone(kind == VIBE_TIMER ? Attention.TONE_INTERVAL_ALERT
                : (kind == VIBE_WARN ? Attention.TONE_ALERT_LO : Attention.TONE_ALERT_HI));
        }
        if (Config.alertLight() && Attention has :backlight) {
            try { Attention.backlight(true); } catch (e) { }
        }
    }

    // [on ms, off ms] pairs at full strength.
    private function vibeProfile(kind as Number) as Array<Attention.VibeProfile> {
        var ms = kind == VIBE_ACK ? [200]
            : (kind == VIBE_TIMER ? [120, 150, 120, 150, 120]
            : (kind == VIBE_WARN ? [700, 300, 700] : [900, 200, 300, 200, 900]));
        var p = [] as Array<Attention.VibeProfile>;
        for (var i = 0; i < ms.size(); i++) {
            p.add(new Attention.VibeProfile(i % 2 == 0 ? 100 : 0, ms[i] as Number));
        }
        return p;
    }
}
