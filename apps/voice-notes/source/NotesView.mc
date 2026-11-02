import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

// The foreground state: the recorder, the uploader and the last status line.
class Notes {
    var recorder as Recorder;
    var uploader as Uploader;
    var status as String = "";
    private var _tick as Timer.Timer = new Timer.Timer();
    private var _boot as Timer.Timer = new Timer.Timer();

    function initialize() {
        recorder = new Recorder(method(:onRecorded));
        uploader = new Uploader(method(:onUploaded), method(:onProgress));
        if (!Recorder.supported()) { status = "no microphone API on this watch"; }
        var trace = Queue.trace();
        if (trace != null) {
            // The last run died inside a request: report it, and upload only when asked (MENU).
            status = "stopped at " + trace;
            Queue.setTrace(null);
        } else {
            _boot.start(method(:upload), 1500, false);
        }
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

    function upload() as Void {
        if (recorder.isRecording() || uploader.isBusy() || Queue.count() == 0) { return; }
        status = "uploading";
        uploader.start();
        WatchUi.requestUpdate();
    }

    function onTick() as Void {
        WatchUi.requestUpdate();
    }

    function onRecorded(error as String?) as Void {
        _tick.stop();
        status = error != null ? error : "saved";
        System.println("recorded: " + status + ", queue " + Queue.count());
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
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
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
        dc.drawText(w / 2, h * 64 / 100, Graphics.FONT_SMALL, q == 0 ? "all uploaded" : q + " waiting",
            Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 78 / 100, Graphics.FONT_XTINY, _n.status, Graphics.TEXT_JUSTIFY_CENTER);
    }
}

class NotesDelegate extends WatchUi.BehaviorDelegate {
    private var _n as Notes;

    function initialize(n as Notes) {
        BehaviorDelegate.initialize();
        _n = n;
    }

    function onSelect() as Boolean {
        _n.toggle();
        return true;
    }

    // BACK while recording saves the note rather than leaving the app mid-word.
    function onBack() as Boolean {
        if (_n.recorder.isRecording()) {
            _n.recorder.stop();
            return true;
        }
        return false;
    }

    // Debug builds: DOWN queues a 40 KB test note, UP uploads it over LTE (see DebugNote).
    (:debug)
    function onNextPage() as Boolean {
        DebugNote.add(40);
        System.println("test note added, queue " + Queue.count());
        _n.status = "test note added";
        WatchUi.requestUpdate();
        return true;
    }

    (:debug)
    function onPreviousPage() as Boolean {
        _n.status = "uploading via LTE";
        _n.uploader.startVia(true);
        WatchUi.requestUpdate();
        return true;
    }

    function onMenu() as Boolean {
        if (_n.recorder.isRecording()) { return true; }
        var m = new WatchUi.Menu2({:title => "Voice Notes"});
        m.addItem(new WatchUi.MenuItem("Upload now", Queue.count() + " waiting", :upload, null));
        m.addItem(new WatchUi.MenuItem("Delete waiting", "notes not uploaded yet", :clear, null));
        WatchUi.pushView(m, new NotesMenuDelegate(_n), WatchUi.SLIDE_UP);
        return true;
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
        }
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
            Queue.clear();
            NotesApp.scheduleRetry();
            _n.status = "deleted";
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);  // the menu
        return true;
    }
}
