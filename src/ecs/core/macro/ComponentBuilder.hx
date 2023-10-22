package ecs.core.macro;

import ecs.utils.Const;
#if macro
import ecs.core.macro.MacroTools.*;
import haxe.macro.Type;
import haxe.macro.Printer;
import haxe.macro.Expr;
import haxe.display.Display;
using ecs.core.macro.MacroTools;
using Lambda;

using haxe.macro.ComplexTypeTools;
using haxe.macro.TypeTools;
using haxe.macro.Context;
using haxe.ds.ArraySort;
using ecs.core.macro.Extensions;

typedef MetaMap = haxe.ds.Map<String, Array<Array<Expr>>>;

enum abstract StorageType(Int) from Int to Int {
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
						case "TAG": TAG;
						default:
							Context.warning('Unknown storage type ${s}', Context.currentPos());
							FAST;
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
@:persistent var tagMap = new Map<String, Int>();
@:persistent var tagCount = 0;

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

	public function new(ct:ComplexType, i:Int, pos) {
		//trace ('Generating storage for ${ct.toString()}');
		// derived from parameters
		givenCT = ct;
		followedCT = ct.followComplexType(pos);
		name = followedCT.toString();
		fullName = followedCT.followComplexType(pos).typeFullName(pos);
		componentIndex = i;

		// Derived from the type
		var followedT = getMacroType(followedCT);
		followedClass = getFollowedClass(followedT);
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

		// dervied from the meta
		updateMeta( followedT );
		updateContainer();
	}

	function tagExpr() : Expr {
		if (!tagMap.exists(fullName)) {
			tagMap.set(fullName, tagCount++);
		}

		return EConst(CInt(Std.string(tagMap.get(fullName)))).at();
	}
	function clearTagExpr(entityVarExpr : Expr ) : Expr {
		var te = tagExpr();	
		return  macro @:privateAccess ecs.Workflow.clearTag($entityVarExpr, $te);	
	}

	function setTagExpr(entityVarExpr : Expr ) : Expr {
		var te = tagExpr();	
		return  macro @:privateAccess ecs.Workflow.setTag($entityVarExpr, $te);	
	}
	
	public function getGetExprCached(entityExpr:Expr, cachedVarName:String):Expr {
		return switch (storageType) {
			case FAST: macro $i{cachedVarName}[$entityExpr];
			case COMPACT: macro $i{cachedVarName}.get($entityExpr);
			case SINGLETON: macro $i{cachedVarName};
			case TAG: macro @:privateAccess $i{cachedVarName};
		};
	}

	public function getGetExpr(entityExpr:Expr, sure:Bool = false):Expr {
		return switch (storageType) {
			case FAST: macro $containerFullNameExpr.storage[$entityExpr];
			case COMPACT: macro $containerFullNameExpr.storage.get($entityExpr);
			case SINGLETON: macro $containerFullNameExpr.storage;
			case TAG: var te = tagExpr();	
			sure ? 
				macro $containerFullNameExpr.storage :
			  	macro @:privateAccess ecs.Workflow.getTag($entityExpr, $te) ? $containerFullNameExpr.storage : null;
		};
	}

	public function getExistsExpr(entityVar:Expr):Expr {
		return switch (storageType) {
			case FAST: 
				isValueStruct ? 
			macro $containerFullNameExpr._existsStorage[$entityVar]
			:	
			macro $containerFullNameExpr.storage[$entityVar] != $emptyExpr;
			case COMPACT: macro $containerFullNameExpr.storage.exists($entityVar);
			case SINGLETON: macro $containerFullNameExpr.owner == $entityVar;
			case TAG: 
				var te = tagExpr();	
				macro  @:privateAccess ecs.Workflow.getTag($entityVar, $te);
		};
	}

	public function getCacheExpr(cacheVarName:String):Expr {
		return cacheVarName.define(macro $containerFullNameExpr.storage);
	}

	public function getAddExpr(entityVarExpr:Expr, componentExpr:Expr):Expr {
		return switch (storageType) {
			case FAST: 
				isValueStruct ? 
				macro {
					$containerFullNameExpr._existsStorage[$entityVarExpr] = true;
					$containerFullNameExpr.storage[$entityVarExpr] = $componentExpr;
				}
				:
			macro $containerFullNameExpr.storage[$entityVarExpr] = $componentExpr;
			
			case COMPACT: macro $containerFullNameExpr.storage.set($entityVarExpr, $componentExpr);
			case SINGLETON: macro {
					if ($containerFullNameExpr.owner != 0)
						throw 'Singleton already has an owner';
					$containerFullNameExpr.storage = $componentExpr;
					$containerFullNameExpr.owner = $entityVarExpr;
				};
			case TAG:var te = tagExpr();	
			macro @:privateAccess  ecs.Workflow.setTag($entityVarExpr, $te);
		};
	}

