import Toybox.Activity;
import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;

// Background retry: every 15 minutes while notes wait, and after every recorded activity, upload
// what is queued without opening the app. Exits with the upload status for the app to show.
(:background)
class UploadService extends System.ServiceDelegate {
    private var _uploader as Uploader?;

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        upload();
    }

    function onActivityCompleted(activity as {:sport as Activity.Sport, :subSport as Activity.SubSport}) as Void {
        upload();
    }

    private function upload() as Void {
        if (Queue.foregroundOpen()) {
            Background.exit(null);  // the app uploads itself
            return;
        }
        Queue.finish(null);
        _uploader = new Uploader(method(:onDone), null);
        (_uploader as Uploader).start();
    }

    function onDone(status as String) as Void {
        Background.exit(status);
    }
}
