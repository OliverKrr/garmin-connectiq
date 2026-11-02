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

    function onReadyForData(freeSpace as Number) as Void {
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

    function play(note as Dictionary) as Void {
        stop();
        if (!supported()) { error = "no speaker API"; return; }
        error = null;
        var id = note["id"] as String;
        try {
            Audio.Output.registerStateChangeHandler(method(:onState));
            Audio.Output.play(new NoteStream(id, note["n"] as Number, method(:onStreamError)), null);
            _playing = id;
        } catch (e) {
            error = "play: " + e.getErrorMessage();
        }
        _onChange.invoke();
    }

    function stop() as Void {
        if (_playing == null) { return; }
        _playing = null;
        if (supported()) { Audio.Output.stop(); }
        _onChange.invoke();
    }

    function onState(state as Audio.Output.PlaybackState) as Void {
        if (state == Audio.Output.PLAYBACK_STOPPED || state == Audio.Output.PLAYBACK_ERROR) {
            if (state == Audio.Output.PLAYBACK_ERROR) { error = "playback error"; }
            _playing = null;
            _onChange.invoke();
        }
        WatchUi.requestUpdate();
    }

    function onStreamError(err as Audio.Output.Error) as Void {
        error = err == Audio.Output.OUTPUT_ERROR_DECODING ? "cannot decode note" : "playback error";
        _playing = null;
        _onChange.invoke();
    }
}
