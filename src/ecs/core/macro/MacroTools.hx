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

using ecs.core.macro.Extensions;
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

	public static function arg(name:String, type:ComplexType, ?opt = false, ?value:Expr = null):FunctionArg {
		return {
			name: name,
			type: type,
			opt: opt,
			value: value
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
			Context.defineType(def, dependency);
		} catch (e:Dynamic) {
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
					// Context.warning('Get ${x}', pos);
				}
			} catch (e:String) {}
		}

		if (x == null) {
			try {
				var t = Context.resolveType(c, pos);
				if (t != null) {
					x = doFollow ? t.follow() : t;
					// Context.warning('Resolved ${x}', pos);
				}
			} catch (e:String) {} catch (d:Dynamic) {}
		}

		if (x == null) {
			// Context.warning('no type ${c.toString()}', pos);
		}
		#end

		return x;

		/*


			return x; */
	}

	public static function followComplexType(ct:ComplexType, pos):ComplexType {
		var x = toTypeOrNull(ct, true, pos);
		if (x == null) {
			Context.fatalError('Could not find type: ${ct.toString()}', pos);
		}
		return x.toComplexType();
	}

	public static function followName(ct:ComplexType, pos):String {
		var x = followComplexType(ct, pos);
		if (x == null) {
			Context.fatalError('Could not follow type: ${ct.toString()}', pos);
		}
		return new Printer().printComplexType(x);
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
						+ ((t.params != null && t.params.length > 0) ? '<'
							+ t.params.map(typeParamName.bind(_, (x) -> typeValidShortName(x, pos))).join(',')
							+ '>' : '');
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
						+ ((t.params != null && t.params.length > 0) ? t.params.map(typeParamName.bind(_, (x) -> typeFullName(x, pos))).join('') : '');
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
		var typeNames = types.map((x) -> typeFullName(x, pos));
		typeNames.sort(compareStrings);
		return typeNames.join(sep);
	}

	static var WORLD_META = ['worlds', 'world', 'wd', ":worlds", ":world"];

	public static function metaFieldToWorlds(f:Field):Int {
		//		var mmap = f.meta.toMap();

		var worldData = f.meta.filter(function(m) return WORLD_META.contains(m.name));
		if (worldData != null && worldData.length > 0) {
			var wd = worldData[0];
			var worlds = 0;

			if (wd.params.length > 0) {
				var p:Expr = wd.params[0];
				for (w in wd.params) {
					var pe = getNumericValue(w, null, p.pos);
					if (pe == null) {
						Context.error('Invalid world value: ${w}', p.pos);
						return 0;
					}
					var mask:Int = cast(pe, Int);
					worlds |= mask;
				}
			}
			return worlds;
		}
		return 0xffffffff;
	}

	/*
		public static function exprToWorlds(p:Expr):Int {
			var pe = getNumericValue(p, 0xffffffff, p.pos);
			if (pe != null) {
				var t:Int = pe;
				return pe;
			}
			return 0xffffffff;
		}
	 */
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

	public static function getNumericValueStr(s:String, valueDefault:Dynamic, pos:Position):Dynamic {
		if (s.indexOf(".") >= 0) {
			var splits = s.split(".");
			var f = splits.pop();
			var tps = splits.join(".");

			var tp = tps.asComplexType();
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
			case TConst(c):
				switch (c) {
					case TInt(i): return i;
					default: Context.warning('found constant ${c}', pos);
				}
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
			case EConst(c):
				switch (c) {
					case CInt(v):
						return Std.parseInt(v);
					case CFloat(f):
						return Std.parseFloat(f);
					case CString(s, kind):
						var v = getNumericValueStr(s, valueDefault, pos);
						if (v == null) {
							Context.error('Could not find string id ${s}', pos);
							return valueDefault;
						}
						return v;
					case CIdent(s):
						var v = getNumericValueStr(s, valueDefault, pos);
						if (v == null) {
							Context.error('Could not find id ${s}', pos);
							return valueDefault;
						}
						return v;
					default:
				}
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
				var cf:ClassField = TypeTools.findField(c, f, true);
				if (cf == null)
					cf = TypeTools.findField(c, f, false);
				if (cf != null) {
					//					Context.warning('found classfield ${cf}', pos);
					if (cf.isVar()) {
						var cfe = cf.expr();
						if (cfe != null) {
							return getTypeNumericValue(cfe, valueDefault, pos);
						}
						Context.error('Empty class field', Context.currentPos());
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
				Context.error('Unknown binop ${op} ${a} ${b}', Context.currentPos());
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
		if (str != null)
			return str;
		switch (e.expr) {
			case EConst(c):
				switch (c) {
					case CString(s, kind): return s;
					case CIdent(s): return s;
					case CFloat(f): return f;
					case CInt(v): return v;
					default:
				}
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
			case TAbstract(at, params):
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

	// adapted from tink macro:
	// 	The MIT License (MIT)
	// Copyright (c) 2013 Juraj Kirchheim
	// Permission is hereby granted, free of charge, to any person obtaining a copy of
	// this software and associated documentation files (the "Software"), to deal in
	// the Software without restriction, including without limitation the rights to
	// use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
	// the Software, and to permit persons to whom the Software is furnished to do so,
	// subject to the following conditions:
	// The above copyright notice and this permission notice shall be included in all
	// copies or substantial portions of the Software.
	// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
	// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
	// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
	// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
	// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

	public static function hasAccess(f:Field, a:Access) {
		if (f.access != null)
			for (x in f.access)
				if (x == a)
					return true;
		return false;
	}

	public static function changeAccess(f:Field, add:Access, remove:Access) {
		var i = 0;
		if (f.access == null)
			f.access = [];
		while (i < f.access.length) {
			var a = f.access[i];
			if (a == remove) {
				f.access.splice(i, 1);
				if (add == null)
					return;
				remove = null;
			} else {
				i++;
				if (a == add) {
					add = null;
					if (remove == null)
						return;
				}
			}
		}
		if (add != null)
			f.access.push(add);
	}

	public static function setAccess(f:Field, a:Access, isset:Bool) {
		changeAccess(f, isset ? a : null, isset ? null : a);
		return isset;
	}

	public static function setIsPublic(f:Field, param) {
		if (param == null) {
			changeAccess(f, null, APublic);
			changeAccess(f, null, APrivate);
		} else if (param)
			changeAccess(f, APublic, APrivate);
		else
			changeAccess(f, APrivate, APublic);
		return param;
	}

	static public function getValues(m:Metadata, name:String)
		return if (m == null) []; else [for (meta in m) if (meta.name == name) meta.params];

	static public function getIdent(e:Expr)
		return switch (e.expr) {
			case EConst(c):
				switch (c) {
					case CIdent(id): id;
					default: null;
				}
			default:
				null;
		}

	static var scopes = new Array<Array<Var>>();

	static function inScope<T>(a:Array<Var>, f:Void->T) {
		scopes.push(a);

		inline function leave()
			scopes.pop();
		try {
			var ret = f();
			leave();
			return ret;
		} catch (e:Dynamic) {
			leave();
			return null;
		}
	}

	static public function scoped<T>(f:Void->T)
		return inScope([], f);

	static public function inSubScope<T>(f:Void->T, a:Array<Var>)
		return inScope(switch scopes[scopes.length - 1] {
			case null: a;
			case v: v.concat(a);
		}, f);

	static public function typeof(expr:Expr, ?locals)
		return try {
			if (locals == null)
				locals = scopes[scopes.length - 1];
			if (locals != null)
				expr = [EVars(locals).at(expr.pos), expr].toMBlock(expr.pos);
			Context.typeof(expr);
		} catch (e:haxe.macro.Error) {
			null;
		} catch (e:Dynamic) {
			null;
		}

	static public inline function func(e:Expr, ?args:Array<FunctionArg>, ?ret:ComplexType, ?params, ?makeReturn = true):Function {
		return {
			args: args == null ? [] : args,
			ret: ret,
			params: params == null ? [] : params,
			expr: if (makeReturn) EReturn(e).at(e.pos) else e
		}
	}

	static public function method(name:String, ?pos, ?isPublic = true, f:Function) {
		var f:Field = {
			name: name,
			pos: if (pos == null) f.expr.pos else pos,
			kind: FFun(f)
		};
		setIsPublic(f, isPublic);
		return f;
	}

	static public function addMeta(f:Field, name, ?pos, ?params):Field {
		if (f.meta == null)
			f.meta = [];
		f.meta.push({
			name: name,
			pos: if (pos == null) f.pos else pos,
			params: if (params == null) [] else params
		});
		return f;
	}

	static public function getOverrides(f:Field)
		return hasAccess(f, AOverride);

	static public function setOverrides(f:Field, param)
		return setAccess(f, AOverride, param);

	static public inline function sanitize(pos:Position)
		return if (pos == null) Context.currentPos(); else pos;

	static public inline function at(e:ExprDef, ?pos:Position)
		return {
			expr: e,
			pos: sanitize(pos)
		};

	static public function getMeta(type:Type)
		return switch type {
			case TInst(_.get().meta => m, _): [m];
			case TEnum(_.get().meta => m, _): [m];
			case TAbstract(_.get().meta => m, _): [m];
			case TType(_.get() => t, _): [t.meta].concat(getMeta(t.type));
			case TLazy(f): getMeta(f());
			default: [];
		}
		static public function toMap(m:Metadata) {
			var ret = new Map<String,Array<Array<Expr>>>();
			if (m != null)
			  for (meta in m) {
				if (!ret.exists(meta.name))
				  ret.set(meta.name, []);
				ret.get(meta.name).push(meta.params);
			  }
			return ret;
		  }
		  static public function unifiesWith(from:Type, to:Type)
			return Context.unify(from, to);
		  static public function toString(t:ComplexType)
			return new Printer().printComplexType(t);
		  static public inline function toArg(name:String, ?t, ?opt = false, ?value = null):FunctionArg {
			return {
			  name: name,
			  opt: opt,
			  type: t,
			  value: value
			};
		  }
		  static public function asTypePath(s:String, ?params):TypePath {
			var parts = s.split('.');
			var name = parts.pop(),
			  sub = null;
			if (parts.length > 0 && parts[parts.length - 1].charCodeAt(0) < 0x5B) {
			  sub = name;
			  name = parts.pop();
			  if(sub == name) sub = null;
			}
			return {
			  name: name,
			  pack: parts,
			  params: params == null ? [] : params,
			  sub: sub
			};
		  }
		  static public function getInt(e:Expr)
			return
			  switch (e.expr) {
				case EConst(c):
				  switch (c) {
					case CInt(id): Std.parseInt(id);
					default: null;
				  }
				default: null;
			  }
			  static public inline function field(e:Expr, field, ?pos)
				return EField(e, field).at(pos);
			  static public inline function binOp(e1:Expr, e2, op, ?pos)
				return EBinop(op, e1, e2).at(pos);
			  static public inline function assign(target:Expr, value:Expr, ?op:Binop, ?pos:Position)
				return binOp(target, value, op == null ? OpAssign : OpAssignOp(op), pos);
			  static public inline function toExpr(v:Dynamic, ?pos:Position)
				return Context.makeExpr(v, pos.sanitize());
}

abstract Member(Field) from Field to Field {
	public var name(get, set):String;
	public var meta(get, set):Metadata;
	public var kind(get, set):FieldType;
	public var pos(get, set):Position;
	public var overrides(get, set):Bool;
	public var isStatic(get, set):Bool;
	public var isPublic(get, set):Null<Bool>;

	
	static public function method(name:String, ?pos, ?isPublic = true, f:Function) {
		var f:Field = {
		  name: name,
		  pos: if (pos == null) f.expr.pos else pos,
		  kind: FFun(f)
		};
		var ret:Member = f;
		ret.isPublic = isPublic;
		return ret;
	  }
	  inline function get_overrides() return hasAccess(AOverride);
	  inline function set_overrides(param) return setAccess(AOverride, param);
	  function get_isPublic() {
		if (this.access != null)    
		  for (a in this.access) 
			switch a {
			  case APublic: return true;
			  case APrivate: return false;
			  default:
			}
		return null;
	  }
	  
	  function set_isPublic(param) {
		if (param == null) {
		  changeAccess(null, APublic);
		  changeAccess(null, APrivate);
		}
		else if (param) 
		  changeAccess(APublic, APrivate);
		else 
		  changeAccess(APrivate, APublic);
		return param;
	  }
	  function changeAccess(add:Access, remove:Access) {
		var i = 0;
		if (this.access == null)
		  this.access = [];
		while (i < this.access.length) {
		  var a = this.access[i];
		  if (a == remove) {
			this.access.splice(i, 1);
			if (add == null) return;
			remove = null;
		  }
		  else {
			i++;
			if (a == add) {
			  add = null;
			  if (remove == null) return;
			}
		  }
		}
		if (add != null)
		  this.access.push(add);
	  }
	  public inline function asField():Field return this;
	  function hasAccess(a:Access) {
		if (this.access != null)
		  for (x in this.access)
			if (x == a) return true;
		return false;
	  }
	
	  function setAccess(a:Access, isset:Bool) {
		changeAccess(
		  isset ? a : null, 
		  isset ? null : a
		);
		return isset;
	  }
	  inline function get_meta() return switch this.meta {
		case null: this.meta = [];
		case v: v;
	  }
	  inline function set_meta(param) return this.meta = param;
	  inline function get_isStatic() return hasAccess(AStatic);
	  inline function set_isStatic(param) return setAccess(AStatic, param);
	  inline function get_pos() return this.pos;
	  inline function set_pos(param) return this.pos = param;
	  inline function get_kind() return this.kind;
	  inline function set_kind(param) return this.kind = param;
	  inline function get_name() return this.name;
	  inline function set_name(param) return this.name = param;
}
	// end tink macro
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
