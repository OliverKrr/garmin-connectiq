import Toybox.Lang;
import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.Attention;
import Toybox.FitContributor;
import Toybox.Sensor;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

const STATE_IDLE = 0;
const STATE_RUNNING = 1;
const STATE_PAUSED = 2;

// Owns one sauna session: the FIT recording, the HR/temperature sensors, the 1 s clock that
// feeds SessionModel, and the alerts. GPS is never enabled, and stop() switches the sensors
// off again, so nothing keeps draining the battery after the app exits.
class SessionController {
    var state as Number = STATE_IDLE;
    var model as SessionModel or Null = null;
    // Short banner text for the view after an alert, and when it expires (System.getTimer ms).
    var banner as String or Null = null;
    var bannerUntil as Number = 0;
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

    function initialize() {
    }

    // Sensors on from app start, so the start screen already shows HR and temperature.
    function enableSensors() as Void {
        Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE, Sensor.SENSOR_TEMPERATURE] as Array<Sensor.SensorType>);
        Sensor.enableSensorEvents(method(:onSensor));
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
        model = new SessionModel(Config.heatTargetSec(), Config.coolTargetSec(), Config.tempWarn(), Config.tempLimit(), Config.hrLimit());
        _startEpoch = Time.now().value();
        if (Config.recordActivity()) {
            // "Other" rather than Meditation: Garmin then counts calories and keeps the
            // session out of stress and breathwork statistics.
            _session = ActivityRecording.createSession({
                :name => "Sauna",
                :sport => Activity.SPORT_GENERIC,
                :subSport => Activity.SUB_SPORT_GENERIC,
            });
            createFields();
            _session.start();
        }
        state = STATE_RUNNING;
        _lastMs = System.getTimer();
        _timer = new Timer.Timer();
        _timer.start(method(:onTimer), 1000, true);
        vibe(1);
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
        } else {
            _lastMs = now;
        }
        WatchUi.requestUpdate();
    }

    // Back/lap button: close the phase as a FIT lap and start the other one.
    function lap() as Void {
        if (state != STATE_RUNNING || model == null) { return; }
        var m = model as SessionModel;
        writeLapFields(m);
        if (_session != null) { (_session as ActivityRecording.Session).addLap(); }
        m.switchPhase();
        showBanner(m.phase == PHASE_HEAT ? "Round " + m.round : "Cool down");
        vibe(1);
    }

    private function writeLapFields(m as SessionModel) as Void {
        if (_fLapRound == null) { return; }
        (_fLapRound as FitContributor.Field).setData(m.round);
        (_fLapPhase as FitContributor.Field).setData(m.phase);
        if (m.current.maxTemp != null) { (_fLapTemp as FitContributor.Field).setData(m.current.maxTemp); }
    }

    function pause() as Void {
        if (state != STATE_RUNNING) { return; }
        state = STATE_PAUSED;
        if (_session != null) { (_session as ActivityRecording.Session).stop(); }
        vibe(1);
    }

    function resume() as Void {
        if (state != STATE_PAUSED) { return; }
        if (_session != null) { (_session as ActivityRecording.Session).start(); }
        state = STATE_RUNNING;
        _lastMs = System.getTimer();
    }

    // Saves the recording and the history entry; returns the entry for the summary screen.
    function save() as Array {
        var m = model as SessionModel;
        if (_session != null) {
            var s = _session as ActivityRecording.Session;
            if (s.isRecording()) { s.stop(); }
            writeLapFields(m);
            (_fRounds as FitContributor.Field).setData(m.roundsDone());
            (_fHeat as FitContributor.Field).setData(m.heatSeconds());
            s.save();
        }
        var info = Activity.getActivityInfo();
        var e = History.entry(m, _startEpoch, info != null ? info.calories : null);
        if (m.roundsDone() > 0) { History.add(e); }
        reset();
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
        if ((ev & EV_TEMP_HIGH) != 0) {
            showBanner("Watch " + (m.lastTemp as Float).format("%.0f") + "°C - leave");
            vibe(3);
        } else if ((ev & EV_TEMP_WARN) != 0) {
            showBanner("Watch " + (m.lastTemp as Float).format("%.0f") + "°C - cover");
            vibe(2);
        } else if ((ev & EV_HR_HIGH) != 0) {
            showBanner("HR " + m.lastHr + " - high");
            vibe(3);
        } else if ((ev & EV_HEAT_DONE) != 0) {
            showBanner("Heat time up");
            vibe(2);
        } else if ((ev & EV_COOL_DONE) != 0) {
            showBanner("Rest done");
            vibe(2);
        }
    }

    function showBanner(text as String) as Void {
        banner = text;
        bannerUntil = System.getTimer() + 5000;
    }

    // `pulses` long buzzes, plus the optional tone and screen wake from settings.
    function vibe(pulses as Number) as Void {
        if (Config.alertVibrate() && Attention has :vibrate) {
            var p = [] as Array<Attention.VibeProfile>;
            for (var i = 0; i < pulses; i++) {
                p.add(new Attention.VibeProfile(100, pulses == 1 ? 300 : 600));
                p.add(new Attention.VibeProfile(0, 250));
            }
            Attention.vibrate(p);
        }
        if (pulses > 1 && Config.alertTone() && Attention has :playTone) {
            Attention.playTone(Attention.TONE_ALERT_HI);
        }
        if (pulses > 1 && Config.alertLight() && Attention has :backlight) {
            try { Attention.backlight(true); } catch (e) { }
        }
    }
}
