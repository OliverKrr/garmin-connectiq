import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

// Voice Notes: START records a note, START again stops it, and the note uploads to the server
// set in the app settings, through the phone or over LTE. Notes that cannot go up wait in the
// watch's storage and are retried in the background.
(:background)
class NotesApp extends Application.AppBase {
    private var _notes as Notes?;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
        if (_notes != null) {
            (_notes as Notes).recorder.abort();
            scheduleRetry();
        }
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        // A note the app did not get to finish (killed while recording) joins the queue.
        Queue.finish(null);
        if (Background has :registerForActivityCompletedEvent) {
            Background.registerForActivityCompletedEvent();
        }
        var notes = new Notes();
        _notes = notes;
        notes.upload();
        return [new NotesView(notes), new NotesDelegate(notes)];
    }

    function getServiceDelegate() as [System.ServiceDelegate] {
        return [new UploadService()];
    }

    function onBackgroundData(data as Application.PersistableType) as Void {
        if (_notes != null && data instanceof String) {
            (_notes as Notes).status = "bg: " + data;
            WatchUi.requestUpdate();
        }
    }

    function onSettingsChanged() as Void {
        if (_notes != null) { (_notes as Notes).upload(); }
    }

    // A 15-minute temporal event while notes wait, none once the queue is empty.
    static function scheduleRetry() as Void {
        if (Queue.count() > 0) {
            Background.registerForTemporalEvent(new Time.Duration(Queue.RETRY_S));
        } else {
            Background.deleteTemporalEvent();
        }
    }
}
