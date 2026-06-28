import Toybox.Application;
import Toybox.WatchUi;

// Data field app entry point.
class RunFieldApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        return [ new RunFieldView() ];
    }

    // Settings changed in Garmin Connect Mobile / the simulator: redraw with them.
    function onSettingsChanged() as Void {
        WatchUi.requestUpdate();
    }
}
