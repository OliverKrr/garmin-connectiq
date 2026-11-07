import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

// The save and discard cues shown while recording, at the edge next to the button that does it,
// as Garmin's own activity screens do: a green check by START (upper right) and a red X by BACK
// (lower right). Pure geometry, so the hit test is unit-tested.
module Markers {
    const SAVE = 1;
    const DISCARD = 2;
    // Degrees above (+) or below (-) the 3 o'clock line: START and BACK on the fenix 9 Pro.
    const SAVE_DEG = 30;
    const DISCARD_DEG = -30;

    // The marker's centre on a round screen of width w and height h.
    function center(w as Number, h as Number, deg as Number) as Array<Number> {
        var r = (w < h ? w : h) / 2 - radius(w, h) - (w < h ? w : h) / 40;
        var a = Math.toRadians(deg);
        return [w / 2 + (r * Math.cos(a)).toNumber(), h / 2 - (r * Math.sin(a)).toNumber()];
    }

    function radius(w as Number, h as Number) as Number {
        return (w < h ? w : h) / 16;
    }

    // SAVE, DISCARD or 0 for a tap at (x, y); the hit area is twice the drawn radius.
    function hit(x as Number, y as Number, w as Number, h as Number) as Number {
        var reach = radius(w, h) * 2;
        if (near(x, y, center(w, h, SAVE_DEG), reach)) { return SAVE; }
        if (near(x, y, center(w, h, DISCARD_DEG), reach)) { return DISCARD; }
        return 0;
    }

    function near(x as Number, y as Number, c as Array<Number>, reach as Number) as Boolean {
        var dx = x - c[0];
        var dy = y - c[1];
        return dx * dx + dy * dy <= reach * reach;
    }

    function draw(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var r = radius(w, h);
        var pen = r / 4 < 2 ? 2 : r / 4;
        dc.setPenWidth(pen);
        var s = center(w, h, SAVE_DEG);
        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(s[0], s[1], r);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(s[0] - r / 2, s[1], s[0] - r / 8, s[1] + r * 2 / 5);
        dc.drawLine(s[0] - r / 8, s[1] + r * 2 / 5, s[0] + r / 2, s[1] - r * 2 / 5);
        var d = center(w, h, DISCARD_DEG);
        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(d[0], d[1], r);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var k = r * 2 / 5;
        dc.drawLine(d[0] - k, d[1] - k, d[0] + k, d[1] + k);
        dc.drawLine(d[0] - k, d[1] + k, d[0] + k, d[1] - k);
        dc.setPenWidth(1);
    }
}
