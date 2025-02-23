package test;

import haxe.macro.Expr;
import haxe.macro.Printer;

class TestMacros {
    static var _printer = new Printer();
    static macro function assertEquals(a : Expr, b : Expr) : Expr {
        return macro {
            if ($a != $b) {
                var aStr = _printer.printExpression($a);
                var bStr = _printer.printExpression($b);
                trace('Test failed: $aStr != $bStr');
            }
        }
    }
}