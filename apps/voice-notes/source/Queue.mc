import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

// The notes on the watch, in Application.Storage. Each note is a list of parts (Ogg bytes, at most
// 32 KB each, the Storage value limit) under "<id>:<n>", plus one entry in the "q" array, oldest
// first: {"id", "rec" (unix s), "dur" (s), "n" (parts), "sent" (parts acknowledged), "kb" (size),
// "up" (uploaded)}. Uploaded notes stay for playback until prune() removes them; waiting notes are
// never removed automatically. A recording in progress is "cur" ({"id", "rec", "n", "b"}), so a note
// survives the app being killed mid-recording. Shared by the app, its glance and its background
// service.
(:background, :glance)
module Queue {
    const KEY = "q";
    const CURRENT = "cur";
    // Background retry interval while notes wait: the retryMin setting, at least the platform's
    // 5 minutes.
    function retrySeconds() as Number {
        var m = Application.Properties.getValue("retryMin");
        var min = m instanceof Number ? m : 15;
        return (min < 5 ? 5 : min) * 60;
    }

    function notes() as Array<Dictionary> {
        var q = Application.Storage.getValue(KEY);
        return q == null ? ([] as Array<Dictionary>) : q as Array<Dictionary>;
    }

    function save(q as Array<Dictionary>) as Void {
        Application.Storage.setValue(KEY, q as Array<Application.PropertyValueType>);
    }

    function isUploaded(note as Dictionary) as Boolean {
        return note["up"] == true;
    }

    // Notes not yet uploaded, oldest first.
    function pending() as Array<Dictionary> {
        var out = [] as Array<Dictionary>;
        var q = notes();
        for (var i = 0; i < q.size(); i++) {
            if (!isUploaded(q[i])) { out.add(q[i]); }
        }
        return out;
    }

    // The number of notes waiting for upload.
    function count() as Number {
        return pending().size();
    }

    // What the uploader was doing when it last started a request; cleared on its answer.
    function trace() as String? {
        return Application.Storage.getValue("trace") as String?;
    }

    function setTrace(s as String?) as Void {
        System.println("trace: " + s);
        if (s == null) { Application.Storage.deleteValue("trace"); } else { Application.Storage.setValue("trace", s); }
    }

    // The open app owns the queue: while it runs it stamps "fg", and the background service stays
    // out (two processes saving "q" could drop each other's changes). A stamp older than an hour
    // is from an app that did not get to clear it.
    function markForeground(open as Boolean) as Void {
        if (open) { Application.Storage.setValue("fg", Time.now().value()); } else { Application.Storage.deleteValue("fg"); }
    }

    function foregroundOpen() as Boolean {
        var t = Application.Storage.getValue("fg") as Number?;
        return t != null && Time.now().value() - t < 3600;
    }

    function partKey(id as String, n as Number) as String {
        return id + ":" + n;
    }

    function part(id as String, n as Number) as ByteArray? {
        return Application.Storage.getValue(partKey(id, n)) as ByteArray?;
    }

    // Recording side: begin, add parts, then finish into the queue.
    function begin(id as String, rec as Number) as Void {
        Application.Storage.setValue(CURRENT, {"id" => id, "rec" => rec, "n" => 0, "b" => 0});
    }

    // Throws when Storage is full; the recorder stops then.
    function addPart(bytes as ByteArray) as Void {
        var cur = Application.Storage.getValue(CURRENT) as Dictionary?;
        if (cur == null) { return; }
        var n = cur["n"] as Number;
        Application.Storage.setValue(partKey(cur["id"] as String, n), bytes);
        cur["n"] = n + 1;
        cur["b"] = (cur["b"] == null ? 0 : cur["b"] as Number) + bytes.size();
        Application.Storage.setValue(CURRENT, cur as Dictionary<Application.PropertyKeyType, Application.PropertyValueType>);
    }

    // Discards the recording in progress: its parts and the "cur" entry, so nothing of it is
    // salvaged on the next start or uploaded.
    function discardCurrent() as Void {
        var cur = Application.Storage.getValue(CURRENT) as Dictionary?;
        if (cur == null) { return; }
        for (var p = 0; p < (cur["n"] as Number); p++) {
            Application.Storage.deleteValue(partKey(cur["id"] as String, p));
        }
        Application.Storage.deleteValue(CURRENT);
    }

    // The note `id` while it has not started uploading: removes it and returns true.
    function removeUnsent(id as String) as Boolean {
        var q = notes();
        for (var i = 0; i < q.size(); i++) {
            if ((q[i]["id"] as String).equals(id)) {
                if (isUploaded(q[i]) || (q[i]["sent"] as Number) > 0) { return false; }
                remove(id);
                return true;
            }
        }
        return false;
    }

    // Moves the recording in progress (if any) into the queue. `dur` is null when salvaging a
    // recording the app did not finish; its length is then unknown.
    function finish(dur as Number?) as Void {
        var cur = Application.Storage.getValue(CURRENT) as Dictionary?;
        if (cur == null) { return; }
        Application.Storage.deleteValue(CURRENT);
        if ((cur["n"] as Number) == 0) { return; }
        var bytes = cur["b"] == null ? 0 : cur["b"] as Number;
        var q = notes();
        q.add({"id" => cur["id"], "rec" => cur["rec"], "dur" => dur == null ? 0 : dur,
            "n" => cur["n"], "sent" => 0, "kb" => (bytes + 1023) / 1024, "up" => false});
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

    // The server holds the whole note: keep it for playback, then apply the cleanup settings.
    function markUploaded(id as String) as Void {
        var q = notes();
        for (var i = 0; i < q.size(); i++) {
            if ((q[i]["id"] as String).equals(id)) {
                q[i]["up"] = true;
                q[i]["sent"] = q[i]["n"];
                save(q);
                break;
            }
        }
        prune();
    }

    // Cleanup of uploaded notes: those older than keepDays (0 = right after upload), then the
    // oldest while all notes together take more than keepKb. Waiting notes are never touched.
    function prune() as Void {
        var keepDays = Application.Properties.getValue("keepDays") as Number?;
        var keepKb = Application.Properties.getValue("keepKb") as Number?;
        if (keepDays == null) { keepDays = 7; }
        if (keepKb == null) { keepKb = 1024; }
        var cutoff = Time.now().value() - keepDays * 86400;
        var q = notes();
        var total = 0;
        for (var i = 0; i < q.size(); i++) { total += kb(q[i]); }
        for (var i = 0; i < q.size(); i++) {  // oldest first
            var note = q[i];
            if (!isUploaded(note)) { continue; }
            if (keepDays == 0 || (note["rec"] as Number) < cutoff || total > keepKb) {
                total -= kb(note);
                remove(note["id"] as String);
            }
        }
    }

    function kb(note as Dictionary) as Number {
        return note["kb"] == null ? 0 : note["kb"] as Number;
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

    // MENU, Delete waiting: the notes not yet uploaded.
    function clearPending() as Void {
        var p = pending();
        for (var i = 0; i < p.size(); i++) { remove(p[i]["id"] as String); }
    }
}
