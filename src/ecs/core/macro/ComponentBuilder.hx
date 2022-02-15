package ecs.core.macro;

#if macro
import ecs.core.macro.MacroTools.*;
import haxe.macro.Type;
import haxe.macro.Printer;
import haxe.macro.Expr;

using ecs.core.macro.MacroTools;
using Lambda;
using tink.MacroApi;
using haxe.macro.ComplexTypeTools;
using haxe.macro.TypeTools;
using haxe.macro.Context;
using haxe.ds.ArraySort;

typedef MetaMap = haxe.ds.Map<String, Array<Array<Expr>>>;

@:enum abstract StorageType(Int) from Int to Int {
	var FAST = 0; // An array the length of all entities, with non-null meaning membership
	var COMPACT = 1; // A map from entity to members
	var SINGLETON = 2; // A single reference with a known entity owner
	var TAG = 3; // An bitfield the length of all entities, with ON | OFF meaning membership

	//  var GLOBAL = 4;     // Exists on every entity
	//  var TRANSIENT = 5;  // Automatically removed every tick
	//  var NONE = 6; 		// This class is not allowed to be used as a component
	public static function getStorageType(mm:MetaMap) {
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
@:persistent var createdModule = false;
final modulePrefix = "__ecs__storage";

function getModulePath():String {
	if (!createdModule) {
		Context.defineModule(modulePrefix, []);
	}
	return modulePrefix;
}

class StorageInfo {
	public static final STORAGE_NAMESPACE = "ecs.storage";

	static function getPooled(mm:MetaMap) {
		var bb = mm.get(":build");

		if (bb != null) {
			for (b in bb) {
				switch (b[0].expr) {
					case ECall(e, p):
						switch (e.expr) {
							case EField(fe, field):
								if (fe.toString() == "ecs.core.macro.PoolBuilder") {
									return true;
								}
							default:
						}
					default:
				}
			}
		}
		return false;
	}

	public function new(ct:ComplexType, i:Int) {
		// trace ('Generating storage for ${ct.toString()}');
		givenCT = ct;
		followedCT = ct.followComplexType();
		followedT = followedCT.toTypeOrNull(Context.currentPos());
		if (followedT == null) {
			Context.error('Could not find type for ${ct}', Context.currentPos());
		}
		followedClass = null;
		try {
			followedClass = followedT.getClass();
		} catch (e) {
			switch (followedT) {
				case TAbstract(at, params):
					var x = at.get().impl;
					if (x != null) {
						followedClass = x.get();
					} else {
						Context.warning('abstract not implemented ${followedCT.toString()}', Context.currentPos());
					}
				default:
					Context.warning('Couldn\'t find class ${followedCT.toString()}', Context.currentPos());
			}
		}

		followedMeta = followedT.getMeta().flatMap((x) -> x.get()).toMap();

		var rt = followedT.followWithAbstracts();

		emptyExpr = switch (rt) {
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
		storageType = StorageType.getStorageType(followedMeta);
		//		isPooled = getPooled(followedMeta);
		isPooled = false;
		var tp = (switch (storageType) {
			case FAST: tpath([], "Array", [TPType(followedCT)]);
			case COMPACT: tpath(["haxe", "ds"], "IntMap", [TPType(followedCT)]);
			case SINGLETON: followedCT.toString().asTypePath();
			case TAG: tpath([], "Array", [TPType(followedCT)]); // TODO [RC] - Optimize tag path
		});

		storageCT = TPath(tp);

		containerTypeName = 'StorageOf' + fullName;
		containerFullName = STORAGE_NAMESPACE + "." + containerTypeName;

		containerFullNameExpr = containerFullName.asTypeIdent(Context.currentPos());
		// trace ('Container name ${containerFullName}');
		//		containerTypeNameExpr = macro $i{containerTypeName};
		componentIndex = i;

		/*
			var tc = TypeTools.getClass(followedT);
			var moduleDependecy = null;
			if (tc != null) {
				def.pack = followedT.pack();

				trace('Pack is ${def.pack} for ${givenCT.toString()}');
			}
			else {
				Context.error("Component is not a class.", Context.currentPos());
			}
		 */

		// def.
 
		//		Context.registerModuleDependency()
		containerCT = containerFullName.asComplexType();
		containerType = containerCT.toTypeOrNull(Context.currentPos());

		if (containerType == null) {
			var existsExpr = getExistsExpr(macro id);
			var removeExpr = getRemoveExpr(macro id);

			var def = (storageType == SINGLETON) ? macro class $containerTypeName {
				public static var storage:$storageCT;
				public static var owner:Int = 0;
			} : macro class $containerTypeName {
				public static var storage:$storageCT = new $tp();

				public function exists(id:Int)
					return $existsExpr;
				};

			def.defineTypeSafe(STORAGE_NAMESPACE);
		}

		if (containerType == null) {
			containerType = containerCT.toTypeOrNull(Context.currentPos());
		}
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
			case FAST: macro $containerFullNameExpr.storage[$entityExpr];
			case COMPACT: macro $containerFullNameExpr.storage.get($entityExpr);
			case SINGLETON: macro $containerFullNameExpr.storage;
			case TAG: macro $containerFullNameExpr.storage[$entityExpr];
		};
	}

	public function getExistsExpr(entityVar:Expr):Expr {
		return switch (storageType) {
			case FAST: macro $containerFullNameExpr.storage[$entityVar] != $emptyExpr;
			case COMPACT: macro $containerFullNameExpr.storage.exists($entityVar);
			case SINGLETON: macro $containerFullNameExpr.owner == $entityVar;
			case TAG: macro $containerFullNameExpr.storage[$entityVar] != $emptyExpr;
		};
	}

	public function getCacheExpr(cacheVarName:String):Expr {
		return cacheVarName.define(macro $containerFullNameExpr.storage);
	}

	public function getAddExpr(entityVarExpr:Expr, componentExpr:Expr):Expr {
		return switch (storageType) {
			case FAST: macro $containerFullNameExpr.storage[$entityVarExpr] = $componentExpr;
			case COMPACT: macro $containerFullNameExpr.storage.set($entityVarExpr, $componentExpr);
			case SINGLETON: macro {
					if ($containerFullNameExpr.owner != 0)
						throw 'Singleton already has an owner';
					$containerFullNameExpr.storage = $componentExpr;
					$containerFullNameExpr.owner = $entityVarExpr;
				};
			case TAG: macro $containerFullNameExpr.storage[$entityVarExpr] = $componentExpr;
		};
	}

	public function getRemoveExpr(entityVarExpr:Expr):Expr {
		var accessExpr = switch (storageType) {
			case FAST: macro @:privateAccess $containerFullNameExpr.storage[$entityVarExpr];
			case COMPACT: macro @:privateAccess $containerFullNameExpr.storage.get($entityVarExpr);
			case SINGLETON: macro($containerFullNameExpr.owner == $entityVarExpr ? $containerFullNameExpr.storage : null);
			case TAG: macro @:privateAccess $containerFullNameExpr.storage[$entityVarExpr];
		};

		var hasExpr = getExistsExpr(entityVarExpr);
		var retireExprs = new Array<Expr>();
		var autoRetire = isPooled && !followedMeta.exists(":no_auto_retire");
		if (autoRetire) {
			retireExprs.push(macro $accessExpr.retire());
		}

		if (followedClass != null) {
			var cfs = followedClass.statics.get().concat(followedClass.fields.get());

			for (cf in cfs) {
				if (cf.meta.has(":on_remove") && cf.kind.match(FMethod(_))) {
					var fname = $i{cf.name};
					retireExprs.push(macro @:privateAccess $accessExpr.$fname());
				}
			}
		}

		return switch (storageType) {
			case FAST: macro if ($hasExpr) {
					$b{retireExprs} @:privateAccess $containerFullNameExpr.storage[$entityVarExpr] = $emptyExpr;
				}
			case COMPACT: macro if ($hasExpr) {
					$b{retireExprs} @:privateAccess $containerFullNameExpr.storage.remove($entityVarExpr);
				}
			case SINGLETON: macro if ($hasExpr) {
					$b{retireExprs} $containerFullNameExpr.storage = $emptyExpr;
					$containerFullNameExpr.owner = 0;
				}
			case TAG: macro if ($hasExpr) {
					$b{retireExprs} @:privateAccess $containerFullNameExpr.storage[$entityVarExpr] = $emptyExpr;
				}
		};
	}

	public final givenCT:ComplexType;
	public final followedT:haxe.macro.Type;
	public final followedCT:ComplexType;
	public final followedMeta:MetaMap;
	public final followedClass:ClassType;
	public final storageType:StorageType;
	public final storageCT:ComplexType;
	public final componentIndex:Int;
	public final fullName:String;
	public final containerCT:ComplexType;
	public final containerType:haxe.macro.Type;
	public final containerTypeName:String;
	public final containerFullName:String;
	public final containerFullNameExpr:Expr;
	public final emptyExpr:Expr;
	public final isPooled:Bool;
}

class ComponentBuilder {
	static var componentIndex = -1;
	static var componentContainerTypeCache = new Map<String, StorageInfo>();

	public static function containerNames() {
		return componentContainerTypeCache.keys();
	}

	public static function getComponentContainerInfoByName(s:String) {
		return componentContainerTypeCache[s];
	}

	public static function getComponentContainerInfo(componentComplexType:ComplexType):StorageInfo {
		var name = componentComplexType.followName();

		var info = componentContainerTypeCache.get(name);
		if (info != null) {
			return info;
		}

		info = new StorageInfo(componentComplexType, ++componentIndex);
		componentContainerTypeCache[name] = info;

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
