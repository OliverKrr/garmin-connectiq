import Toybox.Application;
import Toybox.WatchUi;

// Data field app entry point.
class RunFieldApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    // The data field view is the initial (and only) view.
    function getInitialView() {
        return [ new RunFieldView() ];
    }
}
