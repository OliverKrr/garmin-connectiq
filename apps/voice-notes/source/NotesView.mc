import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Timer;
import Toybox.WatchUi;

// The foreground state: the recorder, the uploader, the player, the last status line, and which
// screen shows (sel: -1 is the record screen the app always starts on, 0.. the notes, newest first).
class Notes {
    var recorder as Recorder;
    var uploader as Uploader;
    var player as Player;
    var status as String = "";
    var sel as Number = -1;
    private var _tick as Timer.Timer = new Timer.Timer();
    private var _boot as Timer.Timer = new Timer.Timer();

    function initialize() {
        recorder = new Recorder(method(:onRecorded));
        uploader = new Uploader(method(:onUploaded), method(:onProgress));
        player = new Player(method(:onProgress));
        if (!Recorder.supported()) { status = "no microphone API on this watch"; }
        Queue.prune();
        var trace = Queue.trace();
        var perr = Player.lastError();
        if (perr != null) {
            status = "last playback: " + perr;
            Application.Storage.deleteValue("perr");
        }
        if (trace != null) {
            // The last run died inside a request: report it, and upload only when asked (MENU).
            status = "stopped at " + trace;
            Queue.setTrace(null);
        } else {
            _boot.start(method(:upload), 1500, false);
        }
    }

    // All notes, newest first.
    function list() as Array<Dictionary> {
        var q = Queue.notes();
        var out = [] as Array<Dictionary>;
        for (var i = q.size() - 1; i >= 0; i--) { out.add(q[i]); }
        return out;
    }

    function selected() as Dictionary? {
        var l = list();
        return sel >= 0 && sel < l.size() ? l[sel] : null;
    }

    // DOWN (+1) and UP (-1) between the record screen and the notes; playback stops on a move.
    function move(step as Number) as Void {
        if (recorder.isRecording()) { return; }
        var next = sel + step;
        var last = list().size() - 1;
        if (next < -1) { next = -1; }
        if (next > last) { next = last; }
        if (next != sel) {
            player.stop();
            sel = next;
            WatchUi.requestUpdate();
        }
    }

    function home() as Void {
        player.stop();
        sel = -1;
        WatchUi.requestUpdate();
    }

    function toggle() as Void {
        if (recorder.isRecording()) {
            recorder.stop();
            return;
        }
        var err = recorder.start();
        if (err != null) {
            status = err;
        } else {
            status = "";
            _tick.start(method(:onTick), 1000, true);
        }
        WatchUi.requestUpdate();
    }

    function togglePlay() as Void {
        var note = selected();
        if (note == null) { return; }
        if (player.playingId() != null && (player.playingId() as String).equals(note["id"] as String)) {
            player.stop();
        } else {
            player.play(note);
        }
        WatchUi.requestUpdate();
    }

    function deleteSelected() as Void {
        var note = selected();
        if (note == null) { return; }
        player.stop();
        Queue.remove(note["id"] as String);
        NotesApp.scheduleRetry();
        var last = list().size() - 1;
        if (sel > last) { sel = last; }
        status = "note deleted";
        WatchUi.requestUpdate();
    }

    function upload() as Void {
        Queue.markForeground(true);
        if (recorder.isRecording() || uploader.isBusy() || Queue.count() == 0) { return; }
        status = "uploading";
        uploader.start();
        WatchUi.requestUpdate();
    }

    function onTick() as Void {
        Queue.markForeground(true);
        WatchUi.requestUpdate();
    }

    function onRecorded(error as String?) as Void {
        _tick.stop();
        status = error != null ? error : "saved";
        System.println("recorded: " + status + ", waiting " + Queue.count());
        NotesApp.scheduleRetry();
        upload();
        WatchUi.requestUpdate();
    }

    function onProgress() as Void {
        WatchUi.requestUpdate();
    }

    function onUploaded(result as String) as Void {
        System.println("upload: " + result);
        status = result;
        NotesApp.scheduleRetry();
        var last = list().size() - 1;  // cleanup may have removed notes
        if (sel > last) { sel = last; }
        WatchUi.requestUpdate();
    }
}

class NotesView extends WatchUi.View {
    private var _n as Notes;

    function initialize(n as Notes) {
        View.initialize();
        _n = n;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var note = _n.selected();
        if (note == null) {
            drawRecord(dc);
        } else {
            drawNote(dc, note);
        }
    }