	public function getRemoveExpr(entityVarExpr:Expr):Expr {
		if (storageType == TAG) {
			return  clearTagExpr(entityVarExpr);
		}

		var retireExprs = getRetireExpr(entityVarExpr);

		return storageRemovePreambleExpr(entityVarExpr, retireExprs);
	}

	public function getRetireExpr(entityVarExpr:Expr):Array<Expr> {
		var accessExpr = switch (storageType) {
			case FAST: macro @:privateAccess $containerFullNameExpr.storage[$entityVarExpr];
			case COMPACT: macro @:privateAccess $containerFullNameExpr.storage.get($entityVarExpr);
			case SINGLETON: macro($containerFullNameExpr.owner == $entityVarExpr ? $containerFullNameExpr.storage : null);
			case TAG: var te = tagExpr();	
			@:privateAccess  macro ecs.Workflow.getTag($te, $te);
		};

		var retireExprs = new Array<Expr>();
		var autoRetire = isPooled && !followedMeta.exists(":no_auto_retire");
		if (autoRetire) {
			retireExprs.push(macro $accessExpr.retire());
		}

		if (followedClass != null) {
			var cfs_statics = followedClass.statics.get().map((x) -> {cf: x, stat: true});
			var cfs_non_statics = followedClass.fields.get().map((x) -> {cf: x, stat: false});

			var cfs = cfs_statics.concat(cfs_non_statics);

			for (cfx in cfs) {
				var cf = cfx.cf;
				if (cf.meta.has(":ecs_remove")) {
					switch (cf.kind) {
						case FMethod(k):
							var te = cf.expr();
							switch (te.expr) {
								case TFunction(tfunc):
									var fname = cf.name;
									var needsEntity = false;
									for (a in tfunc.args) {
										if (a.v.t.toComplexType().toString() == (macro:ecs.Entity).toString()) {
											needsEntity = true;
											break;
										}
									}
									if (needsEntity) {
										retireExprs.push(macro @:privateAccess $accessExpr.$fname($entityVarExpr));
									} else {
										// trace('removing without entity ${cf.name} | ${tfunc.args.length} | ${ cfx.stat} in ${followedClass.name}');
										retireExprs.push(macro @:privateAccess $accessExpr.$fname());
									}
								default:
							}
						default:
					}
				}
			}
		}
		return retireExprs;
	}
	
	function storageRemoveExpr(entityVarExpr:Expr):Expr {
		return switch (storageType) {
			case FAST, COMPACT, SINGLETON: macro @:privateAccess $containerFullNameExpr.remove($entityVarExpr);
			case TAG: clearTagExpr(entityVarExpr);
		}
		/*
		var hasExpr = getExistsExpr(entityVarExpr);
		return switch (storageType) {
			case FAST: macro @:privateAccess $containerFullNameExpr.storage[$entityVarExpr] = $emptyExpr;
			case COMPACT: macro @:privateAccess $containerFullNameExpr.storage.remove($entityVarExpr);
			case SINGLETON: macro {
					$containerFullNameExpr.storage = $emptyExpr;
					$containerFullNameExpr.owner = 0;
				}
			case TAG: 
				var te = tagExpr();	
				@:privateAccess  macro ecs.Workflow.clearTag($te, $te);	
		};*/
	}

	function storageRemovePreambleExpr(entityVarExpr:Expr, preamble:Array<Expr>):Expr {
		var hasExpr = getExistsExpr(entityVarExpr);
		var removeExpr = storageRemoveExpr(entityVarExpr);
		return macro if ($hasExpr) { $b{preamble} $removeExpr; };
	}

	public function getShelveExpr(entityVarExpr:Expr, pos:Position):Expr {
		var shelfCall = switch (storageType) {
			case FAST, COMPACT, SINGLETON: macro @:privateAccess $containerFullNameExpr.shelve($entityVarExpr);
			case TAG: Context.fatalError("Cannot shelve a tag",pos);
		}

		shelfCall.pos = pos;
		return shelfCall;
	}

