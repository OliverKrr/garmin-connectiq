import Toybox.Application;
import Toybox.WatchUi;
import Toybox.Lang;

// Data field app entry point.
class RunFieldApp extends Application.AppBase {
    private var _view as RunFieldView or Null = null;

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        _view = new RunFieldView();
        return [ _view ];
    }

    // Settings changed in Garmin Connect Mobile / the simulator: re-read them into
    // the view's model so they apply live, then redraw.
    function onSettingsChanged() as Void {
        if (_view != null) {
            _view.reloadSettings();
        }
        WatchUi.requestUpdate();
    }
}
