package ecs;

/**
 *  Workflow  
 * 
 * @author https://github.com/deepcake
 * @author https://github.com/onehundredfeet
 */

#if macro

using ecs.core.macro.ComponentBuilder;
using ecs.core.macro.ViewsOfComponentBuilder;
using ecs.core.macro.MacroTools;
using haxe.macro.Context;
using haxe.macro.ComplexTypeTools;
using haxe.macro.Context;
using haxe.macro.Expr;
using haxe.macro.TypeTools;
using ecs.core.macro.Extensions;

#end

import ecs.Entity.Status;
import ecs.core.AbstractView;
import ecs.core.ICleanableComponentContainer;
import ecs.core.ISystem;
import ecs.utils.FastEntitySet;
import haxe.ds.ReadOnlyArray;
import ecs.core.Parameters;
import ecs.core.Containers;

class Workflow {

	static inline final TAG_STRIDE : Int = Std.int(Parameters.MAX_TAGS / 32);
	@:allow(ecs.Entity) static inline final INVALID_ID = 0;

	static var nextId = INVALID_ID + 1;

	static var idPool = new Array<Int>();

	//Per entity
	#if ecs_max_entities
	static var statuses = new EntityVector<Status>(Parameters.MAX_ENTITIES);
	static var tags = new EntityVector<Int>(Parameters.MAX_ENTITIES * TAG_STRIDE);
	static var worldFlags = new EntityVector<Int>(Parameters.MAX_ENTITIES);
	static var _generations = new EntityVector<Int>(Parameters.MAX_ENTITIES);
	#else
	static var statuses = new Array<Status>();
	static var tags = new Array<Int>();
	static var worldFlags = new Array<Int>();
	static var _generations = new Array<Int>();
	#end

	// all of every defined component container
	#if ecs_legacy_containers
	static var definedContainers = new Array<ICleanableComponentContainer>();
	#end
	// all of every defined view
	static var definedViews = new Array<AbstractView>();

	static var _singleton:Entity;

	static var _worldSingletons:Array<Entity> = [];

	public static function singleton() {
		if (_singleton.isValid()) {
			return _singleton;
		}
		_singleton = new Entity();
		return _singleton;
	}

	/**
	 * All active entities
	 */
	 public static var entities(get, null) : ReadOnlyFastEntitySet;
	 static inline function get_entities() {
		 return _entities;
	 }
	static var _entities(default, null) = new FastEntitySet();

	/**
	 * All active views
	 */
	public static var views(get, null) : ReadOnlyArray<AbstractView>;
	static inline function get_views() {
		return _views;
	}
	@:allow(ecs.core.AbstractView) static var _views(default, null) = new Array<AbstractView>();

	/**
	 * All systems that will be called when `update()` is called
	 */
	public static var systems(get, null) : ReadOnlyArray<ISystem>;
	static inline function get_systems() {
		return _systems;
	}
	static var _systems(default, null) = new Array<ISystem>();

	#if ecs_profiling
	static var updateTime = .0;
	#end

	/**
	 * Returns the workflow statistics:  
	 * _( systems count ) { views count } [ entities count | entity cache size ]_  
	 * With `ecs_profiling` flag additionaly returns:  
	 * _( system name ) : time for update ms_  
	 * _{ view name } [ collected entities count ]_  
	 * @return String
	 */
	public static function info():String {
		var ret = '# ( ${systems.length} ) { ${views.length} } [ ${_entities.length} | ${idPool.length} ]'; // TODO version or something

		#if ecs_profiling
		ret += ' : $updateTime ms'; // total
		for (s in systems) {
			ret += '\n${s.info('    ', 1)}';
		}
		for (v in views) {
			ret += '\n    {$v} [${v.entities.length}]';
		}
		#end

		return ret;
	}

	public static function infoObj() {
		return {
			systems : systems.length,
			views : views.length,
			entities : _entities.length,
			ids : idPool.length

		}
	}
	/**
	 * Update 
	 * @param dt deltatime
	 */
	public static function update(dt:Float) {
		#if ecs_profiling
		var timestamp = Date.now().getTime();
		#end

		for (s in systems) {
			s.__update__(dt);
		}

		#if ecs_profiling
		updateTime = Std.int(Date.now().getTime() - timestamp);
		#end
	}

	/**
	 * Removes all views, systems and entities from the workflow, and resets the id sequence 
	 */
	public static function reset() {
		for (e in _entities) {
			e.destroy();
		}
		for (s in systems) {
			removeSystem(s);
		}
		for (v in definedViews) {
			v.reset();
		}
		#if ecs_legacy_containers
		for (c in definedContainers) {
			c.reset();
		}
		#end

		// [RC] why splice and not resize?
		idPool.resize(0);
		#if !ecs_max_entities
		statuses.resize(0);
		worldFlags.resize(0);
		tags.resize(0);
		#end

		nextId = INVALID_ID + 1;
	}

	// System

	/**
	 * Adds the system to the workflow
	 * @param s `System` instance
	 */
	public static function addSystem(s:ISystem) {
		if (!hasSystem(s)) {
			_systems.push(s);
			s.__activate__();
		}
	}