	public function getUnshelveExpr(entityVarExpr:Expr, pos:Position):Expr {
		return switch (storageType) {
			case FAST, COMPACT, SINGLETON: macro @:privateAccess $containerFullNameExpr.unshelve($entityVarExpr);
			case TAG: Context.fatalError("Cannot unshelve a tag",pos);
		}
	}

	function getMacroType(ct : ComplexType) {
		var followedT = ct.toTypeOrNull(Context.currentPos());
		if (followedT == null) {
			Context.error('Could not find type for ${ct}', Context.currentPos());
		}
		return followedT;
	}
	function getFollowedClass(t : haxe.macro.Type) {
		var fc = null;
		try {
			fc = t.getClass();
		} catch (e) {
			switch (t) {
				case TAbstract(at, params):
					var x = at.get().impl;
					if (x != null) {
						fc = x.get();
					} else {
						Context.warning('abstract not implemented ${at} ${followedCT.toString()}', Context.currentPos());
					}
				default:
					Context.warning('Couldn\'t find class ${followedCT.toString()}', Context.currentPos());
			}
		}
		return fc;
	}

	public function update() {
		var t = getMacroType(followedCT);
		this.followedClass = getFollowedClass(t);
		updateMeta(t);
		updateContainer();
	}

	function getTypeMetaMap(t : haxe.macro.Type) {
		return t.getMeta().flatMap((x) -> x.get()).toMap();
	}



	function updateMeta(t : haxe.macro.Type) {
		// dervied from the meta
		followedMeta = getTypeMetaMap( t );
		storageType = StorageType.getStorageType(followedMeta);
//		trace('ECS: ${fullName} is ${structValues}');

		//		isPooled = getPooled(followedMeta);
		isPooled = false;
		isImmutable = followedMeta.exists(":immutable");
		var structValues = t.gatherMetaValueFromHierarchy(":struct");
		var platform = haxe.macro.Compiler.getConfiguration().platform;
		var isStructPlatform = platform == Platform.Cs || platform == Platform.Cpp;
		isValueStruct = isStructPlatform && structValues.length > 0;
	}

