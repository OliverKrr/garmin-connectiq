import Toybox.Lang;
import Toybox.Graphics;
import Toybox.UserProfile;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Colours and small drawing helpers shared by every view. Dark background throughout, which
// also keeps the AMOLED screen's light output (and heat) low.
module Theme {
    const BG = Graphics.COLOR_BLACK;
    const FG = Graphics.COLOR_WHITE;
    const DIM = 0x8A8A8A;
    const TRACK = 0x2A2A2A;
    const HEAT = 0xFF6A00;
    const COOL = 0x2EA8FF;
    const WARN = 0xFF2A2A;
    const CAUTION = 0xFFC400;
    const GO = 0x3CD070;

    // Garmin's zone colours: grey, blue, green, orange, red.
    const ZONE = [0xA0A0A0, 0x2EA8FF, 0x3CD070, 0xFF9A00, 0xFF2A2A];

    var _zones as Array<Number> or Null = null;

    // Percent brightness every colour is drawn at; below 100 dims the whole screen. Set by the
    // session view per frame (Config.heatScreen / restScreen), 100 everywhere else.
    var level as Number = 100;

    function c(color as Number) as Number {
        if (level >= 100) { return color; }
        var r = ((color >> 16) & 0xFF) * level / 100;
        var g = ((color >> 8) & 0xFF) * level / 100;
        var b = (color & 0xFF) * level / 100;
        return (r << 16) | (g << 8) | b;
    }

    function zoneColor(hr as Number or Null) as Number {
        if (hr == null) { return DIM; }
        if (_zones == null) {
            var z = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_GENERIC);
            _zones = (z != null && z.size() >= 6) ? z : [93, 111, 130, 148, 167, 185];
        }
        var z = _zones as Array<Number>;
        for (var i = 4; i >= 1; i--) {
            if (hr > z[i]) { return ZONE[i]; }
        }
        return ZONE[0];
    }

    function phaseColor(phase as Number) as Number {
        return phase == PHASE_HEAT ? HEAT : COOL;
    }

    // Progress ring along the bezel, clockwise from 12 o'clock. frac >= 1 draws a full ring.
    function ring(dc as Graphics.Dc, frac as Float, color as Number) as Void {
        var w = dc.getWidth();
        var pen = w * 4 / 100;
        var r = w / 2 - pen / 2 - 1;
        dc.setPenWidth(pen);
        dc.setColor(c(TRACK), BG);
        dc.drawCircle(w / 2, dc.getHeight() / 2, r);
        dc.setColor(c(color), BG);
        if (frac >= 1.0) {
            dc.drawCircle(w / 2, dc.getHeight() / 2, r);
        } else if (frac > 0.003) {
            var end = 90 - (frac * 360).toNumber();
            dc.drawArc(w / 2, dc.getHeight() / 2, r, Graphics.ARC_CLOCKWISE, 90, end);
        }
        dc.setPenWidth(1);
    }

    function text(dc as Graphics.Dc, x as Number, y as Number, font as Graphics.FontType, s as String, color as Number, just as Number) as Void {
        dc.setColor(c(color), Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, s, just | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // "Sat 17 Oct 18:30".
    function date(epoch as Number) as String {
        var d = Gregorian.info(new Time.Moment(epoch), Time.FORMAT_MEDIUM);
        return Lang.format("$1$ $2$ $3$ $4$:$5$", [d.day_of_week, d.day, d.month, d.hour, (d.min as Number).format("%02d")]);
    }
}
