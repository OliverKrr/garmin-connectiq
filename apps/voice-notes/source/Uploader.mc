import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;

// Uploads the queue part by part, oldest note first. Each part is one POST to
// <uploadUrl>/<id>/parts/<n>; the server answers {"complete": true} once it holds the whole note,
// and only then does the note leave the watch, so any failure just leaves it for the next run.
// Goes through the phone when one is connected, else over LTE when the setting allows it.
// Shared by the app and its background service.
(:background)
class Uploader {
    private var _onDone as Method(status as String) as Void;
    private var _onProgress as Method() as Void or Null;
    private var _lte as Boolean = false;
    private var _busy as Boolean = false;

    function initialize(onDone as Method(status as String) as Void, onProgress as Method() as Void or Null) {
        _onDone = onDone;
        _onProgress = onProgress;
    }

    function isBusy() as Boolean {
        return _busy;
    }

    function start() as Void {
        startVia(false);
    }

    // forceLte skips the phone even when one is connected (debug builds use it in the simulator).
    function startVia(forceLte as Boolean) as Void {
        if (_busy) { return; }
        if (Queue.count() == 0) { _onDone.invoke("nothing to upload"); return; }
        var url = Application.Properties.getValue("uploadUrl") as String?;
        var token = Application.Properties.getValue("uploadToken") as String?;
        if (url == null || url.length() == 0 || token == null || token.length() == 0) {
            _onDone.invoke("set URL and token in settings");
            return;
        }
        _busy = true;
        if (!forceLte && System.getDeviceSettings().phoneConnected) {
            next();
        } else if ((Application.Properties.getValue("useLte") as Boolean) && (Communications has :enableConnection)) {
            _lte = true;
            Queue.setTrace("switching LTE on");
            try {
                Communications.enableConnection({:type => Communications.CONNECTION_TYPE_LTE,
                    :updateCallback => method(:onLte)});
            } catch (e) {
                Queue.setTrace(null);
                finish("LTE error: " + e.getErrorMessage());
            }
        } else {
            finish("no phone");
        }
    }

    function onLte(info as {:type as Communications.ConnectionType, :connected as Boolean,
            :errorCode as Communications.LteConnectionStatus or Null}) as Void {
        Queue.setTrace(null);
        if (!_busy) { return; }
        if (info[:connected]) {
            next();
        } else {
            finish("no phone, no LTE (" + info[:errorCode] + ")");
        }
    }

    private function next() as Void {
        var q = Queue.notes();
        if (q.size() == 0) { finish("all uploaded"); return; }
        var note = q[0];
        var id = note["id"] as String;
        var total = note["n"] as Number;
        var sent = note["sent"] as Number;
        var n = sent < total ? sent : total - 1;
        var body = Queue.part(id, n);
        if (body == null) {
            // Parts lost (Storage cleared): nothing left to send for this note.
            Queue.remove(id);
            next();
            return;
        }
        var url = clean(Application.Properties.getValue("uploadUrl") as String) + "/" + id + "/parts/" + n;
        // A trace survives a crash inside the request, so the next start can say where it died
        // instead of crashing again on the same note (see Queue.trace).
        Queue.setTrace("POST part " + (n + 1) + "/" + total + ", " + (body.size() / 1024) + " KB");
        try {
            Communications.makeWebRequest(url,
                // Strings only: with a non-JSON body, Connect IQ throws on any other value type.
                {"total" => total.toString(), "recorded" => (note["rec"] as Number).toString(),
                    "duration" => (note["dur"] as Number).toString()}, {
                    :method => Communications.HTTP_REQUEST_METHOD_POST,
                    :headers => {
                        "Authorization" => "Bearer " + clean(Application.Properties.getValue("uploadToken") as String),
                        "Content-Type" => "application/octet-stream"},
                    :body => body,
                    :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
                    :context => {"id" => id, "n" => n}
                }, method(:onResponse));
        } catch (e) {
            Queue.setTrace(null);
            finish("send error: " + e.getErrorMessage());
        }
    }

    // Settings pasted on a phone can carry spaces or line breaks.
    private function clean(s as String) as String {
        var out = "";
        var chars = s.toCharArray();
        for (var i = 0; i < chars.size(); i++) {
            var c = chars[i];
            if (c != ' ' && c != '\n' && c != '\r' && c != '\t') { out += c.toString(); }
        }
        return out;
    }

    function onResponse(code as Number, data as Dictionary or String or ByteArray or Null, context as Object) as Void {
        Queue.setTrace(null);
        var ctx = context as Dictionary;
        var id = ctx["id"] as String;
        if (code != 200 || !(data instanceof Dictionary)) {
            finish(code == 401 ? "token rejected" : "upload failed (" + code + ")");
            return;
        }
        if (data["complete"] == true) {
            Queue.remove(id);
        } else {
            Queue.markSent(id, (ctx["n"] as Number) + 1);
        }
        if (_onProgress != null) { _onProgress.invoke(); }
        next();
    }

    private function finish(status as String) as Void {
        if (_lte) {
            Communications.disableConnection({:type => Communications.CONNECTION_TYPE_LTE});
            _lte = false;
        }
        _busy = false;
        _onDone.invoke(status);
    }
}
