import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Throwaway probe for SDK 9.3's microphone and LTE APIs (see README.md). Not a product.
class SpikeApp extends Application.AppBase {
    var spike as Spike = new Spike();

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        spike.log("START: menu");
    }

    function onStop(state as Dictionary?) as Void {
        spike.stopRecording();
        spike.lteOff();
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        return [new SpikeView(spike), new SpikeDelegate(spike)];
    }
}

// The log, newest line at the bottom.
class SpikeView extends WatchUi.View {
    private var _s as Spike;

    function initialize(s as Spike) {
        View.initialize();
        _s = s;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var font = Graphics.FONT_XTINY;
        var lh = dc.getFontHeight(font);
        var top = dc.getHeight() * 15 / 100;
        var rows = (dc.getHeight() * 70 / 100) / lh;
        var lines = _s.lines;
        var first = lines.size() > rows ? lines.size() - rows : 0;
        for (var i = first; i < lines.size(); i++) {
            dc.drawText(dc.getWidth() / 2, top + (i - first) * lh, font, lines[i], Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}

class SpikeDelegate extends WatchUi.BehaviorDelegate {
    private var _s as Spike;

    function initialize(s as Spike) {
        BehaviorDelegate.initialize();
        _s = s;
    }

    function onSelect() as Boolean {
        var m = new WatchUi.Menu2({:title => "Probe"});
        m.addItem(new WatchUi.MenuItem("Status", "formats, wifi, LTE", :status, null));
        m.addItem(new WatchUi.MenuItem("Record 10 s", "Ogg Opus 16 kHz", :record, null));
        m.addItem(new WatchUi.MenuItem("Upload rec", "POST the recording", :upload, null));
        m.addItem(new WatchUi.MenuItem("Size sweep", "4/16/64/128 KB", :sweep, null));
        m.addItem(new WatchUi.MenuItem("LTE on", null, :lteOn, null));
        m.addItem(new WatchUi.MenuItem("LTE off", null, :lteOff, null));
        WatchUi.pushView(m, new SpikeMenuDelegate(_s), WatchUi.SLIDE_UP);
        return true;
    }
}

class SpikeMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _s as Spike;

    function initialize(s as Spike) {
        Menu2InputDelegate.initialize();
        _s = s;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        var id = item.getId();
        if (id == :status) { _s.status(); }
        else if (id == :record) { _s.record(); }
        else if (id == :upload) { _s.uploadRecording(); }
        else if (id == :sweep) { _s.sweep(); }
        else if (id == :lteOn) { _s.lteOn(); }
        else if (id == :lteOff) { _s.lteOff(); }
    }
}
