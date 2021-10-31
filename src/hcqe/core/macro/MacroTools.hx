package hcqe.core.macro;

#if macro
import haxe.macro.ComplexTypeTools;
import haxe.macro.Expr;
import haxe.macro.Expr.Access;
import haxe.macro.Expr.ComplexType;
import haxe.macro.Expr.Field;
import haxe.macro.Expr.FunctionArg;
import haxe.macro.Expr.TypePath;
import haxe.macro.Expr.Position;
import haxe.macro.Printer;
import haxe.macro.TypeTools;
import haxe.macro.Type.ClassField;
import tink.macro.Types;
using haxe.macro.Context;
using Lambda;

/**
 * ...
 * @author https://github.com/deepcake
 */
@:final
@:dce
class MacroTools {

    public static function ffun(?meta:Metadata, ?access:Array<Access>, name:String, ?args:Array<FunctionArg>, ?ret:ComplexType, ?body:Expr, pos:Position):Field {
        return {
            meta: meta != null ? meta : [],
            name: name,
            access: access != null ? access : [],
            kind: FFun({
                args: args != null ? args : [],
                expr: body != null ? body : macro { },
                ret: ret
            }),
            pos: pos
        };
    }

    public static function fvar(?meta:Metadata, ?access:Array<Access>, name:String, ?type:ComplexType, ?expr:Expr, pos:Position):Field {
        return {
            meta: meta != null ? meta : [],
            name: name,
            access: access != null ? access : [],
            kind: FVar(type, expr),
            pos: pos
        };
    }


    public static function arg(name:String, type:ComplexType):FunctionArg {
        return {
            name: name,
            type: type
        };
    }

    public static function meta(name:String, ?params:Array<Expr>, pos:Position):MetadataEntry {
        return {
            name: name,
            params: params != null ? params : [],
            pos: pos
        }
    }

    public static function tpath(?pack:Array<String>, name:String, ?params:Array<TypeParam>, ?sub:String):TypePath {
        return {
            pack: pack != null ? pack : [],
            name: name,
            params: params != null ? params : [],
            sub: sub
        }
    }


    public static function followComplexType(ct:ComplexType) {
        return ComplexTypeTools.toType(ct).follow().toComplexType();
    }

    public static function followName(ct:ComplexType):String {
        return new Printer().printComplexType(followComplexType(ct));
    }


    public static function parseClassName(e:Expr) {
        return switch(e.expr) {
            case EConst(CIdent(name)): name;
            case EField(path, name): parseClassName(path) + '.' + name;
            case x: 
                #if (haxe_ver < 4) 
                throw 'Unexpected $x!';
                #else
                Context.error('Unexpected $x!', e.pos);
                #end 
        }
    }


    static function capitalize(s:String) {
        return s.substr(0, 1).toUpperCase() + (s.length > 1 ? s.substr(1).toLowerCase() : '');
    }

    static function typeParamName(p:TypeParam, f:ComplexType->String):String {
        return switch (p) {
            case TPType(ct): {
                f(ct);
            }
            case x: {
                #if (haxe_ver < 4) 
                throw 'Unexpected $x!';
                #else
                Context.error('Unexpected $x!', Context.currentPos());
                #end 
            }
        }
    }

    public static function typeValidShortName(ct:ComplexType):String {
        return switch (followComplexType(ct)) {
            case TPath(t): {

                (t.sub != null ? t.sub : t.name) + 
                ((t.params != null && t.params.length > 0) ? '<' + t.params.map(typeParamName.bind(_, typeValidShortName)).join(',') + '>' : '');

            }
            case x: {
                #if (haxe_ver < 4) 
                throw 'Unexpected $x!';
                #else
                Context.error('Unexpected $x!', Context.currentPos());
                #end
            }
        }
    }

    public static function typeFullName(ct:ComplexType):String {
        return switch (followComplexType(ct)) {
            case TPath(t): {

                (t.pack.length > 0 ? t.pack.map(capitalize).join('') : '') + 
                t.name + 
                (t.sub != null ? t.sub : '') + 
                ((t.params != null && t.params.length > 0) ? t.params.map(typeParamName.bind(_, typeFullName)).join('') : '');

            }
            case x: {
                #if (haxe_ver < 4) 
                throw 'Unexpected $x!';
                #else
                Context.error('Unexpected $x!', Context.currentPos());
                #end
            }
        }
    }

    public static function compareStrings(a:String, b:String):Int {
        a = a.toLowerCase();
        b = b.toLowerCase();
        return (a < b) ? -1 : (a > b) ? 1 : 0;
    }

    public static function joinFullName(types:Array<ComplexType>, sep:String) {
        var typeNames = types.map(typeFullName);
        typeNames.sort(compareStrings);
        return typeNames.join(sep);
    }

    static var WORLD_META = [ 'worlds', 'world', 'wd'];

    public static function metaFieldToWorlds(f : Field) : Int {
        var worldData = f.meta.filter( function (m) return WORLD_META.contains(m.name));
        if (worldData != null && worldData.length > 0) {
            var wd = worldData[0];
            if (wd.params.length > 0) {
                var p : Expr = wd.params[0];
                var pe = getNumericValue( p );
                if (pe != null) {
                    var t : Int = pe;
                    return pe;
                }
            }
        }
        return 0xffffffff;
    }

    public static function exprToWorlds(p : Expr) : Int {
        var pe = getNumericValue( p );
        if (pe != null) {
            var t : Int = pe;
            return pe;
        }
        return 0xffffffff;
    }

    public static function stringToWorlds(s : String) : Int {
        var p : Expr = { expr: EConst(CString(s)), pos: Context.currentPos()};
        var pe = getNumericValue( p );
        if (pe != null) {
            var t : Int = pe;
            return pe;
        }
        return 0xffffffff;
    }

    public static function getNumericValue( e : Expr ) : Dynamic {
        switch(e.expr) {
            case EConst(c):
                switch(c) {
                    case CInt(v):
                        return Std.parseInt(v);
                    case CFloat(f):
                        return Std.parseFloat(f);
                    case CString(s, kind):
//                            var x = macro $i{s};
//                          trace('x = ${x}');
                        return getNumericValue(Context.parse(s, Context.currentPos()) );
                    case CIdent(s):
                        return s;
                    default:
                }
            case EField( e, f ):
                var path = Types.asTypePath(getNumericValue(e));
                var ct = Types.asComplexType( getNumericValue(e));
                var tt = ComplexTypeTools.toType(ct);
                var c = TypeTools.getClass(tt);
                var cf = TypeTools.findField(c,f, true );
                var ce = Context.getTypedExpr( cf.expr() );
                return getNumericValue( ce );
            case EBinop(op, e1, e2) :
                var a = getNumericValue(e1);
                var b = getNumericValue(e2);
                if (a != null && b != null)
                    switch(op) {
                        case OpShl: return getNumericValue(e1) << getNumericValue(e2);
                        case OpShr: return getNumericValue(e1) >> getNumericValue(e2);
                        case OpAdd: return getNumericValue(e1) + getNumericValue(e2);
                        case OpMult: return getNumericValue(e1) * getNumericValue(e2);
                        case OpOr: return getNumericValue(e1) | getNumericValue(e2);
                        case OpAnd: return getNumericValue(e1) & getNumericValue(e2);

                        default: trace('Unknown op: ${op}');
                    }
                
            default:
                trace('Unknown expr: ${e.expr}');
        }
        return null;
    }
    
}
#end
