import Toybox.Application;
import Toybox.Lang;
import Toybox.System;

// The notes waiting for upload, in Application.Storage. Each note is a list of parts (Ogg bytes,
// at most 32 KB each, the Storage value limit) under "<id>:<n>", plus one entry in the "q" array:
// {"id", "rec" (unix s), "dur" (s), "n" (parts), "sent" (parts acknowledged)}. A recording in
// progress is "cur" ({"id", "rec", "n"}), so a note survives the app being killed mid-recording.
// Shared by the app and its background service.
(:background)
module Queue {
    const KEY = "q";
    const CURRENT = "cur";
    // Background retry interval while notes wait (the platform minimum is 5 minutes).
    const RETRY_S = 15 * 60;

    function notes() as Array<Dictionary> {
        var q = Application.Storage.getValue(KEY);
        return q == null ? ([] as Array<Dictionary>) : q as Array<Dictionary>;
    }

    function save(q as Array<Dictionary>) as Void {
        Application.Storage.setValue(KEY, q as Array<Application.PropertyValueType>);
    }

    // What the uploader was doing when it last started a request; cleared on its answer.
    function trace() as String? {
        return Application.Storage.getValue("trace") as String?;
    }

    function setTrace(s as String?) as Void {
        System.println("trace: " + s);
        if (s == null) { Application.Storage.deleteValue("trace"); } else { Application.Storage.setValue("trace", s); }
    }

    function count() as Number {
        return notes().size();
    }

    function partKey(id as String, n as Number) as String {
        return id + ":" + n;
    }

    function part(id as String, n as Number) as ByteArray? {
        return Application.Storage.getValue(partKey(id, n)) as ByteArray?;
    }

    // Recording side: begin, add parts, then finish into the queue.
    function begin(id as String, rec as Number) as Void {
        Application.Storage.setValue(CURRENT, {"id" => id, "rec" => rec, "n" => 0});
    }

    // Throws when Storage is full; the recorder stops then.
    function addPart(bytes as ByteArray) as Void {
        var cur = Application.Storage.getValue(CURRENT) as Dictionary?;
        if (cur == null) { return; }
        var n = cur["n"] as Number;
        Application.Storage.setValue(partKey(cur["id"] as String, n), bytes);
        cur["n"] = n + 1;
        Application.Storage.setValue(CURRENT, cur as Dictionary<Application.PropertyKeyType, Application.PropertyValueType>);
    }

    // Moves the recording in progress (if any) into the queue. `dur` is null when salvaging a
    // recording the app did not finish; its length is then unknown.
    function finish(dur as Number?) as Void {
        var cur = Application.Storage.getValue(CURRENT) as Dictionary?;
        if (cur == null) { return; }
        Application.Storage.deleteValue(CURRENT);
        if ((cur["n"] as Number) == 0) { return; }
        var q = notes();
        q.add({"id" => cur["id"], "rec" => cur["rec"], "dur" => dur == null ? 0 : dur,
            "n" => cur["n"], "sent" => 0});
        save(q);
    }

    function markSent(id as String, sent as Number) as Void {
        var q = notes();
        for (var i = 0; i < q.size(); i++) {
            if ((q[i]["id"] as String).equals(id)) {
                q[i]["sent"] = sent;
                save(q);
                return;
            }
        }
    }

    function remove(id as String) as Void {
        var q = notes();
        for (var i = 0; i < q.size(); i++) {
            var note = q[i];
            if ((note["id"] as String).equals(id)) {
                for (var p = 0; p < (note["n"] as Number); p++) {
                    Application.Storage.deleteValue(partKey(id, p));
                }
                q.remove(note);
                save(q);
                return;
            }
        }
    }

    function clear() as Void {
        var q = notes();
        for (var i = q.size() - 1; i >= 0; i--) { remove(q[i]["id"] as String); }
    }
}
