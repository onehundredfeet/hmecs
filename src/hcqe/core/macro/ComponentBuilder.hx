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

typedef MetaMap = haxe.ds.Map<String, Array<Array<Expr>>>;

@:enum abstract StorageType(Int) from Int to Int {
	var FAST = 0;			// An array the length of all entities, with non-null meaning membership
	var COMPACT = 1;		// A map from entity to members
	var SINGLETON = 2;		// A single reference with a known entity owner
	var TAG = 3;			// An bitfield the length of all entities, with ON | OFF meaning membership

	//  var GLOBAL = 4;     // Exists on every entity
	//  var TRANSIENT = 5;  // Automatically removed every tick
	//  var NONE = 6; 		// This class is not allowed to be used as a component
	public static function getStorageType(mm :MetaMap) {
		var storageType = StorageType.FAST;


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
		followedT = followedCT.mtToType();
		if (followedT == null)
			throw('Could not find type for ${ct}');
		followedMeta = followedT.getMeta().flatMap((x) -> x.get()).toMap();

		var rt = followedT.followWithAbstracts();
		
		emptyExpr = switch(rt) {
			case TInst(t, params): macro null;
			case TAbstract(t, params):
				if (t.get().name == "Int") {
					macro 0;
				} else {
					macro null;
				}
				
			default: macro null;
		}
//		trace('Underlaying type is ${rt} with empty ${_printer.printExpr(emptyExpr)}');

//		followedMeta.exists(":empty") ? followedMeta.get(":empty")[0][0] : macro null;

		fullName = followedCT.followComplexType().typeFullName();
		storageType = StorageType.getStorageType( followedMeta);
		
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

		var def = (storageType == SINGLETON) ? macro class $containerTypeName {
			public static var storage:$storageCT;
			public static var owner:Int = 0;
		} : macro class $containerTypeName {
			public static var storage:$storageCT = new $tp ();
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
			case FAST: macro $containerTypeNameExpr.storage[$entityVar] != $emptyExpr;
			case COMPACT: macro $containerTypeNameExpr.storage.exists($entityVar);
			case SINGLETON: macro $containerTypeNameExpr.owner == $entityVar;
			case TAG: macro $containerTypeNameExpr.storage[$entityVar] != $emptyExpr;
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
					if ($containerTypeNameExpr.owner != 0)
						throw 'Singleton already has an owner';
					$containerTypeNameExpr.storage = $componentExpr;
					$containerTypeNameExpr.owner = $entityVarExpr;
				};
			case TAG: macro $containerTypeNameExpr.storage[$entityVarExpr] = $componentExpr;
		};
	}

	public function getRemoveExpr(entityVarExpr:Expr):Expr {
		return switch (storageType) {
			case FAST: macro @:privateAccess $containerTypeNameExpr.storage[$entityVarExpr] = $emptyExpr;
			case COMPACT: macro @:privateAccess $containerTypeNameExpr.storage.remove($entityVarExpr);
			case SINGLETON: macro if ($containerTypeNameExpr.owner == $entityVarExpr) {
					$containerTypeNameExpr.storage = $emptyExpr;
					$containerTypeNameExpr.owner = 0;
				}
			case TAG: macro @:privateAccess $containerTypeNameExpr.storage[$entityVarExpr] = $emptyExpr;
		};
	}


	public final givenCT:ComplexType;
	public final followedT:haxe.macro.Type;
	public final followedCT:ComplexType;
	public final followedMeta:MetaMap;
	public final storageType:StorageType;
	public final storageCT:ComplexType;
	public final componentIndex:Int;
	public final fullName:String;
	public final containerCT:ComplexType;
	public final containerType:haxe.macro.Type;
	public final containerTypeName:String;
	public final containerTypeNameExpr:Expr;
	public final emptyExpr:Expr;
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
