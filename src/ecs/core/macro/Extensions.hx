package ecs.core.macro;

// Tiny selection of tink_macro to avoid dependency
// https://github.com/haxetink/tink_macro
#if macro
import haxe.macro.Expr;
import haxe.macro.MacroStringTools;
import haxe.macro.Context;
import haxe.macro.Printer;
import haxe.macro.Type;
import haxe.macro.TypeTools;

class Extensions {
	static var _printer:Printer;

	inline static function printer():Printer {
		if (_printer == null)
			_printer = new Printer();
		return _printer;
	}

	static public function toString(t:ComplexType)
		return printer().printComplexType(t);

	static public inline function sanitize(pos:Position)
		return if (pos == null) Context.currentPos(); else pos;

	static public inline function at(e:ExprDef, ?pos:Position)
		return {
			expr: e,
			pos: sanitize(pos)
		};

	static public function asTypePath(s:String, ?params):TypePath {
		var parts = s.split('.');
		var name = parts.pop(), sub = null;
		if (parts.length > 0 && parts[parts.length - 1].charCodeAt(0) < 0x5B) {
			sub = name;
			name = parts.pop();
			if (sub == name)
				sub = null;
		}
		return {
			name: name,
			pack: parts,
			params: params == null ? [] : params,
			sub: sub
		};
	}

	static public inline function asComplexType(s:String, ?params)
		return TPath(asTypePath(s, params));

	static public inline function toMBlock(exprs:Array<Expr>, ?pos)
		return at(EBlock(exprs), pos);

	static public inline function toBlock(exprs:Iterable<Expr>, ?pos)
		return toMBlock(Lambda.array(exprs), pos);

	static public inline function binOp(e1:Expr, e2, op, ?pos)
		return at(EBinop(op, e1, e2), pos);

	static public inline function assign(target:Expr, value:Expr, ?op:Binop, ?pos:Position)
		return binOp(target, value, op == null ? OpAssign : OpAssignOp(op), pos);

	static public inline function field(x:Expr, member:String, ?pos):Expr {
		return at(EField(x, member), pos);
	}

	static public function isVar(field:haxe.macro.ClassField)
		return switch (field.kind) {
			case FVar(_, _): true;
			default: false;
		}

	static public function getString(e:Expr)
		return switch (e.expr) {
			case EConst(c):
				switch (c) {
					case CString(string): string;
					default: null;
				}
			default: null;
		}

	static public inline function define(name:String, ?init:Expr, ?typ:ComplexType, ?pos:Position)
		return at(EVars([{name: name, type: typ, expr: init}]), pos);

	static public function getMeta(type:Type)
		return switch type {
			case TInst(_.get().meta => m, _): [m];
			case TEnum(_.get().meta => m, _): [m];
			case TAbstract(_.get().meta => m, _): [m];
			case TType(_.get() => t, _): [t.meta].concat(getMeta(t.type));
			case TLazy(f): getMeta(f());
			default: [];
		}

		public static function isSameAbstractType( a : AbstractType, b : AbstractType ) {
			if (a == null || b == null) return false;
			if (a == b) return true;

			if (a.name != b.name) return false;
			if (a.module != b.module) return false;
			if (a.params.length != b.params.length) return false;

			for (i in 0...a.params.length) {
				if (a.params[i].name != b.params[i].name) return false;
			}

			return true;
		}

		public static function gatherMetaValueFromHierarchy(t:haxe.macro.Type, key:String):Array<Dynamic> {
			var metaValue :Array<Dynamic> = null;
			        
			switch(t) {
				case TInst(cl, _):
					metaValue = cl.get().meta.extract(key);
					if (cl.get().superClass != null) {
						metaValue = metaValue.concat(gatherMetaValueFromHierarchy(TInst(cl.get().superClass.t, null), key));
					}
				case TAbstract(a, _):
					metaValue = a.get().meta.extract( key);
					var next = haxe.macro.TypeTools.followWithAbstracts(t,true);
					if (next != null) {
						switch(next){
							case TAbstract(aa,_):
								if (isSameAbstractType(a.get(), aa.get())) {
									metaValue = [];
								} else {
									metaValue = metaValue.concat(gatherMetaValueFromHierarchy(next, key));									
								}
							default:
								metaValue = metaValue.concat(gatherMetaValueFromHierarchy(next, key));
						}
					}
					else {
						metaValue = [];
					}
				case TEnum(en, _):
					metaValue = en.get().meta.extract(key);
				case _:
					metaValue = [];
			}
			
			return metaValue;
		}

	static public function toMap(m:Metadata) {
		var ret = new Map<String, Array<Array<Expr>>>();
		if (m != null)
			for (meta in m) {
				if (!ret.exists(meta.name))
					ret.set(meta.name, []);
				ret.get(meta.name).push(meta.params);
			}
		return ret;
	}
    static public inline function toExpr(v:Dynamic, ?pos:Position)
        return Context.makeExpr(v, sanitize(pos));
}

class ExprExtensions {
	static public inline function toString(e:Expr):String
		return new haxe.macro.Printer().printExpr(e);
}
#end
