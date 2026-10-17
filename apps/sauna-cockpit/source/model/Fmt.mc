import Toybox.Lang;
import Toybox.Math;

// Text formatting for the views. Pure, so it is unit-tested.
module Fmt {
    // 75 -> "1:15", 3725 -> "1:02:05".
    function clock(sec as Number) as String {
        if (sec < 0) { sec = 0; }
        var h = sec / 3600;
        var m = (sec % 3600) / 60;
        var s = sec % 60;
        if (h > 0) {
            return h.format("%d") + ":" + m.format("%02d") + ":" + s.format("%02d");
        }
        return m.format("%d") + ":" + s.format("%02d");
    }

    // Whole minutes, rounded: 754 -> "13'".
    function minutes(sec as Number) as String {
        return ((sec + 30) / 60).format("%d") + "'";
    }

    // History.NONE-aware integer: NONE -> "--".
    function num(v as Number) as String {
        return v == History.NONE ? "--" : v.format("%d");
    }

    // °C x 10 -> "44°", rounded (History.NONE -> "--").
    function temp10(v as Number) as String {
        return v == History.NONE ? "--" : Math.round(v / 10.0).format("%d") + "°";
    }
}
