package hcqe.core.macro;

#if macro
import haxe.macro.Printer;
import hcqe.core.macro.MacroTools.*;
import haxe.macro.Expr.ComplexType;

using hcqe.core.macro.MacroTools;
using haxe.macro.Context;
using haxe.macro.ComplexTypeTools;
using Lambda;

import haxe.macro.Expr;

using tink.MacroApi;

@:enum abstract StorageType(Int) from Int to Int {
	var FAST = 0;
	var COMPACT = 1;
	var SINGLETON = 2;
	var TAG = 3;

	//  var GLOBAL = 4;     // Exists on every entity
    //  var TRANSIENT = 5;  // Designed to be wiped every frame

	public static function getStorageType(ct:ComplexType) {
		var storageType = StorageType.FAST;

		var t = ct.followComplexType().mtToType();
		if (t == null)
			throw('Could not find type for ${ct}');
		var mm = t.getMeta().flatMap((x) -> x.get()).toMap();
		var stma = mm.get(":storage");

		if (stma != null) {
			var stm = stma[0];
			return switch (stm[0].expr) {
				case EConst(CIdent(s)), EConst(CString(s)):
					switch (s.toUpperCase()) {
						case "FAST": FAST;
						case "COMPACT": COMPACT;
						case "SINGLETON": SINGLETON;
						case "TAG": FAST;
						default: FAST;
					}
				default: FAST;
			}
		}
		return FAST;
	}
}

var _printer = new Printer();

class StorageInfo {
	public function new(ct:ComplexType, i:Int) {
		givenCT = ct;
		followedCT = ct.followComplexType();
		fullName = followedCT.followComplexType().typeFullName();
		storageType = StorageType.getStorageType(followedCT);

		var tp = (switch (storageType) {
			case FAST: tpath([], "Array", [TPType(followedCT)]);
			case COMPACT: tpath(["haxe", "ds"], "IntMap", [TPType(followedCT)]);
			case SINGLETON: followedCT.toString().asTypePath();
			case TAG: tpath([], "Array", [TPType(followedCT)]); // TODO [RC] - Optimize tag path
		});

		storageCT = TPath(tp);

		containerTypeName = 'StorageOf' + fullName;
		containerTypeNameExpr = macro $i{containerTypeName};
		componentIndex = i;

		// TODO [RC] Figure out a way of stripping singleEntity from unnecessary classes
		var def = macro class $containerTypeName {
			public static var storage:$storageCT;
			public static var owner:Int = 0;
		};

		Context.defineType(def);

		containerCT = containerTypeName.asComplexType();
		containerType = containerCT.mtToType();
	}

	public function getGetExpr(entityExpr:Expr, cachedVarName:String = null):Expr {
		if (cachedVarName != null)
			return switch (storageType) {
				case FAST: macro $i{cachedVarName}[$entityExpr];
				case COMPACT: macro $i{cachedVarName}.get($entityExpr);
				case SINGLETON: macro $i{cachedVarName};
				case TAG: macro $i{cachedVarName}[$entityExpr];
			};
		return switch (storageType) {
			case FAST: macro $containerTypeNameExpr.storage[$entityExpr];
			case COMPACT: macro $containerTypeNameExpr.storage.get($entityExpr);
			case SINGLETON: macro $containerTypeNameExpr.storage;
			case TAG: macro $containerTypeNameExpr.storage[$entityExpr];
		};
	}

	public function getExistsExpr(entityVar:Expr):Expr {
		return switch (storageType) {
			case FAST: macro $containerTypeNameExpr.storage[$entityVar] != null;
			case COMPACT: macro $containerTypeNameExpr.storage.exists($entityVar);
			case SINGLETON: macro $containerTypeNameExpr.owner == $entityVar;
			case TAG: macro $containerTypeNameExpr.storage[$entityVar] != null;
		};
	}

	public function getCacheExpr(cacheVarName:String):Expr {
		return cacheVarName.define(macro $containerTypeNameExpr.storage);
	}

	public function getAddExpr(entityVarExpr:Expr, componentExpr:Expr):Expr {
		return switch (storageType) {
			case FAST: macro $containerTypeNameExpr.storage[$entityVarExpr] = $componentExpr;
			case COMPACT: macro $containerTypeNameExpr.storage.set($entityVarExpr, $componentExpr);
			case SINGLETON: macro { 
                if ($containerTypeNameExpr.owner != 0) throw 'Singleton already has an owner';
                $containerTypeNameExpr.storage = $componentExpr; $containerTypeNameExpr.owner = $entityVarExpr;
            };
			case TAG: macro $containerTypeNameExpr.storage[$entityVarExpr] = $componentExpr;
		};
	}

	public function getRemoveExpr(entityVarExpr:Expr):Expr {
		return switch (storageType) {
			case FAST: macro @:privateAccess $containerTypeNameExpr.storage[$entityVarExpr] = null;
			case COMPACT: macro @:privateAccess $containerTypeNameExpr.storage.remove($entityVarExpr);
			case SINGLETON: macro if ($containerTypeNameExpr.owner == $entityVarExpr) {
					$containerTypeNameExpr.storage = null;
					$containerTypeNameExpr.owner = 0;
				}
			case TAG: macro @:privateAccess $containerTypeNameExpr.storage[$entityVarExpr] = null;
		};
	}

	public function getAllocAddExpr(entityVarExpr:Expr):Expr {
		throw "Unimplemented";
		/*
			var sid = EConst(CIdent(storageCT.toString())).at();

			return switch(storageType) {
				case FAST:  macro $sid[ $entityVarExpr ];
				case COMPACT: macro $sid.map.get($entityVarExpr);
				case SINGLETON: macro $sid.instance;
				case TAG: macro $sid[ $entityVarExpr];
			};

			var containerName = (c.parseClassName().getType().follow().toComplexType()).getComponentContainer().followName();
			var alloc = {expr: ENew(exprOfClassToTypePath(c), []), pos:Context.currentPos()};
			return macro @:privateAccess $i{ containerName }.inst().add(__entity__, $alloc);
		 */
	}

	public final givenCT:ComplexType;
	public final followedCT:ComplexType;
	public final storageType:StorageType;
	public final storageCT:ComplexType;
	public final componentIndex:Int;
	public final fullName:String;
	public final containerCT:ComplexType;
	public final containerType:haxe.macro.Type;
	public final containerTypeName:String;
	public final containerTypeNameExpr:Expr;
}

class ComponentBuilder {
	static var componentIndex = -1;
	static var componentContainerTypeCache = new Map<String, StorageInfo>();

	public static function getComponentContainerInfo(componentComplexType:ComplexType):StorageInfo {
		var name = componentComplexType.followName();
		var info = componentContainerTypeCache.get(name);
		if (info != null) {
			Report.gen();
			return info;
		}

		info = new StorageInfo(componentComplexType, ++componentIndex);
		componentContainerTypeCache[name] = info;

		Report.gen();
		return info;
	}

	public static function getLookup(ct:ComplexType, entityVarName:Expr):Expr {
		return getComponentContainerInfo(ct).getGetExpr(entityVarName);
	}

	public static function getComponentId(componentComplexType:ComplexType):Int {
		return getComponentContainerInfo(componentComplexType).componentIndex;
	}
}
#end
