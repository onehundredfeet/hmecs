package ecs.core.macro;

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

using tink.MacroApi;
using haxe.macro.Context;
using Lambda;

/**
 * ...
 * @author https://github.com/deepcake
 */
@:final
@:dce
class MacroTools {
	public static function ffun(?meta:Metadata, ?access:Array<Access>, name:String, ?args:Array<FunctionArg>, ?ret:ComplexType, ?body:Expr,
			pos:Position):Field {
		return {
			meta: meta != null ? meta : [],
			name: name,
			access: access != null ? access : [],
			kind: FFun({
				args: args != null ? args : [],
				expr: body != null ? body : macro {},
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

	/**
		Returns a type corresponding to `c`.

		If `c` is null, the result is null.
	**/
	static public function mtToType(c:ComplexType):Null<haxe.macro.Type> {
		if (c == null)
			return null;

		try {
			return Context.resolveType(c, Context.currentPos());
		} catch (e) {
			switch (c) {
				case TPath(p):
					throw 'Could not resolve type ${p}';
				default:
					throw 'Could not resolve type ${c}';
			}
		}
	}

	public static function followComplexType(ct:ComplexType):ComplexType {
		return mtToType(ct).follow().toComplexType();
	}

	public static function followName(ct:ComplexType):String {
		return new Printer().printComplexType(followComplexType(ct));
	}

	public static function parseClassName(e:Expr) {
		return switch (e.expr) {
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
					(t.sub != null ? t.sub : t.name)
						+ ((t.params != null && t.params.length > 0) ? '<' + t.params.map(typeParamName.bind(_, typeValidShortName)).join(',') + '>' : '');
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
					(t.pack.length > 0 ? t.pack.map(capitalize).join('') : '')
						+ t.name
						+ (t.sub != null ? t.sub : '')
						+ ((t.params != null && t.params.length > 0) ? t.params.map(typeParamName.bind(_, typeFullName)).join('') : '');
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

	static var WORLD_META = ['worlds', 'world', 'wd', ":worlds", ":world"];

	public static function metaFieldToWorlds(f:Field):Int {
		var worldData = f.meta.filter(function(m) return WORLD_META.contains(m.name));
		if (worldData != null && worldData.length > 0) {
			var wd = worldData[0];
			if (wd.params.length > 0) {
				var p:Expr = wd.params[0];
				var pe = getNumericValue(p);
				if (pe != null) {
					var t:Int = pe;
					return pe;
				}
			}
		}
		return 0xffffffff;
	}

	public static function exprToWorlds(p:Expr):Int {
		var pe = getNumericValue(p);
		if (pe != null) {
			var t:Int = pe;
			return pe;
		}
		return 0xffffffff;
	}

	public static function stringToWorlds(s:String):Int {
		var p:Expr = {expr: EConst(CString(s)), pos: Context.currentPos()};
		var pe = getNumericValue(p);
		if (pe != null) {
			var t:Int = pe;
			return pe;
		}
		return 0xffffffff;
	}

	public static function getLocalField(n:String):Expr {
		var cf = TypeTools.findField(Context.getLocalClass().get(), n, true);
		if (cf == null)
			cf = TypeTools.findField(Context.getLocalClass().get(), n, false);
		if (cf == null) {
			for (f in Context.getBuildFields()) {
				if (f.name == n)
					switch (f.kind) {
						case FVar(t, e):
							return e;
						default:
							return null;
					}
			}		
		}
		if (cf == null) {
			return null;
		}

		return Context.getTypedExpr(cf.expr());
	}

	public static function getNumericValueStr( s:String) :Dynamic {
		if (s.indexOf(".") >= 0) {
			var splits = s.split(".");
			var f = splits.pop();
			var tps = splits.join(".");

			var tp = Types.asComplexType(tps);
			if (tp != null) {
				return getNumericValue({expr: EField({expr:EConst(CIdent(tps)), pos:Context.currentPos()}, f), pos: Context.currentPos()});
			}
			
			throw 'TP ${tps} . ${f}';
		}
		var lf = getLocalField(s);
		if (lf != null) {
			return getNumericValue(lf);
		}
		return null;
	}
	public static function getNumericValue(e:Expr):Dynamic {
		switch (e.expr) {
			case EConst(c):
				switch (c) {
					case CInt(v):
						return Std.parseInt(v);
					case CFloat(f):
						return Std.parseFloat(f);
					case CString(s, kind):
						var v = getNumericValueStr(s);
						if (v == null) throw 'Could not find string id ${s}';
						return v;
					case CIdent(s):
						var v = getNumericValueStr(s);
						if (v == null) throw 'Could not find id ${s}';
						return v;
					default:
				}
			case EField(ee, f):

				var path = parseClassName(ee);
				var ct = Types.asComplexType(path);
				if (ct == null)	{
					Context.error ('Type not found ${path}', Context.currentPos());
					return 0.;
				}
				var tt = ComplexTypeTools.toType(ct);
				var c = TypeTools.getClass(tt);
				if (c == null)	{
					Context.error ('Type not a class ${path}', Context.currentPos());
					return 0.;
				}
				var cf = TypeTools.findField(c, f, true);
				if (cf == null)
					cf = TypeTools.findField(c, f, false);
				if (cf != null) {
					var ce = Context.getTypedExpr(cf.expr());
					return getNumericValue(ce);
				}
				throw 'Could not find field ${f} in ${path}';

				
			case EBinop(op, e1, e2):
				var a = getNumericValue(e1);
				var b = getNumericValue(e2);
				if (a != null && b != null)
					switch (op) {
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


	public static function getStringValue(e:Expr):String {
		var str = e.getString();
		if (str.isSuccess()) return str.sure();
		switch (e.expr) {
			case EConst(c):
				switch(c) {
					case CString(s, kind): return s;
					case CIdent(s): return s;
					case CFloat(f, s): return f;
					case CInt(v, s): return v;
					default:
				}
			default:
		}
		return null;
	}
	public static function exprOfClassToTypePath(e:ExprOf<Class<Any>>):TypePath {
		var x = followComplexType(parseClassName(e).getType().toComplexType());
		// trace("tpath: " + x);
		switch (x) {
			case TPath(p):
				return p;
			default:
		}
		return null;
	}

	public static function constructExpr( tp : TypePath, ?position : Position ) {
		return {expr: ENew(tp, []), pos: (position == null) ? Context.currentPos() : position};
	}

	public static function pack( t : haxe.macro.Type ) : Array<String> {
		var c = TypeTools.getClass(t);
		if (c != null) return c.pack;

		
		switch(t) {
			case TAbstract(at, params): Context.error('No abstract component support for ${t.getName()}', Context.currentPos());
			default:
		}

		Context.error('Unknown component type', Context.currentPos());
		return [];
	}

	public static function modulePath( tp : TypePath ) {
		return (tp.pack.length > 0) ? tp.pack.join('.') + '.' + tp.name : tp.name;
	}
}

class ComplexTools {
	public static function modulePath( ct : ComplexType ) {
		var tp = switch(ct) {
			case TPath(p): p;
			default: Context.error("Type must have a path", Context.currentPos());
		}

		return (tp.pack.length > 0) ? tp.pack.join('.') + '.' + tp.name : tp.name;
	}
}
#end
