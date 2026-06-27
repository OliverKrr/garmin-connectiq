import Toybox.Test;
import Toybox.Lang;

(:test)
function runningAverage_meanOfThree(logger as Test.Logger) as Boolean {
    var a = new RunningAverage();
    a.add(140); a.add(150); a.add(160);
    return a.average() == 150;
}

(:test)
function runningAverage_emptyIsNull(logger as Test.Logger) as Boolean {
    return (new RunningAverage()).average() == null;
}

(:test)
function runningAverage_resetClears(logger as Test.Logger) as Boolean {
    var a = new RunningAverage();
    a.add(100); a.add(200);
    a.reset();
    return a.average() == null && a.count() == 0;
}

(:test)
function runningAverage_truncatesToInteger(logger as Test.Logger) as Boolean {
    var a = new RunningAverage();
    a.add(1); a.add(2); // mean 1.5 -> truncates to 1
    return a.average() == 1;
}
