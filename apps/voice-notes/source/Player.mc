import Toybox.Application;
import Toybox.Audio;
import Toybox.Lang;
import Toybox.WatchUi;

// Plays one note through the speaker by streaming its stored parts in order, so memory holds one
// part at a time. Needs the AudioOutput permission and API level 6.0.3.
class NoteStream extends Audio.Output.StreamingAudioSource {
    private var _id as String;
    private var _parts as Number;
    private var _n as Number = 0;
    private var _buf as ByteArray? = null;
    private var _ended as Boolean = false;
    private var _onError as Method(error as Audio.Output.Error) as Void;

    function initialize(id as String, parts as Number, onError as Method(error as Audio.Output.Error) as Void) {
        StreamingAudioSource.initialize({:format => Recorder.format(), :bufferSize => 16384});
        _id = id;
        _parts = parts;
        _onError = onError;
    }

    // An exception here would end the app, so it is caught, stored for the next start
    // (Queue "perr") and reported as a playback error.
    function onReadyForData(freeSpace as Number) as Void {
        try {
            feed(freeSpace);
        } catch (e) {
            _ended = true;
            Application.Storage.setValue("perr", "feed: " + e.getErrorMessage() + " (part " + _n + "/" + _parts + ")");
            _onError.invoke(Audio.Output.OUTPUT_ERROR_UNKNOWN);
        }
    }

    private function feed(freeSpace as Number) as Void {
        while (freeSpace > 0 && !_ended) {
            if (_buf == null || (_buf as ByteArray).size() == 0) {
                if (_n >= _parts) {
                    end();
                    _ended = true;
                    return;
                }
                _buf = Queue.part(_id, _n);
                _n++;
                if (_buf == null) { continue; }
            }
            var b = _buf as ByteArray;
            var chunk = b.size() > freeSpace ? b.slice(0, freeSpace) : b;
            var taken = append(chunk);
            if (taken <= 0) { return; }
            _buf = b.slice(taken, null);
            freeSpace -= taken;
        }
    }

    function onError(error as Audio.Output.Error) as Void {
        _onError.invoke(error);
    }
}

class Player {
    private var _playing as String? = null;
    private var _onChange as Method() as Void;
    var error as String? = null;

    function initialize(onChange as Method() as Void) {
        _onChange = onChange;
    }

    static function supported() as Boolean {
        return (Toybox has :Audio) && (Audio has :Output);
    }

    function playingId() as String? {
        return _playing;
    }

    // The last playback error, also after a crash: set before the app died, shown on the next start.
    static function lastError() as String? {
        var e = Application.Storage.getValue("perr");
        return e instanceof String ? e : null;
    }

    private function fail(msg as String) as Void {
        error = msg;
        Application.Storage.setValue("perr", msg);
    }

    function play(note as Dictionary) as Void {
        stop();
        if (!supported()) { error = "no speaker API"; return; }
        error = null;
        // Marked before play so a crash inside it is still named on the next start.
        Application.Storage.setValue("perr", "crashed while playing");
        var id = note["id"] as String;
        try {
            Audio.Output.registerStateChangeHandler(method(:onState));
            Audio.Output.play(new NoteStream(id, note["n"] as Number, method(:onStreamError)), null);
            _playing = id;
        } catch (e) {
            fail("play: " + e.getErrorMessage());
        }
        _onChange.invoke();
    }

    function stop() as Void {
        if (_playing == null) { return; }
        Application.Storage.deleteValue("perr");
        _playing = null;
        if (supported()) { Audio.Output.stop(); }
        _onChange.invoke();
    }

    function onState(state as Audio.Output.PlaybackState) as Void {
        if (state == Audio.Output.PLAYBACK_PLAYING) {
            Application.Storage.deleteValue("perr");
        }
        if (state == Audio.Output.PLAYBACK_STOPPED || state == Audio.Output.PLAYBACK_ERROR) {
            if (state == Audio.Output.PLAYBACK_ERROR) { fail("playback error (" + Audio.Output.getError() + ")"); }
            else if (Application.Storage.getValue("perr") != null && error == null) {
                // Stopped before it ever played: no PLAYING state came.
                fail("stopped before playing (" + Audio.Output.getError() + ")");
            }
            _playing = null;
            _onChange.invoke();
        }
        WatchUi.requestUpdate();
    }

    function onStreamError(err as Audio.Output.Error) as Void {
        if (error == null) {
            fail(err == Audio.Output.OUTPUT_ERROR_DECODING ? "cannot decode note (1)" : "playback error (" + err + ")");
        }
        _playing = null;
        _onChange.invoke();
    }
}
