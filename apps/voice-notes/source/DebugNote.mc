import Toybox.Application;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;

// Debug builds only (`just build`, the simulator); release builds such as the beta .iq drop it.
// The simulator has no microphone in the VM, so this puts a recording-sized note into the queue
// to exercise uploads: `kb` KB of zeros starting with "OggS", in pieces of the partKb setting.
(:debug)
module DebugNote {
    function add(kb as Number) as Void {
        var now = Time.now().value();
        Queue.begin("sim" + now.format("%d") + "-" + (Math.rand() % 1000).format("%03d"), now);
        var part = (Application.Properties.getValue("partKb") as Number) * 1024 - 64;
        var left = kb * 1024;
        var first = true;
        while (left > 0) {
            var n = left < part ? left : part;
            var b = new [n]b;  // zeros; a byte loop this long trips the watchdog
            if (first) { b[0] = 0x4F; b[1] = 0x67; b[2] = 0x67; b[3] = 0x53; first = false; }
            Queue.addPart(b);
            left -= n;
        }
        Queue.finish(kb / 2);
    }
}
