import Toybox.Application;
import Toybox.Audio;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// The spike's probes: format support, a 10 s Opus recording, LTE on/off, and POST uploads.
// Every result is one log line, drawn by SpikeView and echoed to System.println, which a
// sideloaded app writes to GARMIN/APPS/LOGS/VOICESPIKE.TXT when that file exists on the watch.
class Spike {
    const RECORD_MS = 10000;
    const MAX_LINES = 40;
    // Synthetic body sizes for the sweep; -1 in the queue stands for the last recording.
    const SWEEP = [4096, 16384, 65536, 131072];

    var lines as Array<String> = [];

    private var _audio as ByteArray = []b;
    private var _chunks as Number = 0;
    private var _recStart as Number = 0;
    private var _timer as Timer.Timer = new Timer.Timer();
    private var _queue as Array<Number> = [];
    private var _sentAt as Number = 0;

    function initialize() {
    }

    function log(s as String) as Void {
        System.println(s);
        lines.add(s);
        if (lines.size() > MAX_LINES) { lines = lines.slice(1, null); }
        WatchUi.requestUpdate();
    }

    private function opus() as Audio.AudioFormat {
        return {:containerFormat => Audio.CONTAINER_OGG, :codec => Audio.CODEC_OPUS,
            :frequency => Audio.FREQ_16_KHZ, :channels => Audio.CHANNEL_MONO};
    }

    private function wav() as Audio.AudioFormat {
        return {:containerFormat => Audio.CONTAINER_WAV, :codec => Audio.CODEC_LPCM,
            :frequency => Audio.FREQ_16_KHZ, :channels => Audio.CHANNEL_MONO};
    }

    // ---- status ----

    function status() as Void {
        var ds = System.getDeviceSettings();
        log("phone " + ds.phoneConnected + " mem " + (System.getSystemStats().freeMemory / 1024) + "K");
        if (!(Toybox has :Audio) || !(Audio has :Capture)) {
            log("no Audio.Capture");
        } else {
            log("opus16 " + Audio.Capture.isFormatSupported(opus()) + " wav16 " + Audio.Capture.isFormatSupported(wav()));
            log("filters " + Audio.Capture.getSupportedFilters().size());
        }
        if (Communications has :checkWifiConnection) {
            Communications.checkWifiConnection(method(:onWifiCheck));
        }
        if (Communications has :checkLteConnection) {
            Communications.checkLteConnection(method(:onLteCheck));
        } else {
            log("no checkLteConnection");
        }
    }

    function onWifiCheck(result) as Void {
        log("wifi " + result[:wifiAvailable] + " err " + result[:errorCode]);
    }

    function onLteCheck(result) as Void {
        log("lte " + result[:lteAvailable] + " err " + result[:errorCode]);
    }

    // ---- LTE ----

    function lteOn() as Void {
        if (!(Communications has :enableConnection)) { log("no enableConnection"); return; }
        Communications.enableConnection({:type => Communications.CONNECTION_TYPE_LTE,
            :updateCallback => method(:onLteUpdate)});
        log("LTE enable sent");
    }

    function lteOff() as Void {
        if (!(Communications has :disableConnection)) { return; }
        Communications.disableConnection({:type => Communications.CONNECTION_TYPE_LTE});
        log("LTE disable sent");
    }

    function onLteUpdate(info) as Void {
        log("LTE conn " + info[:connected] + " err " + info[:errorCode]);
    }

    // ---- recording (Audio.Capture.Callbacks) ----

    function record() as Void {
        if (!(Toybox has :Audio) || !(Audio has :Capture)) { log("no Audio.Capture"); return; }
        if (Audio.Capture.getState() == Audio.Capture.CAPTURE_CAPTURING) { log("already recording"); return; }
        _audio = []b;
        _chunks = 0;
        var filters = Audio.Capture.getSupportedFilters().indexOf(Audio.Capture.FILTER_NREC) >= 0
            ? [Audio.Capture.FILTER_NREC] : [];
        try {
            var s = Audio.Capture.initializeAudioCapture(self, {:format => opus(), :windowSize => 4096,
                :windowFilledBehavior => Audio.Capture.WINDOW_FILLED_CONTINUE, :filters => filters});
            log("rec init win " + s[:windowSize]);
        } catch (e) {
            log("rec init: " + e.getErrorMessage());
            return;
        }
        Audio.Capture.start();
        _recStart = System.getTimer();
        _timer.start(method(:stopRecording), RECORD_MS, false);
        log("recording 10 s ...");
    }

    function stopRecording() as Void {
        if (!(Toybox has :Audio) || !(Audio has :Capture)) { return; }
        if (Audio.Capture.getState() == Audio.Capture.CAPTURE_CAPTURING) { Audio.Capture.stop(); }
    }

    function onData(audioData as ByteArray) as Void {
        _audio.addAll(audioData);
        _chunks++;
    }

    function onError(error) as Void {
        _timer.stop();
        log("rec error " + error);
    }

    function onComplete() as Void {
        var ms = System.getTimer() - _recStart;
        var n = _audio.size();
        log("rec " + n + " B, " + _chunks + " chunks, " + ms + " ms");
        log("rate " + (ms > 0 ? n * 1000 / ms : 0) + " B/s, head " + head());
    }

    // First four bytes as text: "OggS" means the buffer starts with an Ogg page.
    private function head() as String {
        var s = "";
        for (var i = 0; i < 4 && i < _audio.size(); i++) {
            var b = _audio[i] as Number;
            s += (b >= 32 && b < 127) ? b.toChar().toString() : "?";
        }
        return s;
    }

    // ---- uploads ----

    function uploadRecording() as Void {
        if (_audio.size() == 0) { log("record first"); return; }
        _queue = [-1];
        next();
    }

    function sweep() as Void {
        _queue = [];
        for (var i = 0; i < SWEEP.size(); i++) { _queue.add(SWEEP[i] as Number); }
        next();
    }

    private function next() as Void {
        if (_queue.size() == 0) { return; }
        var size = _queue[0];
        _queue = _queue.slice(1, null);
        var body = size < 0 ? _audio : new [size]b;
        var url = Application.Properties.getValue("uploadUrl") as String;
        _sentAt = System.getTimer();
        Communications.makeWebRequest(url, null, {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => {"Content-Type" => size < 0 ? "audio/ogg" : "application/octet-stream"},
            :body => body,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_TEXT_PLAIN,
            :context => body.size()
        }, method(:onResponse));
    }

    function onResponse(code as Number, data, context) as Void {
        var kb = (context as Number) / 1024;
        log("POST " + kb + "K -> " + code + " in " + (System.getTimer() - _sentAt) + " ms");
        next();
    }
}