	function updateContainer() {
		var tp = (switch (storageType) {
			case FAST: tpath([], "Array", [TPType(followedCT)]);
			case COMPACT: tpath(["haxe", "ds"], "IntMap", [TPType(followedCT)]);
			case TAG: followedCT.toString().asTypePath();
			case SINGLETON: followedCT.toString().asTypePath();
			default: null;
		});

		if (tp != null) {
			storageCT = TPath(tp);

			containerTypeName = 'StorageOf' + fullName;
			containerFullName = STORAGE_NAMESPACE + "." + containerTypeName;

			containerFullNameExpr = containerFullName.asTypeIdent(Context.currentPos());

			//		Context.registerModuleDependency()
			containerCT = containerFullName.asComplexType();
			var containerType = containerCT.toTypeOrNull(Context.currentPos());

			if (containerType == null) {
				var existsExpr = getExistsExpr(macro id);
				var removeExpr = getRemoveExpr(macro id);

				var def = 
				switch(storageType) {
					case TAG:  macro class $containerTypeName {
						public static var storage:$storageCT = @:privateAccess new $tp();
						
					}
					case SINGLETON: macro class $containerTypeName {
						public static var storage:$storageCT;
						public static var owner:Int = 0;
						public static var _shelved :$storageCT = $emptyExpr;
						public static inline function shelved(id:Int) {
							return _shelved != $emptyExpr;
						}
						public static inline function exists(id:Int) {
							return storage != $emptyExpr;
						}
						public inline static function shelve(id:Int) {
							_shelved = storage;
							storage = $emptyExpr;
						}
						public inline static function unshelve(id:Int) : $followedCT {
							storage = _shelved;
							_shelved = $emptyExpr;
							return _shelved;
						}
						public inline static function remove(id:Int) {
							storage = $emptyExpr;
							_shelved = $emptyExpr;
							owner = 0;
						}
					}
					case FAST:

						var existsStorage = isValueStruct ? macro new Array<Bool>() : macro null;
						var existsStorageExpr = isValueStruct ? macro (_existsStorage[id]) : macro (storage[id] != $emptyExpr);
						var existsMarkTrueExpr = isValueStruct ? macro (_existsStorage[id] = true) : macro null;
						var existsMarkFalseExpr = isValueStruct ? macro (_existsStorage[id] = false) : macro null;

						macro class $containerTypeName {
							public static var storage = new Array<$followedCT>();
							public static var _shelved = new Map<Int,$followedCT>();
							public static var _existsStorage = $existsStorage;

							public inline function exists(id:Int)  {
								//return storage[id] != $emptyExpr;
								return $existsStorageExpr;
							}
							public inline static function shelved(id:Int) {
								return _shelved.exists(id);
							}
							public inline static function shelve(id:Int) {
								_shelved.set(id, storage[id]);
								storage[id] = $emptyExpr;
								$existsMarkFalseExpr;
							}
							public inline static function unshelve(id:Int) : $followedCT{
								var x = _shelved.get(id);
								storage[id] = x;
								_shelved.remove(id);
								$existsMarkTrueExpr;
								return x;
							}
							public inline static function remove(id) {
								storage[id] = $emptyExpr;
								$existsMarkFalseExpr;
							}
							public inline static function add(id, item : $followedCT) {
								storage[id] = item;
								$existsMarkTrueExpr;
							}
						}
					case COMPACT: 
					macro class $containerTypeName {
						//public static var storage:$storageCT = @:privateAccess new $tp();
						public static var storage = new Map<Int,$followedCT>();
						public static var _shelved = new Map<Int,$followedCT>();
	
						public inline function exists(id:Int)  {
							return storage.exists(id);
						}
						public inline static function shelved(id:Int) {
							return _shelved.exists(id);
						}
						public inline static function shelve(id:Int) {
							// This will fail if nothing is shelved
							var x = storage.get(id);
							_shelved.set(id, x);
							storage.remove(id);
						}
						public inline static function unshelve(id:Int) : $followedCT{
							var x = _shelved.get(id);
							storage.set(id, x);
							_shelved.remove(id);
							return x;
						}
						public inline static function remove(id) {
							storage.remove(id);
						}
						public inline static function add(id, item : $followedCT) {
							storage.set(id,item);
						}
					}
				}


				//trace(_printer.printTypeDefinition(def));
				def.defineTypeSafe(STORAGE_NAMESPACE, Const.ROOT_MODULE);
			}

			if (containerType == null) {
				containerType = containerCT.toTypeOrNull(Context.currentPos());
			}
		} else {
			containerCT = null;
			containerTypeName = null;
			containerFullName = null;
			containerFullNameExpr = null;
		}
	}

	public var name:String;
	public var givenCT:ComplexType;
	public var followedCT:ComplexType;
	public var followedMeta:MetaMap;
	public var followedClass:ClassType;
	public var storageType:StorageType;
	public var storageCT:ComplexType;
	public var componentIndex:Int;
	public var fullName:String;
	public var containerCT:ComplexType;
	public var containerTypeName:String;
	public var containerFullName:String;
	public var containerFullNameExpr:Expr;
	public var emptyExpr:Expr;
	public var isPooled:Bool;
	public var isImmutable : Bool;
	public var isValueStruct : Bool;
}

class ComponentBuilder {
	static var componentIndex = -1;
	@:persistent static var componentContainerTypeCache = new Map<String, StorageInfo>();
	static var currentComponentContainerTypeCache = new Map<String, StorageInfo>();

	public static function componentTypeNames() {
		return componentContainerTypeCache.keys();
	}

	public static function containerInfo(s:String) {
		return componentContainerTypeCache[s];
	}

	public static function getComponentContainerInfo(componentComplexType:ComplexType, pos):StorageInfo {
		var name = componentComplexType.followName(pos);

		var info = currentComponentContainerTypeCache.get(name);
		if (info != null) {
			return info;
		}

		info = componentContainerTypeCache.get(name);
		if (info != null) {
			#if ecs_late_debug
			trace('ECS: Updating type info on ${name}');
			#end
			info.update();
			currentComponentContainerTypeCache.set(name, info);
			return info;
		}

		info = new StorageInfo(componentComplexType, ++componentIndex, pos);
		componentContainerTypeCache[name] = info;
		currentComponentContainerTypeCache.set(name, info);

		return info;
	}

	public static function getLookup(ct:ComplexType, entityVarName:Expr, pos):Expr {
		return getComponentContainerInfo(ct, pos).getGetExpr(entityVarName);
	}

	public static function getComponentId(componentComplexType:ComplexType, pos):Int {
		return getComponentContainerInfo(componentComplexType, pos).componentIndex;
	}
}
#end
