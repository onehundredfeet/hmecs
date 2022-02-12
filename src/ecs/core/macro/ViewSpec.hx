package ecs.core.macro;


#if macro
import haxe.macro.Printer;
import tink.core.Ref;
import ecs.core.macro.MacroTools.*;
import ecs.core.macro.ComponentBuilder.*;
import ecs.core.macro.ViewsOfComponentBuilder.*;
import haxe.macro.Expr;
import haxe.macro.Type.ClassField;
import haxe.macro.Type.ModuleType;

using ecs.core.macro.MacroTools;
using haxe.macro.ComplexTypeTools;
using haxe.macro.Context;
using Lambda;
using haxe.ds.ArraySort;
using tink.MacroApi;

typedef ViewTypeRef = {
    ct : ComplexType,
    ex : Bool,
    name : String,
    lcname: String
}

class ViewSpec {
    function new() {}
	static function compareViewTypes(aRef:ViewTypeRef, bRef:ViewTypeRef):Int {
		return (aRef.lcname < bRef.lcname) ? -1 : (aRef.lcname > bRef.lcname) ? 1 : 0;
	}

    static function notNull<T>(e:Null<T>) return e != null;

	public var name:String;
	public var worlds:Int;
	public var includes:Array<ViewTypeRef> = [];
	public var excludes:Array<ViewTypeRef> = [];
    public var needsEntity: Bool;
    public var needsDT : Bool;

    public function clone() {
        var c = new ViewSpec();
        c.name = name;
        c.worlds = worlds;
        c.needsDT = needsDT;
        c.needsEntity = needsEntity;
        c.includes = includes.copy();
        c.excludes = excludes.copy();
        return c;
    }
    function addArg(a:FunctionArg) : ViewTypeRef {
        var mm = a.meta.toMap();
        var ct = a.type.followComplexType();

        var x : ViewTypeRef = switch (ct) {
            case macro:StdTypes.Float : needsDT = true; null;
            case macro:StdTypes.Int : null;
            case macro:ecs.Entity : needsEntity = true; null;
            default: 
                var localA = mm.get(":local");
                if (localA == null) {
                    var vt = { ct: ct, ex: false, name:ct.typeFullName(), lcname: ct.typeFullName().toLowerCase() };
                    includes.push(vt);
    
                    vt;
                }
                else null;
        }

        return x;
    }

    public static function getExcludesFromField( field:Field ) {
        var mm = field.meta.toMap();

        var excludes = [];
        if (mm.exists(":not")) {
            var exs = mm.get(":not");
            for (ex in exs) {
                for (te in ex) {
                    var tn = te.getStringValue();
                    var ct : ComplexType = TPath(exprOfClassToTypePath(cast te));
                    ct = ct.followComplexType();

                    var vt = { ct: ct, ex: true, name:ct.typeFullName(), lcname: ct.typeFullName().toLowerCase(), fun:null, local : null  };
                    excludes.push(vt);
                }
            }    
        }
        excludes.sort( compareViewTypes );
        return excludes;
    }
	public static function fromField(field:Field, func:Function) : ViewSpec{
        var vi = new ViewSpec();

		var components = func.args.map(vi.addArg).filter(notNull);
		vi.worlds = metaFieldToWorlds(field);

        vi.includes.sort( compareViewTypes );
        vi.excludes = getExcludesFromField( field );

        vi.generateName();
        return vi;
	}

    public static function fromVar( field:Field, t : haxe.macro.Type ) : ViewSpec {
        var vs = fromViewType( t );
        vs.worlds = metaFieldToWorlds(field);
        vs.excludes = getExcludesFromField( field );
        vs.generateName();
        trace ('From var ${vs.name}');
        return vs;
    }

    public static function fromViewType(t : haxe.macro.Type ) : ViewSpec {

        
        return switch(t) {
            case TInst(c, types):
                if (c.get().name != "View") {
                    Context.warning('View type ${c.get().name} should likely be View<T>', Context.currentPos());
                }

                var vi = new ViewSpec();
                vi.includes = types.map(function(t)  {
                    var ct = t.follow().toComplexType();
                    var vt = { ct: ct, ex: false, name:ct.typeFullName(), lcname: ct.typeFullName().toLowerCase() };
                    return vt;
                });
                vi.includes.sort( compareViewTypes );
                vi.excludes = [];
                vi.worlds = 0xffffffff;
                vi.needsEntity = false;
                vi.needsDT = false;
                vi.generateName();
                vi;
            default:
                throw 'Not implemented on ${Context.getLocalClass().get().name}  ${t} ';
        };
    }
    #if oldy
    public static function parseComponents(type:haxe.macro.Type) : ViewSpec{
		return switch (type) {
			case TInst(_, params = [x = TType(_, _) | TAnonymous(_) | TFun(_, _)]) if (params.length == 1):
				parseComponents(x);

			case TType(_.get() => {type: x}, []):
				parseComponents(x);

			case TAnonymous(_.get() => p):
                throw "not implemented";
//				p.fields.map(function(f) return {cls: f.type.follow().toComplexType()});
			case TFun(args, ret):
                throw "not implemented";
                /*
				args.map(function(a) return a.t.follow().toComplexType())
					.concat([ret.follow().toComplexType()])
					.filter(function(ct) {
						return switch (ct) {
							case(macro:StdTypes.Void): false;
							default: true;
						}
					})
					.map(function(ct) return {cls: ct});
                    */
			case TInst(c, types):

				types.map(function(t) return t.follow().toComplexType()).map(function(ct) return {cls: ct});

			case x:
				Context.error('Unexpected Type Param: $x', Context.currentPos());
		}
	}
    #end


    /*
    
    */
	public static function fromExplicit() {}

	public function generateName() {
		name = 'ViewOf_'
			+ StringTools.hex(worlds, 8)
			+ "_i_"
			+ includes.map((x) -> x.name).join('_')
			+ "_e_"
			+ excludes.map((x) -> x.name).join('_');
		return name;
	}
}

#end