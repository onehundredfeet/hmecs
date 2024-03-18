package ecs.core.macro;

#if macro
import haxe.macro.Printer;
import haxe.macro.Expr;



import ecs.core.macro.MacroTools.*;

using StringTools;
using Lambda;
using ecs.core.macro.Extensions;

import haxe.macro.Context;

using haxe.macro.TypeTools;

class PoolBuilder {
	static var _printer:Printer = new Printer();

	// Sorry this is brutally messy, it took a while to work through the edge cases
	// USE THE IPoolable interface please
	public static function arrayPool() {
		var fields = Context.getBuildFields();
		var lt = Context.getLocalType().follow();
		var ct = lt.toComplexType();
		switch (lt) {
			case TInst(t, params):
				switch (t.get().kind) {
					case KAbstractImpl(a):
						if (a.get().params.length > 0)
							throw 'Pools do not support abstract types with parameters on ${ct.toString()}';
						ct = a.get().name.asComplexType();
					default:
				}
			default:
		}

		// check to see if this is the start of the pool implementation
		var classTypeRef = Context.getLocalClass();
		var poolRoot = false;
		if (classTypeRef != null) {
			var classType = classTypeRef.get();
			for (i in classType.interfaces) {
				var it = i.t.get();
				if (it.name == "IPoolable") {
					poolRoot = true;
					break;
				}
			}
			if (!poolRoot) {
				poolRoot = true;
				var sc = classType.superClass;
				while (sc != null) {
					var st = sc.t.get();
					for (i in st.interfaces) {
						var it = i.t.get();
						if (it.name == "IPoolable") {
							poolRoot = false;
							break;
						}
					}
					if (!poolRoot) {
						break;
					}
					sc = st.superClass;
				}
			}
		}

		// Create pool static var
		{
			var atp = tpath([], "Array", [TPType(ct)]);
			var at = TPath(atp);
			var atalloc = constructExpr(atp);
			fields.push(fvar(null, [AStatic], "__pool", at, atalloc, Context.currentPos()));
		}
		// Rent
		{
			var tp = ct.toString().asTypePath();
			var factoryField = fields.find((x) -> x.meta.toMap().exists(":pool_factory"));
			var newCall = factoryField != null ? macro $i{factoryField.name}() : macro new $tp();
			var rentCalls = fields.filter((x) -> x.meta.toMap().exists(":pool_rent")).map((x) -> 
			switch(x.kind) {
				case FFun(fun): 
					var ne = x.name;
					var ve = macro x;
					macro $ve.$ne();
				default: null;				
			}).filter((x)-> x != null);

			var allocBody = macro {
				var x = (__pool.length == 0) ? $newCall : __pool.pop();
				$b{rentCalls}
				return x;
			}

			var access = [APublic, AStatic, AInline];
			fields.push(ffun(null, access, "rent", null, ct, allocBody, Context.currentPos()));
		}

		// Retire
		{
			var retireCalls = fields.filter((x) -> x.meta.toMap().exists(":pool_retire")).map((x) -> 
			switch(x.kind) {
				case FFun(fun):   macro $i{x.name}();
				default: null;				
			}).filter((x)-> x != null);
			retireCalls.push(macro __pool.push(this));
			var access = [APublic];
			if (!poolRoot) {
				access.push(AOverride);
			}
			fields.push(ffun(null, access, "retire", [], null, macro $b{retireCalls}, Context.currentPos()));
		}

		/*
		var cb = new ClassBuilder(fields);

		// In the case it doesn't already have a constructor, make a private default one
		if (!cb.hasConstructor() && !fields.exists((x) -> x.name == "_new")) {
			var constructor = cb.getConstructor();
			constructor.isPublic = false;
			constructor.publish();
		}

		return cb.export();
		*/
		return fields;
	}

	public static function linkedPool(debug:Bool = false) {
		var fields = Context.getBuildFields();

		var ct = Context.getLocalType().toComplexType();

		var body = macro {};
		fields.push(ffun(null, [APublic, AStatic, AInline], "rent", null, ct, body, Context.currentPos()));

		fields.push(ffun(null, [APublic, AInline], "retire", [{name: "p", type: ct}], null, body, Context.currentPos()));

		return fields;
	}
}
#end
