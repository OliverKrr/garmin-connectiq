import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Activity;
import Toybox.Lang;

// Minimal full-screen data field used to prove the build -> sim -> sideload
// pipeline. Real metrics and the grid + chart-sidebar layout arrive in P2.
class RunFieldView extends WatchUi.DataField {
    private var _elapsedSec as Number = 0;

    function initialize() {
        DataField.initialize();
    }

    // Cache layout geometry once. (Populated in P2.)
    function onLayout(dc as Graphics.Dc) as Void {
    }

    // Called ~once per second while the activity records.
    function compute(info as Activity.Info) as Void {
        var t = info.timerTime;
        if (t != null) {
            _elapsedSec = (t as Number) / 1000;
        }
    }

    // Render the field. getBackgroundColor() respects the user's theme.
    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_TRANSPARENT, getBackgroundColor());
        dc.clear();
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            dc.getWidth() / 2,
            dc.getHeight() / 2,
            Graphics.FONT_MEDIUM,
            "run-field " + _elapsedSec + "s",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }
}
