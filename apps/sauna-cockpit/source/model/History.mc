import Toybox.Lang;
import Toybox.Application;

// Saved sessions, newest first, in Application.Storage under "sessions". Plain arrays keep the
// stored form small and storage-safe:
//   session = [startEpochSec, totalSec, minHr, avgHr, maxHr, maxTemp10, rounds, kcal]
//   round   = [heatSec, minHr, avgHr, maxHr, maxTemp10, coolSec, hrr60]
// maxTemp10 is °C x 10. NONE marks a missing value; it is not -1 because hrr60 and temperatures
// can be negative. Everything but the Storage functions (load, save, add, removeAt) is pure.
module History {
    const NONE = -32768;
    const MAX_SESSIONS = 50;
    const KEY = "sessions";

    // Session field indices.
    const S_START = 0;
    const S_TOTAL = 1;
    const S_MIN = 2;
    const S_AVG = 3;
    const S_MAX = 4;
    const S_TEMP = 5;
    const S_ROUNDS = 6;
    const S_KCAL = 7;

    // Round field indices.
    const R_HEAT = 0;
    const R_MIN = 1;
    const R_AVG = 2;
    const R_MAX = 3;
    const R_TEMP = 4;
    const R_COOL = 5;
    const R_HRR = 6;

    function n(v as Number or Null) as Number {
        return v == null ? NONE : v;
    }

    function t10(v as Float or Null) as Number {
        return v == null ? NONE : (v * 10.0).toNumber();
    }

    // A session entry from a finished model.
    function entry(m as SessionModel, startEpoch as Number, kcal as Number or Null) as Array {
        var t = m.total;
        return [startEpoch, t.seconds, n(t.minHr), n(t.avgHr()), n(t.maxHr), t10(t.maxTemp), m.roundRows(), n(kcal)];
    }

    // Prepend an entry, keeping at most MAX_SESSIONS.
    function prepend(list as Array<Array>, e as Array) as Array<Array> {
        var out = [e] as Array<Array>;
        var keep = list.size() < MAX_SESSIONS - 1 ? list.size() : MAX_SESSIONS - 1;
        for (var i = 0; i < keep; i++) { out.add(list[i]); }
        return out;
    }

    // [sessions, rounds, heatSec] over entries that started at or after sinceEpoch.
    function totalsSince(list as Array<Array>, sinceEpoch as Number) as Array<Number> {
        var sessions = 0;
        var rounds = 0;
        var heat = 0;
        for (var i = 0; i < list.size(); i++) {
            var e = list[i];
            if ((e[S_START] as Number) < sinceEpoch) { continue; }
            sessions++;
            var rs = e[S_ROUNDS] as Array<Array<Number>>;
            rounds += rs.size();
            for (var j = 0; j < rs.size(); j++) { heat += rs[j][R_HEAT]; }
        }
        return [sessions, rounds, heat];
    }

    function load() as Array<Array> {
        var v = Application.Storage.getValue(KEY);
        return v instanceof Array ? v as Array<Array> : [] as Array<Array>;
    }

    function save(list as Array<Array>) as Void {
        Application.Storage.setValue(KEY, list as Application.PropertyValueType);
    }

    function add(e as Array) as Void {
        save(prepend(load(), e));
    }

    function removeAt(i as Number) as Void {
        var list = load();
        if (i < 0 || i >= list.size()) { return; }
        var out = [] as Array<Array>;
        for (var j = 0; j < list.size(); j++) {
            if (j != i) { out.add(list[j]); }
        }
        save(out);
    }
}