    private function drawRecord(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var rec = _n.recorder.isRecording();
        dc.setColor(rec ? Graphics.COLOR_RED : Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(w / 2, h * 40 / 100, h / 6);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        if (rec) {
            var s = _n.recorder.elapsedS();
            dc.drawText(w / 2, h * 40 / 100, Graphics.FONT_MEDIUM, (s / 60) + ":" + (s % 60).format("%02d"),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(w / 2, h * 66 / 100, Graphics.FONT_SMALL, "START to stop", Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }
        dc.drawText(w / 2, h * 40 / 100, Graphics.FONT_SMALL, "REC",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(w / 2, h * 12 / 100, Graphics.FONT_XTINY, "START to record", Graphics.TEXT_JUSTIFY_CENTER);
        var q = Queue.count();
        var all = Queue.notes().size();
        var headline = q == 0 ? "all uploaded" : q + " waiting";
        dc.drawText(w / 2, h * 62 / 100, Graphics.FONT_SMALL, headline, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        if (!_n.status.equals(headline)) {
            dc.drawText(w / 2, h * 75 / 100, Graphics.FONT_XTINY, _n.status, Graphics.TEXT_JUSTIFY_CENTER);
        }
        if (all > 0) {
            dc.drawText(w / 2, h * 85 / 100, Graphics.FONT_XTINY, "DOWN: " + all + (all == 1 ? " note" : " notes"),
                Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    private function drawNote(dc as Graphics.Dc, note as Dictionary) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var total = Queue.notes().size();
        var t = Gregorian.info(new Time.Moment(note["rec"] as Number), Time.FORMAT_SHORT);
        var when = t.day.format("%02d") + "." + (t.month as Number).format("%02d") + ". "
            + t.hour.format("%02d") + ":" + t.min.format("%02d");
        var dur = note["dur"] as Number;
        var playing = _n.player.playingId() != null && (_n.player.playingId() as String).equals(note["id"] as String);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 12 / 100, Graphics.FONT_XTINY, (_n.sel + 1) + " / " + total, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 21 / 100, Graphics.FONT_SMALL, when, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(playing ? Graphics.COLOR_GREEN : Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(w / 2, h * 50 / 100, h / 7);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        if (playing) {
            dc.fillRectangle(w / 2 - h / 24, h * 50 / 100 - h / 24, h / 12, h / 12);
        } else {
            var cx = w / 2 + h / 60;
            var cy = h * 50 / 100;
            var s = h / 18;
            dc.fillPolygon([[cx - s, cy - s], [cx - s, cy + s], [cx + s, cy]]);
        }
        dc.drawText(w / 2, h * 67 / 100, Graphics.FONT_SMALL,
            (dur / 60) + ":" + (dur % 60).format("%02d") + "  " + Queue.kb(note) + " KB", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Queue.isUploaded(note) ? Graphics.COLOR_LT_GRAY : Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
        var line = _n.player.error != null ? _n.player.error as String : (Queue.isUploaded(note) ? "uploaded" : "waiting");
        dc.drawText(w / 2, h * 79 / 100, Graphics.FONT_XTINY, line, Graphics.TEXT_JUSTIFY_CENTER);
    }
}

class NotesDelegate extends WatchUi.BehaviorDelegate {
    private var _n as Notes;

    function initialize(n as Notes) {
        BehaviorDelegate.initialize();
        _n = n;
    }

    // START: record or stop on the record screen, play or stop on a note.
    function onSelect() as Boolean {
        if (_n.sel < 0) { _n.toggle(); } else { _n.togglePlay(); }
        return true;
    }

    function onNextPage() as Boolean {
        _n.move(1);
        return true;
    }

    function onPreviousPage() as Boolean {
        _n.move(-1);
        return true;
    }

    // BACK while recording saves the note; on a note it returns to the record screen.
    function onBack() as Boolean {
        if (_n.recorder.isRecording()) {
            _n.recorder.stop();
            return true;
        }
        if (_n.sel >= 0) {
            _n.home();
            return true;
        }
        return false;
    }

    function onMenu() as Boolean {
        if (_n.recorder.isRecording()) { return true; }
        if (_n.sel >= 0) {
            WatchUi.pushView(new WatchUi.Confirmation("Delete this note?"),
                new DeleteNoteDelegate(_n), WatchUi.SLIDE_LEFT);
            return true;
        }
        var m = new WatchUi.Menu2({:title => "Voice Notes"});
        m.addItem(new WatchUi.MenuItem("Upload now", Queue.count() + " waiting", :upload, null));
        m.addItem(new WatchUi.MenuItem("Delete waiting", "notes not uploaded yet", :clear, null));
        addDebugItems(m);
        WatchUi.pushView(m, new NotesMenuDelegate(_n), WatchUi.SLIDE_UP);
        return true;
    }

    // Debug builds (the simulator has no microphone in the VM): queue a 40 KB test note, and
    // upload forcing the LTE route. Release builds such as the beta .iq have neither.
    (:debug)
    private function addDebugItems(m as WatchUi.Menu2) as Void {
        m.addItem(new WatchUi.MenuItem("Test note", "debug: 40 KB", :testNote, null));
        m.addItem(new WatchUi.MenuItem("Upload via LTE", "debug", :lteUpload, null));
    }

    (:release)
    private function addDebugItems(m as WatchUi.Menu2) as Void {
    }
}

class NotesMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _n as Notes;

    function initialize(n as Notes) {
        Menu2InputDelegate.initialize();
        _n = n;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :upload) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            _n.upload();
        } else if (id == :clear) {
            WatchUi.pushView(new WatchUi.Confirmation("Delete " + Queue.count() + " waiting notes?"),
                new ClearConfirmDelegate(_n), WatchUi.SLIDE_LEFT);
        } else {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            debugAction(id);
        }
    }

    (:debug)
    private function debugAction(id as Object?) as Void {
        if (id == :testNote) {
            DebugNote.add(40);
            System.println("test note added, waiting " + Queue.count());
            _n.status = "test note added";
        } else if (id == :lteUpload) {
            _n.status = "uploading via LTE";
            _n.uploader.startVia(true);
        }
        WatchUi.requestUpdate();
    }

    (:release)
    private function debugAction(id as Object?) as Void {
    }
}

class ClearConfirmDelegate extends WatchUi.ConfirmationDelegate {
    private var _n as Notes;

    function initialize(n as Notes) {
        ConfirmationDelegate.initialize();
        _n = n;
    }

    function onResponse(response as WatchUi.Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            Queue.clearPending();
            NotesApp.scheduleRetry();
            _n.status = "deleted";
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);  // the menu
        return true;
    }
}

class DeleteNoteDelegate extends WatchUi.ConfirmationDelegate {
    private var _n as Notes;

    function initialize(n as Notes) {
        ConfirmationDelegate.initialize();
        _n = n;
    }

    function onResponse(response as WatchUi.Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) { _n.deleteSelected(); }
        return true;
    }
}
