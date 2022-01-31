package ecs.core.macro;

import haxe.macro.Type.AbstractType;
import haxe.macro.Printer;
#if macro
import haxe.macro.Expr;
using tink.MacroApi;
import ecs.core.macro.MacroTools.*;
using StringTools;
using Lambda;
import haxe.macro.Context;
using haxe.macro.TypeTools;

class PoolBuilder {
    static var _printer :Printer = new Printer();

    // Sorry this is brutally messy, it took a while to work through the edge cases
    public static function arrayPool() {
        var fields = Context.getBuildFields();

        var lt = Context.getLocalType().follow();
        var ct = lt.toComplexType();

        switch(lt) {
            case TInst(t, params): 
                switch (t.get().kind) {
                    case KAbstractImpl(a): 
                        if (a.get().params.length > 0) throw 'Pools do not support abstract types with parameters on ${ct.toString()}';
                        ct = Context.resolveType(TPath(tpath(a.get().name)), Context.currentPos()).toComplexType();
                    default:
                }
            default:
        }

        // Create pool static var
        {
            var atp = tpath([], "Array", [TPType(ct)]);
            var at = TPath(atp);
            var atalloc = constructExpr( atp );        
            fields.push(fvar(null, [AStatic], "__pool", at, atalloc , Context.currentPos() ));
        }
        // Rent
        {
            var tp = ct.toString().asTypePath();
            var factoryField = fields.find( (x) -> x.meta.toMap().exists(":pool_factory"));
            var newCall = factoryField != null ? macro $i{factoryField.name}() : macro new $tp();
            var allocBody = macro return  (__pool.length == 0) ?  $newCall : __pool.pop();            
            fields.push(ffun(null, [APublic, AStatic], "rent", null, ct, allocBody, Context.currentPos()        ));
        }

        // Retire
        {
            var retireCalls = fields.filter( (x) -> x.meta.toMap().exists(":pool_retire")).map((x) -> macro $i{x.name}());
            retireCalls.push(macro __pool.push( this ));
            fields.push(ffun(null, [APublic, AInline], "retire", [], null, macro $b{retireCalls} , Context.currentPos())   );
        }

        var cb = new ClassBuilder(fields);

        // In the case it doesn't already have a constructor, make a private default one
        if (! cb.hasConstructor() && !fields.exists( (x) -> x.name == "_new")) {
            var constructor = cb.getConstructor();
            constructor.isPublic = false;
            constructor.publish();
        }

        return cb.export();
    }

    public static function linkedPool(debug: Bool = false) {
        var fields = Context.getBuildFields();

        var ct = Context.getLocalType().toComplex();

        var body = macro {};
        fields.push(ffun(null, [APublic, AStatic, AInline], "rent", null, ct, body, Context.currentPos()        ));

        fields.push(ffun(null, [APublic, AInline], "retire", [{name:"p", type:ct }], null, body, Context.currentPos()        ));

        return fields;

    }


}
#end