	/**
	 * Removes the system from the workflow
	 * @param s `System` instance
	 */
	public static function removeSystem(s:ISystem) {
		if (hasSystem(s)) {
			s.__deactivate__();
			_systems.remove(s);
		}
	}

	/**
	 * Returns `true` if the system is added to the workflow, otherwise returns `false`  
	 * @param s `System` instance
	 * @return `Bool`
	 */
	public static function hasSystem(s:ISystem):Bool {
		return _systems.contains(s);
	}

	// Entity

	@:allow(ecs.Entity) static function id(immediate:Bool, worlds:Int):Int {
		var id = idPool.pop();

		if (id == null) {
			id = nextId++;
			_generations[id] = 0;
		} else {
			_generations[id]++;
		}

		#if ecs_max_entities
		if (id >= Parameters.MAX_ENTITIES) {
			throw 'Maximum number of entities reached';
		}
		#end

		if (immediate) {
			statuses[id] = Active;
			_entities.add(id);
		} else {
			statuses[id] = Inactive;
		}
		worldFlags[id] = worlds;
		tags[id] = 0;
		return id;
	}

	public inline static function worlds(id:Int) {
		if (status(id) == Active) {
			return worldFlags[id];
		}
		return 0;
	}

	public inline static function worldEntity(idx:Int) {
		if (!_worldSingletons[idx].isValid()) {
			_worldSingletons[idx] = new Entity();
		}

		return _worldSingletons[idx];
	}

	/*
		macro function getContainer( containerName : String ) {
			var containerName = (c.typeof().follow().toComplexType()).getComponentContainer().followName();
			return macro @:privateAccess $i{ containerName }.inst();
		}


		  /**
		* Creates a new archetype that makes entities
		* @param components comma separated list of components of `Any` type
		* @return `Entity`
	 */
	#if macro
	

	/*
		 static function exprOfClassToTypePath( e : ExprOf<Class<Any>>) : TPath {
			var x =  e.parseClassName().getType().follow().toComplexType();
			trace("tpath: " + x);
			return x;
		}
	 */
	// var allocation = components.map(function(c) return  {expr: ENew(exprOfClassToTypePath(c)),  pos:Context.currentPos()});
	#end
	/*
		 macro public static function addNoViews(self:Expr, components:Array<ExprOf<Any>>):ExprOf<ecs.Entity> {
			if (components.length == 0) {
				Context.error('Required one or more Components', Context.currentPos());
			}

		   
			var body = []
				.concat(
					addComponentsToContainersExprs
				)
				
				.concat([ 
					macro return __entity__ 
				]);

			var ret = macro #if (haxe_ver >= 4) inline #end ( function(__entity__:ecs.Entity) $b{body} )($self);

			return ret;
		}
	 */
	 
	macro public static function createFactory(worlds:ExprOf<Any>, components:Array<ExprOf<Class<Any>>>) { // :ExprOf<ecs.Factory> {
		#if macro
		var pos = Context.currentPos();

		if (components.length == 0) {
			Context.error('Required one or more Components', Context.currentPos());
		}

		// var pp = new haxe.macro.Printer();
		var classNames = components.map(function(c) return {expr: c.exprOfClassToFullTypeName(null, pos).asTypeIdent(pos).expr, pos: pos});
		var allocation = components.map(function(c) return {expr: ENew(c.exprOfClassToTypePath(null, pos), []), pos:pos});

		var addComponentsToContainersExprs = components.map((c) -> {
			// trace("parsetname|" + c.parseClassName().getType().toComplexType());
			var ct = c.parseClassName().getType().follow().toComplexType();
			var info = ct.getComponentContainerInfo(pos);

			//trace('add and alloc ${c}');
			var alloc = {expr: ENew(ct.toString().asTypePath(), []), pos: Context.currentPos()};

			return info.getAddExpr(macro __entity__, alloc);
		});

		// trace(pp.printExprs(allocation, "\n"));

		var body = [].concat([macro var _views:Array<ecs.core.AbstractView> = []])
			.concat([
				// macro trace("Tracing against " + ecs.Workflow.views.length)
			])
			.concat([
				macro for (v in ecs.Workflow.views) {
					if (@:privateAccess v.isMatchedByTypes($worlds, $a{classNames})) {
						_views.push(v);
					}
				}
			])
			.concat([
				macro return function() {
					var __entity__ = new ecs.Entity($worlds);
					//                ecs.Workflow.addNoViews(e, $a{allocation});
					$b{addComponentsToContainersExprs};

					// trace("adding to views " + _views.length);
					for (v in _views) {
						// trace("adding to view ");
						@:privateAccess v.addMatchedNew(__entity__);
					}
					return __entity__;
				}
			]);

		var ret = macro inline(function() $b{body})();

		// trace(pp.printExpr(ret));
		return ret;
		#else
		return macro "";
		#end

		#if false.concat
		(addComponentsToContainersExprs) var addComponentsToContainersExprs = components.map(function(c) {
			var info = (c.typeof().follow().toComplexType()).getComponentContainerInfo();

			var containerName = (c.typeof().follow().toComplexType()).getComponentContainer().followName();
			return macro @:privateAccess $i{containerName}.inst();
		});

		return macro "";
		#end
	}

