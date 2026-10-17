import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Watch app entry point. One SessionController lives for the app's lifetime.
class SaunaApp extends Application.AppBase {
    var controller as SessionController = new SessionController();

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        controller.enableSensors();
    }

    function onStop(state as Dictionary?) as Void {
        controller.shutdown();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        return [new StartView(controller), new StartDelegate(controller)];
    }
}

function getApp() as SaunaApp {
    return Application.getApp() as SaunaApp;
}
