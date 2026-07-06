import Toybox.Lang;
import Toybox.Test;

(:test)
function zoneColor_white5(logger as Logger) as Boolean {
    return ZoneColor.of(1, true) == 0x555555 && ZoneColor.of(2, true) == 0x0000AA
        && ZoneColor.of(3, true) == 0x006600 && ZoneColor.of(4, true) == 0xAA5500
        && ZoneColor.of(5, true) == 0xAA0000;
}

(:test)
function zoneColor_black5(logger as Logger) as Boolean {
    return ZoneColor.of(1, false) == 0xAAAAAA && ZoneColor.of(2, false) == 0x00AAFF
        && ZoneColor.of(3, false) == 0x00CC00 && ZoneColor.of(4, false) == 0xFFAA00
        && ZoneColor.of(5, false) == 0xFF3333;
}

(:test)
function zoneColor_white7(logger as Logger) as Boolean {
    return ZoneColor.of7(1, true) == 0x555555 && ZoneColor.of7(3, true) == 0x00AAAA
        && ZoneColor.of7(5, true) == 0xAA5500 && ZoneColor.of7(7, true) == 0xAA0000;
}

(:test)
function zoneColor_black7(logger as Logger) as Boolean {
    return ZoneColor.of7(2, false) == 0x3B82F6 && ZoneColor.of7(4, false) == 0x22C55E
        && ZoneColor.of7(6, false) == 0xFF8800 && ZoneColor.of7(7, false) == 0xFF3333;
}

(:test)
function zoneColor_zone0IsGrey(logger as Logger) as Boolean {
    return ZoneColor.of(0, true) == 0x555555 && ZoneColor.of7(0, false) == 0xAAAAAA;
}

(:test)
function zoneColor_8020White(logger as Logger) as Boolean {
    // 1/X(3)/Y(5) greys; 2/3(4)/4(6)/5(7) the normal colours
    return ZoneColor.of8020(1, true) == 0x555555 && ZoneColor.of8020(3, true) == 0x445566
        && ZoneColor.of8020(5, true) == 0x665544 && ZoneColor.of8020(2, true) == 0x0000AA
        && ZoneColor.of8020(4, true) == 0x006600 && ZoneColor.of8020(6, true) == 0xAA5500
        && ZoneColor.of8020(7, true) == 0xAA0000;
}

(:test)
function zoneColor_8020GreysDistinct(logger as Logger) as Boolean {
    // the three "grey" zones (1, X, Y) are visually distinct on both themes
    return ZoneColor.of8020(1, true) != ZoneColor.of8020(3, true)
        && ZoneColor.of8020(3, true) != ZoneColor.of8020(5, true)
        && ZoneColor.of8020(1, true) != ZoneColor.of8020(5, true)
        && ZoneColor.of8020(1, false) != ZoneColor.of8020(3, false)
        && ZoneColor.of8020(3, false) != ZoneColor.of8020(5, false);
}
