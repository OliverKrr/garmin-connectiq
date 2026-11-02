import Toybox.Application;
import Toybox.Audio;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

// Records one note as Ogg Opus 16 kHz mono and writes it to the Queue in parts of the
// `partKb` setting while recording, so memory holds at most one part.
class Recorder {
    private var _buf as ByteArray = []b;
    private var _partBytes as Number = 16384;
    private var _startedAt as Number = 0;
    private var _recording as Boolean = false;
    private var _timer as Timer.Timer = new Timer.Timer();
    private var _onFinished as Method(error as String?) as Void;
    private var _error as String? = null;

    function initialize(onFinished as Method(error as String?) as Void) {
        _onFinished = onFinished;
    }

    static function supported() as Boolean {
        return (Toybox has :Audio) && (Audio has :Capture) && Audio.Capture.isFormatSupported(format());
    }

    static function format() as Audio.AudioFormat {
        return {:containerFormat => Audio.CONTAINER_OGG, :codec => Audio.CODEC_OPUS,
            :frequency => Audio.FREQ_16_KHZ, :channels => Audio.CHANNEL_MONO};
    }

    function isRecording() as Boolean {
        return _recording;
    }

    function elapsedS() as Number {
        return _recording ? (System.getTimer() - _startedAt) / 1000 : 0;
    }

    function start() as String? {
        if (_recording) { return null; }
        if (!supported()) { return "no Opus recording"; }
        var kb = Application.Properties.getValue("partKb") as Number;
        _partBytes = (kb < 1 ? 1 : kb > 32 ? 32 : kb) * 1024 - 64;
        _buf = []b;
        _error = null;
        var filters = Audio.Capture.getSupportedFilters().indexOf(Audio.Capture.FILTER_NREC) >= 0
            ? [Audio.Capture.FILTER_NREC] : [];
        try {
            Audio.Capture.initializeAudioCapture(self, {:format => format(), :windowSize => 4096,
                :windowFilledBehavior => Audio.Capture.WINDOW_FILLED_CONTINUE,
                :filters => filters as Array<Audio.Capture.Filter>});
        } catch (e) {
            return "mic: " + e.getErrorMessage();
        }
        var now = Time.now().value();
        Queue.begin(now.format("%d") + "-" + (Math.rand() % 100000).format("%05d"), now);
        Audio.Capture.start();
        _startedAt = System.getTimer();
        _recording = true;
        var maxMin = Application.Properties.getValue("maxMin") as Number;
        _timer.start(method(:stop), (maxMin < 1 ? 1 : maxMin) * 60000, false);
        return null;
    }

    function stop() as Void {
        _timer.stop();
        if (Audio.Capture.getState() == Audio.Capture.CAPTURE_CAPTURING) {
            Audio.Capture.stop();  // flushes the rest through onData, then onComplete
        } else {
            complete();
        }
    }

    // App exit while recording: keep what has arrived, without waiting for onComplete.
    function abort() as Void {
        if (!_recording) { return; }
        _timer.stop();
        if (Audio.Capture.getState() == Audio.Capture.CAPTURE_CAPTURING) { Audio.Capture.stop(); }
        complete();
    }

    // ---- Audio.Capture.Callbacks ----

    function onData(audioData as ByteArray) as Void {
        if (!_recording) { return; }
        _buf.addAll(audioData);
        while (_buf.size() >= _partBytes && _error == null) {
            flush(_buf.slice(0, _partBytes));
            _buf = _buf.slice(_partBytes, null);
        }
    }

    function onError(error as Audio.Capture.Error) as Void {
        _error = "mic error " + error;
        complete();
    }

    function onComplete() as Void {
        complete();
    }

    private function flush(bytes as ByteArray) as Void {
        try {
            Queue.addPart(bytes);
        } catch (e) {
            _error = "watch storage full";
            stop();
        }
    }

    private function complete() as Void {
        if (!_recording) { return; }
        if (_buf.size() > 0 && _error == null) { flush(_buf); }
        _buf = []b;
        _recording = false;
        Queue.finish((System.getTimer() - _startedAt) / 1000);
        _onFinished.invoke(_error);
    }
}
