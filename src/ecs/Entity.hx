package ecs;

import ecs.core.Parameters;
#if macro
import haxe.macro.Expr;

using ecs.core.macro.ComponentBuilder;
using ecs.core.macro.ViewsOfComponentBuilder;
using ecs.core.macro.MacroTools;
using haxe.macro.Context;
using Lambda;
using StringTools;
#else

import haxe.CallStack;
#end

/**
 * Entity is an abstract over the `Int` key.  
 * - Do not use the Entity as a unique id, as destroyed entities will be cached and reused!  
 *  
 * @author https://github.com/deepcake
 */
 @:allow(ecs.World) 
abstract Entity(Int)  {
	public static inline final INVALID_ID = 0;
	public static inline var INVALID_ENTITY:Entity = new Entity(INVALID_ID);


	private inline function new(i : Int) : Entity {
		this = i;
	}

		/**
	 * Creates a new Entity instance  
	 * @param immediate immediately adds this entity to the workflow if `true`, otherwise `activate()` call is required
	 */
	public inline function make(world:Int, immediate:Bool = true) {
		return Workflow.world(world).newEntity(immediate);
	}
	static inline final WORLD_SHIFT = 32 - Parameters.WORLD_BITS; // defaults to 4
	static inline final WORLD_COUNT = 1 << Parameters.WORLD_BITS;
	static inline final WORLD_RIGHT_MASK = ((1 << (Parameters.WORLD_BITS)) - 1);
	static inline final WORLD_LEFT_MASK =  ~((1 << (WORLD_SHIFT)) - 1);

	static inline final GENERATION_SHIFT = WORLD_SHIFT - Parameters.GENERATION_BITS; // defaults to 4
	static inline final GENERATION_COUNT = 1 << Parameters.GENERATION_BITS;
	static inline final GENERATION_RIGHT_MASK = ((1 << (Parameters.GENERATION_BITS)) - 1);
	static inline final GENERATION_LEFT_MASK = ~((1 << (GENERATION_SHIFT)) - 1) & ~WORLD_LEFT_MASK;

	static inline final ID_MASK = ~(WORLD_LEFT_MASK | GENERATION_LEFT_MASK);
	static inline final ID_BITS = 32 - Parameters.WORLD_BITS - Parameters.GENERATION_BITS;
	static inline final ID_COUNT = 1 << ID_BITS;

	private static inline function fromWorldAndId(world:Int, id:Int, gen:Int) : Entity {
		return new Entity((world << WORLD_SHIFT) | (gen << GENERATION_SHIFT) | id);
	}

	public var valid(get, never):Bool;
	inline function get_valid() {
		return this != INVALID_ID && world.getGeneration(id) == generation;
	}

	public var active(get, never):Bool;
	inline function get_active(){
		return this != INVALID_ID && world.getGeneration(id) == generation && status() == Status.Active;
	}

	public var world(get, never):World;
	inline function get_world() {
		return Workflow.world((this >>> WORLD_SHIFT) );
	}

	public var worldId(get, never):Int;
	inline function get_worldId() {
		return this >>> WORLD_SHIFT; // doesn't need a mask because it's on the left
	}
	
	public var id(get, never):Int;
	inline function get_id() {
		return this & ID_MASK;
	}

	public var generation(get, never):Int;
	inline function get_generation() {
		return (this >>> GENERATION_SHIFT) & GENERATION_RIGHT_MASK;
	}

	// public var generation(get, never):Int;

	// inline function get_generation() {
	// 	return  world.getGeneration(this);
	// }

	/**
	 * Adds this entity to the workflow, so it can be collected by views  
	 */
	public inline function activate() {
		world.add(self());
	}

	/**
	 * Removes this entity from the workflow (and also from all views), but saves all associated components.  
	 * Entity can be added to the workflow again by `activate()` call
	 */
	public inline function deactivate() {
		world.remove(self());
	}

	/**
	 * Prevents any addition callbaks until resuming
	 */
	public inline function pauseAdding() {
		world.pauseAdding(self());
	}

	/**
	 * Calls any addition callbacks for new views
	 */
	public inline function resumeAdding() {
		world.resumeAdding(self());
	}

	/**
	 * Returns the status of this entity: Active, Inactive, Cached or Invalid. Method is used mostly for debug purposes  
	 * @return Status
	 */
	public inline function status():Status {
		return world.status(self());
	}

	/**
	 * Returns `true` if this entity is added to the workflow, otherwise returns `false`  
	 * @return Bool
	 */
	public inline function isActive():Bool {
		return status() == Active;
	}

	/**
	 * Returns `true` if this entity has not been destroyed and therefore can be used safely  
	 * @return Bool
	 */
	public inline function isValid():Bool {
		return this != INVALID_ID && status() < Cached;
	}

	public inline function self():Entity {
		return new Entity(this);
	}

	/**
	 * Removes all of associated to this entity components.  
	 * __Note__ that this entity will be still exists after call this method (just without any associated components). 
	 * If entity is not required anymore - `destroy()` should be called 
	 */
	public inline function removeAll() {
		world.removeAllComponentsOf(self());
	}

	/**
	 * Removes this entity from the workflow with removing all associated components. 
	 * The `Int` id will be cached and then will be used again in new created entities.  
	 * __Note__ that using this entity after call this method is incorrect!
	 */
	public inline function destroy() {
		world.cache(self());
	}

	

	/**
	 * Returns list of all associated to this entity components.  
	 * @return String
	 */
	public inline function print():String {
		return world.printAllComponentsOf(this);
	}

	#if macro
	static function getComponentContainerInfo(c:haxe.macro.Expr, pos:haxe.macro.Expr.Position) {
		var to = c.typeof();
		if (to == null) {
			Context.fatalError('Can not find type for ${c} ', pos);
		}
		var type = to;

		return switch (type) {
			case TType(tref, args):
				if (tref.get().name.contains("Class<")) {
					var cn = c.parseClassName();
					var clt = cn.getType();
					var tt = clt.follow();
					var compt = tt.toComplexType();
					compt.getComponentContainerInfo(pos);
				} else {
					// Typedef
					(type.follow().toComplexType()).getComponentContainerInfo(pos);
				}
			// class is specified instead of an expression
			default:
				(type.follow().toComplexType()).getComponentContainerInfo(pos);
		}
	}
	#end

	/**
	 * Adds a specified components to this entity.  
	 * If a component with the same type is already added - it will be replaced 
	 * @param components comma separated list of components of `Any` type
	 * @return `Entity`
	 */
	macro public function add(self:Expr, components:Array<Expr>):ExprOf<ecs.Entity> {
		var pos = Context.currentPos();

		if (components.length == 0) {
			Context.error('Required one or more Components', pos);
		}

		var addComponentsToContainersExprs = components.map(function(c) {
			var info = getComponentContainerInfo(c, pos);

			return info.getAddExpr( macro __entity__, c);
			// var containerName = (c.typeof().follow().toComplexType()).getComponentContainerInfo().fullName;
			// return macro @:privateAccess $i{ containerName }.inst().add(__entity__, $c);
		});

		var body = [].concat(addComponentsToContainersExprs).concat([
			macro if (__entity__.isActive()) {
				for (v in __entity__.world.views) {
					@:privateAccess v.addIfMatched(__entity__);
				}
			}
		]).concat([macro return __entity__]);

		var ret = macro #if (haxe_ver >= 4) inline #end (function(__entity__:ecs.Entity) $b{body})($self);

		return ret;
	}

	#if macro
	static function ecsActionByClass(self:Expr, types:Array<ExprOf<Class<Any>>>, pos:Position,
			storageAction:(info:StorageInfo, entityExpr:Expr, pos:Position) -> Expr,
			viewAction:(viewExpr:Expr, entityExpr:Expr, pos:Position) -> Expr):ExprOf<ecs.Entity> {
		var errorStage = "";
		if (types.length == 0) {
			Context.error('Required one or more Component Types', pos);
		}
		errorStage = "starting";
		var cts = types.map(function(type) {
			return type.parseClassName().getType().follow().toComplexType();
		});

		errorStage = "found types";
		var actionExprs = cts.map(function(ct) {
			var info = ct.getComponentContainerInfo(pos);
			return storageAction(info, macro __entity__, pos);
		});
		errorStage = "got action expression";

		var viewActionExpr = cts.map(function(ct) {
			return ct.getViewsOfComponent(pos).followName(pos);
		}).map(function(viewsOfComponentClassName) {
			var x = viewsOfComponentClassName.asTypeIdent(Context.currentPos());
			return viewAction(macro $x.inst(), macro __entity__, pos);
		});
		errorStage = "got views of components";

		var body = [
			[
				macro if (__entity__.isActive())
					$b{viewActionExpr}
			],
			actionExprs,
			[macro return __entity__]
		].flatten();

		/*
			var body = [].concat([
				macro if (__entity__.isActive())
					$b{removeEntityFromRelatedViewsExprs}
			]).concat(removeComponentsFromContainersExprs).concat([macro return __entity__]);
		 */
		errorStage = "made body";

		var ret = macro inline(function(__entity__:ecs.Entity) $b{body})($self);

		errorStage = "returning";

		return ret;
	}
	#end

	//
	// By class functions
	//

	/**
	 * Removes a component from this entity with specified type  
	 * @param types comma separated `Class<Any>` types of components that should be removed
	 * @return `Entity`
	 */
	macro public function remove(self:Expr, types:Array<ExprOf<Class<Any>>>):ExprOf<ecs.Entity> {
		var storageAction = (info:StorageInfo, entityExpr:Expr, pos:Position) -> {
			return info.getRemoveExpr(entityExpr);
		}
		var viewAction = (viewExpr:Expr, entityExpr:Expr, pos:Position) -> {
			return macro @:privateAccess ${viewExpr}.removeIfExists($entityExpr);
		}
		return ecsActionByClass(self, types, Context.currentPos(), storageAction, viewAction);
	}

	macro public function shelve(self:Expr, types:Array<ExprOf<Class<Any>>>):ExprOf<ecs.Entity> {
		var storageAction = (info:StorageInfo, entityExpr:Expr, pos:Position) -> {
			return info.getShelveExpr(entityExpr, pos);
		}
		var viewAction = (viewExpr:Expr, entityExpr:Expr, pos:Position) -> {
			return macro @:privateAccess ${viewExpr}.removeIfExists($entityExpr);
		}
		return ecsActionByClass(self, types, Context.currentPos(), storageAction, viewAction);
	}

	macro public function unshelve(self:Expr, types:Array<ExprOf<Class<Any>>>):ExprOf<ecs.Entity> {
		var storageAction = (info:StorageInfo, entityExpr:Expr, pos:Position) -> {
			return info.getUnshelveExpr(entityExpr, pos);
		}
		var viewAction = (viewExpr:Expr, entityExpr:Expr, pos:Position) -> {
			return macro @:privateAccess ${viewExpr}.addIfMatched($entityExpr);
		}
		return ecsActionByClass(self, types, Context.currentPos(), storageAction, viewAction);
	}

	/**
	 * Returns a component of this entity of specified type.  
	 * If a component with specified type is not added to this entity, `null` will be returned 
	 * @param type `Class<T:Any>` type of component
	 * @return `T:Any` component instance
	 */
	macro public function get<T>(self:Expr, type:ExprOf<Class<T>>):ExprOf<T> {
		var pos = Context.currentPos();
		var info = (type.parseClassName().getType().follow().toComplexType()).getComponentContainerInfo(pos);

		return info.getGetExpr(self);
	}

	/**
	 * Returns `true` if this entity contains a component of specified type, otherwise returns `false` 
	 * @param type `Class<T:Any>` type of component
	 * @return `Bool`
	 */
	macro public function exists(self:Expr, type:ExprOf<Class<Any>>):ExprOf<Bool> {
		var pos = Context.currentPos();
		var info = (type.parseClassName().getType().follow().toComplexType()).getComponentContainerInfo(pos);
		return info.getExistsExpr(self);
	}

	macro public function has(self:Expr, type:ExprOf<Class<Any>>):ExprOf<Bool> {
		var pos = Context.currentPos();
		var info = (type.parseClassName().getType().follow().toComplexType()).getComponentContainerInfo(pos);

		return info.getExistsExpr(self);
	}

	@:keep
    public function toString() {
        return 'Entity( world:${worldId}, id:${id}, gen:${generation}, status:${status()} )';
    }


}

enum abstract Status(Int) {
	var Inactive = 0;
	var Active = 1;
	var Cached = 2;
	var Invalid = 3;

	@:op(A > B) static function gt(a:Status, b:Status):Bool;

	@:op(A < B) static function lt(a:Status, b:Status):Bool;
}
