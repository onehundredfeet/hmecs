package hcqe.core.macro;

import haxe.macro.Printer;
#if macro
import haxe.macro.Expr;
using tink.MacroApi;
import hcqe.core.macro.MacroTools.*;
using StringTools;
using Lambda;
import haxe.macro.Context;

class PoolBuilder {
    static var _printer :Printer = new Printer();

    public static function arrayPool(debug: Bool = false) {
        var fields = Context.getBuildFields();

        var ct = followComplexType(Context.getLocalType().toComplex());

//        trace('Pool for ${ct.toString()} being built');
        var c = constructExpr(ct.toString().asTypePath());
        var allocBody = macro return  (__pool.length == 0) ?  $c : return __pool.pop();

        var tp = tpath([], "Array", [TPType(ct)]);
        var at = TPath(tp);
        var atalloc = constructExpr( tp );

        fields.push(fvar(null, [AStatic], "__pool", at, atalloc , Context.currentPos() ));
        fields.push(ffun(null, [APublic, AStatic, AInline], "alloc", null, ct, allocBody, Context.currentPos()        ));
        fields.push(ffun(null, [APublic, AInline], "retire", [], null, macro __pool.push(this), Context.currentPos()        ));

        return fields;
    }

    public static function linkedPool(debug: Bool = false) {
        var fields = Context.getBuildFields();

        var ct = Context.getLocalType().toComplex();

        var body = macro {};
        fields.push(ffun(null, [APublic, AStatic, AInline], "alloc", null, ct, body, Context.currentPos()        ));

        fields.push(ffun(null, [APublic, AInline], "retire", [{name:"p", type:ct }], null, body, Context.currentPos()        ));

        return fields;

    }


}
#end