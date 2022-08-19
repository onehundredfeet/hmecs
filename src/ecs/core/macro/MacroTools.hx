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
import haxe.macro.Type;

using tink.MacroApi;
using haxe.macro.Context;
using Lambda;

/**
 * ...
 * @author https://github.com/deepcake
 */
@:final
// @:dce
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

		#if false
		var x = c.toType(Context.currentPos());

		if (x.isSuccess()) {
			return x.sure();
		}
		#else
		try {
			return Context.resolveType(c, Context.currentPos());
		} catch (e:Dynamic) {
			if (Std.isOfType(e, String)) {
				return null;
			}
		}
		#end
		return null;
	
	}

	static public function typeNotFoundError(c:ComplexType, doThrow:Bool = false) {
		if (c == null) {
			Context.error('Type is null', Context.currentPos());
			if (doThrow)
				throw 'Type is null';
		}
		switch (c) {
			case TPath(p):
				Context.error('Could not resolve type ${p.pack}.${p.sub}.${p.name}<${p.params}>', Context.currentPos());
				if (doThrow)
					throw 'Could not resolve type ${p.pack}.${p.sub}.${p.name}<${p.params}>';
			default:
				Context.error(throw 'Could not resolve type ${c.toString()}', Context.currentPos());
				if (doThrow)
					throw 'Could not resolve type ${c.toString()}';
		}
	}

	static public function defineTypeSafe(def:TypeDefinition, namespace:String, dependency:String = "ecs.View") {
		if (namespace.length > 0) {
			def.pack = namespace.split(".");
		}
		#if false
		// Context.getLocalImports()
		Context.defineModule(namespace + "." + def.name, [def]);
		#else
		try {
		Context.defineType( def, dependency );
		}
		catch(e:Dynamic) {
			Context.warning('Error defining type ${e}', Context.currentPos());
		}
		#end
	}

	static public function toTypeOrNull(c:ComplexType, doFollow:Bool = true, pos:Position):Null<haxe.macro.Type> {
		var x:Null<haxe.macro.Type> = null;

		if (c == null) {
			Context.warning('null type', pos);
			return null;
		}

		#if false
		var yy = c.toType(pos);
		if (yy.isSuccess()) {
			x = yy.sure();
		}

		#else
		if (x == null) {
			try {
				var t = Context.getType(c.toString());

				if (t != null) {
					x = doFollow ? t.follow() : t;
					//Context.warning('Get ${x}', pos);

				}
			} catch (e:String) {}
		}

		if (x == null) {
		try {
			var t = Context.resolveType(c, pos);
			if (t != null) {
				x = doFollow ? t.follow() : t;
				//Context.warning('Resolved ${x}', pos);

			}
		} 
		catch (e:String) {}
		catch (d:Dynamic) {
		}
	}
		
		if (x == null) {
			//Context.warning('no type ${c.toString()}', pos);
		}
		#end

	return x;

		/*
			

			return x; */
	}

	public static function followComplexType(ct:ComplexType, pos):ComplexType {
		var x = toTypeOrNull(ct,true, pos);
		if (x == null) {
			Context.error('Could not find type: ${ct.toString()}', pos);
		}
		return x.toComplexType();
	}

	public static function followName(ct:ComplexType, pos):String {
		return new Printer().printComplexType(followComplexType(ct, pos));
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

	public static function typeValidShortName(ct:ComplexType, pos):String {
		return switch (followComplexType(ct, pos)) {
			case TPath(t): {
					(t.sub != null ? t.sub : t.name)
						+ ((t.params != null && t.params.length > 0) ? '<' + t.params.map(typeParamName.bind(_, (x) -> typeValidShortName(x,pos))).join(',') + '>' : '');
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

	public static function typeFullName(ct:ComplexType, pos):String {
		return switch (followComplexType(ct, pos)) {
			case TPath(t): {
					(t.pack.length > 0 ? t.pack.map(capitalize).join('') : '')
						+ t.name
						+ (t.sub != null ? t.sub : '')
						+ ((t.params != null && t.params.length > 0) ? t.params.map(typeParamName.bind(_, (x) -> typeFullName(x,pos) )).join('') : '');
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

	public static function joinFullName(types:Array<ComplexType>, sep:String, pos) {
		var typeNames = types.map((x) -> typeFullName(x,pos));
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
				var pe = getNumericValue(p, 0xffffffff, p.pos);
				return 0xffffffff;
				if (pe != null) {
					var t:Int = pe;
					return pe;
				}
			}
		}
		return 0xffffffff;
	}

	public static function exprToWorlds(p:Expr):Int {
		var pe = getNumericValue(p, 0xffffffff, p.pos);
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
				switch (f) {
					case { name: name, kind: FVar(_, e) } if(name == n):
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

	public static function getNumericValueStr(s:String, valueDefault:Dynamic, pos:Position):Dynamic {
		if (s.indexOf(".") >= 0) {
			var splits = s.split(".");
			var f = splits.pop();
			var tps = splits.join(".");

			var tp = Types.asComplexType(tps);
			if (tp != null) {
				return getNumericValue({expr: EField({expr: EConst(CIdent(tps)), pos: Context.currentPos()}, f), pos: pos}, valueDefault, pos);
			}

			throw 'TP ${tps} . ${f}';
		}
		var lf = getLocalField(s);
		if (lf != null) {
			return getNumericValue(lf, valueDefault, pos);
		}
		return null;
	}

	public static function getTypeNumericValue(typedExpr:haxe.macro.Type.TypedExpr, valueDefault:Dynamic, pos:Position):Dynamic {

		switch (typedExpr.expr) {
			case TConst(TInt(i)): return i;
			case TConst(c): Context.warning('found constant ${c}', pos);
			case TBinop(op, e1, e2):
				var a = getTypeNumericValue(e1, valueDefault, pos);
				var b = getTypeNumericValue(e2, valueDefault, pos);
				if (a != null && b != null)
					switch (op) {
						case OpShl: return getTypeNumericValue(e1, valueDefault, pos) << getTypeNumericValue(e2, valueDefault, pos);
						case OpShr: return getTypeNumericValue(e1, valueDefault, pos) >> getTypeNumericValue(e2, valueDefault, pos);
						case OpAdd: return getTypeNumericValue(e1, valueDefault, pos) + getTypeNumericValue(e2, valueDefault, pos);
						case OpMult: return getTypeNumericValue(e1, valueDefault, pos) * getTypeNumericValue(e2, valueDefault, pos);
						case OpOr: return getTypeNumericValue(e1, valueDefault, pos) | getTypeNumericValue(e2, valueDefault, pos);
						case OpAnd: return getTypeNumericValue(e1, valueDefault, pos) & getTypeNumericValue(e2, valueDefault, pos);

						default: trace('Unknown op: ${op}');
					}
			default:
		}
		return valueDefault;
	}

	public static function getNumericValue(e:Expr, valueDefault:Dynamic, pos:Position):Dynamic {
		switch (e.expr) {
			case EConst(CInt(v)):
				return Std.parseInt(v);
			case EConst(CFloat(f)):
				return Std.parseFloat(f);
			case EConst(CString(s, _)):
				var v = getNumericValueStr(s, valueDefault, pos);
				if (v == null) {
					Context.error('Could not find string id ${s}', pos);
					return valueDefault;
				}
				return v;
			case EConst(CIdent(s)):
				var v = getNumericValueStr(s, valueDefault, pos);
				if (v == null) {
					Context.error('Could not find id ${s}', pos);
					return valueDefault;
				}
				return v;

			case EField(ee, f):
				var path = parseClassName(ee);

				var ct = path.asComplexType();
				if (ct == null) {
					Context.error('getNumericValue Type not found ${path}', e.pos);
					return valueDefault;
				}
				var tt = toTypeOrNull(ct, pos);
				//				Context.warning('becomes type ${tt}', pos);
				if (tt == null) {
					Context.error('Could not resolve type ${path}', e.pos);
					return valueDefault;
				}
				var c = TypeTools.getClass(tt);

				//				Context.warning('becomes class ${c}', pos);
				if (c == null) {
					Context.error('Type not a class ${path}', e.pos);
					return valueDefault;
				}
				var cf = TypeTools.findField(c, f, true);
				if (cf == null)
					cf = TypeTools.findField(c, f, false);
				if (cf != null) {
					//					Context.warning('found classfield ${cf}', pos);
					if (cf.isVar()) {
						var cfe = cf.expr();
						if (cfe != null) {
							return getTypeNumericValue(cfe, valueDefault, pos);
						}

						return valueDefault;
					} else {
						Context.error('Only var fields are supported', Context.currentPos());
						return valueDefault;
					}
				}
				Context.error('Could not find field ${f} in ${path}', Context.currentPos());
				return valueDefault;

			case EBinop(op, e1, e2):
				var a = getNumericValue(e1, valueDefault, pos);
				var b = getNumericValue(e2, valueDefault, pos);
				if (a != null && b != null)
					switch (op) {
						case OpShl: return getNumericValue(e1, valueDefault, pos) << getNumericValue(e2, valueDefault, pos);
						case OpShr: return getNumericValue(e1, valueDefault, pos) >> getNumericValue(e2, valueDefault, pos);
						case OpAdd: return getNumericValue(e1, valueDefault, pos) + getNumericValue(e2, valueDefault, pos);
						case OpMult: return getNumericValue(e1, valueDefault, pos) * getNumericValue(e2, valueDefault, pos);
						case OpOr: return getNumericValue(e1, valueDefault, pos) | getNumericValue(e2, valueDefault, pos);
						case OpAnd: return getNumericValue(e1, valueDefault, pos) & getNumericValue(e2, valueDefault, pos);

						default: trace('Unknown op: ${op}');
					}

			default:
				Context.error('Unknown expr: ${e.expr}', pos);
		}
		return valueDefault;
	}

	public static function asTypeIdent(s:String, pos:Position):Expr {
		if (s == null || s.length == 0) {
			"Null type".error(pos);
			//			Context.errror("Null type", pos);
		}

		var chunks = s.split(".");

		if (chunks.length == 1) {
			return EConst(CIdent(chunks.pop())).at(pos);
		}

		return chunks.fold((item, result) -> EField(result, item).at(pos), EConst(CIdent(chunks.shift())).at(pos));
	}

	public static function getStringValue(e:Expr):String {
		var str = e.getString();
		if (str.isSuccess())
			return str.sure();
		switch (e.expr) {
			case EConst(CString(s, _)): return s;
			case EConst(CIdent(s)): return s;
			case EConst(CFloat(f)): return f;
			case EConst(CInt(v)): return v;
			default:
		}
		return null;
	}

	public static function constructExpr(tp:TypePath, ?position:Position) {
		return {expr: ENew(tp, []), pos: (position == null) ? Context.currentPos() : position};
	}

	public static function pack(t:haxe.macro.Type):Array<String> {
		var c = TypeTools.getClass(t);
		if (c != null)
			return c.pack;

		switch (t) {
			case TAbstract(_, _):
				Context.error('No abstract component support for ${t.getName()}', Context.currentPos());
			default:
		}

		Context.error('Unknown component type', Context.currentPos());
		return [];
	}

	public static function modulePath(tp:TypePath) {
		return (tp.pack.length > 0) ? tp.pack.join('.') + '.' + tp.name : tp.name;
	}

	public static function exprOfClassToCT(e:Expr, ns:String = null, pos:Position):ComplexType {
		var x = parseClassName(e);

		if (ns != null && x.indexOf(ns) != 0) {
			x = ns + "." + x;
		}
		return toTypeOrNull(x.asComplexType(), pos).follow().toComplexType();
	}

	public static function exprOfClassToFullTypeName(e:Expr, ns:String = null, pos:Position):String {
		var x = exprOfClassToCT(e, ns, pos);

		return typeFullName(x, pos);
	}

	public static function exprOfClassToTypePath(e:Expr, ns:String = null, pos:Position):TypePath {
		var x = exprOfClassToCT(e, ns, pos);

		// trace("tpath: " + x);
		switch (x) {
			case TPath(p):
				return p;
			default:
		}
		return null;
	}
}

class ComplexTools {
	public static function modulePath(ct:ComplexType) {
		var tp = switch (ct) {
			case TPath(p): p;
			default: Context.error("Type must have a path", Context.currentPos());
		}

		return (tp.pack.length > 0) ? tp.pack.join('.') + '.' + tp.name : tp.name;
	}
}
#end
