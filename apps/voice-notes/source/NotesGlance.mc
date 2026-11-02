import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// The widget-loop glance: the app name and how many notes wait. Selecting it opens the app on its
// record screen.
(:glance)
class NotesGlance extends WatchUi.GlanceView {
    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var q = Queue.count();
        var all = Queue.notes().size();
        var line = q > 0 ? q + " waiting" : (all > 0 ? "all uploaded, " + all + " on watch" : "START to record");
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, h * 30 / 100, Graphics.FONT_GLANCE, "VOICE NOTES",
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(q > 0 ? Graphics.COLOR_ORANGE : Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, h * 72 / 100, Graphics.FONT_GLANCE, line,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