	#if factories
	#end
	@:allow(ecs.Entity) static inline function setWorlds(id:Int, flags:Int) {
		if (status(id) == Active) {
			remove(id);
			worldFlags[id] = flags;
			add(id);
		}
		return 0;
	}

	@:allow(ecs.Entity) static inline function joinWorld(id:Int, idx:Int) {
		if (status(id) == Active) {
			remove(id);
			worldFlags[id] = worldFlags[id] | (1 << idx);
			add(id);
		}
	}

	@:allow(ecs.Entity) static inline function leaveWorld(id:Int, idx:Int) {
		if (status(id) == Active) {
			remove(id);
			worldFlags[id] = worldFlags[id] & ~(1 << idx);
			add(id);
		}
	}

	@:allow(ecs.Entity) static inline function cache(id:Int) {
		// Active or Inactive
		if (status(id) < Cached) {
			removeAllComponentsOf(id);
			_entities.remove(id);
			idPool.push(id);
			statuses[id] = Cached;
		}
	}

	@:allow(ecs.Entity) static inline function add(id:Int) {
		if (status(id) == Inactive) {
			statuses[id] = Active;
			_entities.add(id);
			for (v in views)
				v.addIfMatched(id);
		}
	}

	@:allow(ecs.Entity) static inline function remove(id:Int) {
		if (status(id) == Active) {
			for (v in views)
				v.removeIfExists(id);
			_entities.remove(id);
			statuses[id] = Inactive;
		}
	}

	@:allow(ecs.Entity) static inline function status(id:Int):Status {
		if (id <= Workflow.INVALID_ID)
			return Status.Invalid;
		return statuses[id];
	}

	@:allow(ecs.Entity) static inline function pauseAdding(id:Int) {

	}

	@:allow(ecs.Entity) static inline function resumeAdding(id:Int) {
		
	}


	@:allow(ecs.Entity) static inline function getTag( id:Int, tag: Int) {
		final offset = tag >> 5;
		final bitOffset = tag - (offset << 5);
		final tagField = tags[id * TAG_STRIDE + offset];
		return tagField & (1 << bitOffset) != 0;
	}


	@:allow(ecs.Entity) static inline function setTag( id:Int, tag: Int) {
//		trace('Setting tag  ${tag} on ${id}');
		final offset = tag >> 5;
		final bitOffset = tag - (offset << 5);
		final idx = id * TAG_STRIDE + offset;
		final tagField = tags[id * TAG_STRIDE + offset];
		tags[id * TAG_STRIDE + offset] = tagField | (1 << bitOffset);
	}

	@:allow(ecs.Entity) static inline function clearTag( id:Int, tag: Int) {
		final offset = tag >> 5;
		final bitOffset = tag - (offset << 5);
		final idx = id * TAG_STRIDE + offset;
		final tagField = tags[id * TAG_STRIDE + offset];
		tags[id * TAG_STRIDE + offset] = tagField & ~(1 << bitOffset);
	}

	static var removeAllFunction : (ecs.Entity) -> Void = null;

	public static dynamic function numComponentTypes() { return 0; }	
	public static dynamic function componentNames()  : Array<String> {
		return [];
	}
	public static dynamic function entityComponentNames(e : ecs.Entity) : Array<String> {
		return [];
	}
	public static dynamic function componentsToStrings(e : ecs.Entity) : Array<String> {
		return [];
	}
	public static dynamic function componentsToDynamic(e : ecs.Entity) : Array<Dynamic> {
		return [];
	}
	public static dynamic function componentNameToString(e : ecs.Entity, name : String) : String {
		return "";
	}

	macro static function removeAllComponents(e : Expr) : Expr {
		return macro {
			if (removeAllFunction == null) {
				var c = Type.resolveClass("LateCalls");
				if (c == null) throw "Internal ecs Error - no LateCalls class available in reflection. Required compilation macro: --macro ecs.core.macro.Global.setup()";
				var i = Type.createInstance(c,null);
				if (i == null) throw "Internal ecs Error - could not instance LateCalls. Required compilation macro: --macro ecs.core.macro.Global.setup()";
				removeAllFunction = i.getRemoveFunc();
			}
			removeAllFunction($e);			
		}		
	}

	@:allow(ecs.Entity) static inline function removeAllComponentsOf(id:Int) {
		if (status(id) == Active) {
			for (v in views) {
				v.removeIfExists(id);
			}
		}
		#if ecs_legacy_containers
		for (c in definedContainers) {
			c.remove(id);
		}
		#else
		removeAllComponents(id);
		#end
	}



	@:allow(ecs.Entity) static inline function printAllComponentsOf(id:Int):String {
		var ret = '#$id:';
		#if ecs_legacy_containers
		for (c in definedContainers) {
			if (c.exists(id)) {
				ret += '${c.print(id)},';
			}
		}
		#end

		return ret.substr(0, ret.length - 1);
	}

	public inline static function getGeneration(id:Int):Int {
		return _generations[id];
	}
}
