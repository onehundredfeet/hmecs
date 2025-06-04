package ecs;

import haxe.ds.BalancedTree;
import haxe.macro.Printer;
import ecs.Entity.Entity;

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

enum  UpdatePreference{
	Agnostic; // order independent
	First; // Will throw if more than one system is marked as first
	Last; // Will throw if more than one system is marked as last
}

class World {
	public function new(worldid:Int) {
		_worldID = worldid;
		worldBits = worldid << @:privateAccess Entity.WORLD_SHIFT;
		_self = newEntity();
	}

	inline static final TAG_STRIDE:Int = Std.int(Parameters.MAX_TAGS / 32);

	public var self(get, never):Entity;

	inline function get_self() {
		return _self;
	}

	public var worldID(get, never):Int;

	inline function get_worldID() {
		return _worldID;
	}

	var nextId = Entity.INVALID_ID + 1;
	var _self:Entity;
	var idPool = new Array<Int>();
	var worldBits = 0;
	var _worldID = 0;

	@:allow(ecs.System) var orderDirty = true;

	// Per entity
	#if ecs_max_entities
	var statuses = new EntityVector<Status>(Parameters.MAX_ENTITIES);
	var tags = new EntityVector<Int>(Parameters.MAX_ENTITIES * TAG_STRIDE);
	var _generations = new EntityVector<Int>(Parameters.MAX_ENTITIES);
	#else
	var statuses = new Array<Status>();
	var tags = new Array<Int>();
	var _generations = new Array<Int>();
	#end

	// all of every defined component container
	// all of every defined view
	var definedViews = new Array<AbstractView>();

	/**
	 * All active entities
	 */
	public var entities(get, null):ReadOnlyFastEntitySet;

	inline function get_entities() {
		return _entities;
	}

	var _entities(default, null) = new FastEntitySet();

	/**
	 * All active views
	 */
	public var views(get, null):ReadOnlyArray<AbstractView>;

	inline function get_views() {
		return _views;
	}

	@:allow(ecs.core.AbstractView) var _views(default, null) = new Array<AbstractView>();

	/**
	 * All systems that will be called when `update()` is called
	 */
	public var systems(get, null):ReadOnlyArray<ISystem>;

	inline function get_systems() {
		return _systems;
	}

	var _systems(default, null) = new Array<ISystem>();

	#if ecs_profiling
	var updateTime = .0;
	#end

	/**
	 * Returns the workflow statistics:  
	 * _( systems count ) { views count } [ entities count | entity cache size ]_  
	 * With `ecs_profiling` flag additionaly returns:  
	 * _( system name ) : time for update ms_  
	 * _{ view name } [ collected entities count ]_  
	 * @return String
	 */
	public function info():String {
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

	public function infoObj() {
		return {
			systems: systems.length,
			views: views.length,
			entities: _entities.length,
			ids: idPool.length
		}
	}

	public function sortSystems() {
		if (orderDirty) {
			// translate to systems
			var sysObjects = new Array<ecs.System>();
			

			for (i in 0..._systems.length) {
				var s = _systems[i];
				if (s is ecs.System) {
					sysObjects.push(cast(s, ecs.System));
				}
			}

			// sort systems
			var allChildren = new Array<Array<Int>>();
			for (i in 0...sysObjects.length) {
				allChildren[i] = [];
			}

			
			var map = new Map<String, Int>();
	
			// make name map
			for (i in 0...sysObjects.length) {
				var sys = sysObjects[i];
				var name = Type.getClassName(Type.getClass(sys));
				if (name == null) {
					throw 'System type name is null for ${sys}';
				}
				if (map.exists(name)) {
					throw 'System type name collision: $name';
				}
				map.set(name, i);
			}

			// unify all depdencies into all afters
			for (i in 0...sysObjects.length) {
				var s = sysObjects[i];
				
				var sname = Type.getClassName(Type.getClass(s));

				for (before in s._updateBefore) {
					var beforeName = Type.getClassName(before);
					if (map.exists(beforeName)) {
						var beforeIndex = map.get(beforeName);
						allChildren[i].push(beforeIndex);
					} 
				}

				for (after in s._updateAfter) {
					var afterName = Type.getClassName(after);
					trace('Adding wtf? ${afterName} to ${sname}');
					if (map.exists(afterName)) {
						var afterIndex = map.get(afterName);
						allChildren[afterIndex].push(i);
					} 
				}
			}

			// add dependencies to first and last if they exist

			if (_firstSystem != null) {
				var firstIndex = map.get(Type.getClassName(Type.getClass(_firstSystem)));
				for (s in sysObjects) {
					if (s == _firstSystem) continue;
					//first must go before everything else
					allChildren[firstIndex].push(map.get(Type.getClassName(Type.getClass(s))));
				}
			}

			if (_lastSystem != null) {
				var lastIndex = map.get(Type.getClassName(Type.getClass(_lastSystem)));
				for (s in sysObjects) {
					if (s == _lastSystem) continue;
					// last must go after everything else
					allChildren[map.get(Type.getClassName(Type.getClass(s)))].push(lastIndex);
				}
			}

			var incoming = new Array<Int>();
			for (i in 0...allChildren.length) {
				for (j in allChildren[i]) {
					incoming[j]++;
				}
			}

			var scores = new Array<Int>();

			function traverse(i:Int, score:Int) {
				if (score > scores[i]) {
					scores[i] = score;
					for (j in allChildren[i]) {
						traverse(j, score + 1);
					}
				}
			}

			// calculate score
			for (i in 0...sysObjects.length) {
				if (incoming[i] == 0) {
					traverse(i, 1);
				} 
			}

			trace('Scores:');
			for (i in 0...sysObjects.length) {
				var s = sysObjects[i];
				var n = Type.getClassName(Type.getClass(s));
				trace('System ${i} ${n}:score ${scores[i]} : incoming ${incoming[i]} : children ${allChildren[i]}');
			}

			_systems.sort((a, b) -> {
				var idx = map.get(Type.getClassName(Type.getClass(a)));
				var jdx = map.get(Type.getClassName(Type.getClass(b)));
				if (idx == null || jdx == null) {
					if (idx == null && jdx == null) return 0;
					if (idx == null) return -1; // first one is not a system
					if (jdx == null) return 1; // second one is not a system
				}

				if (scores[idx] > scores[jdx]) {
					return 1;
				} else if (scores[idx] < scores[jdx]) {
					return -1;
				}
				return 0;
			});

			trace('---Sorted:');
			for (i in 0..._systems.length) {
				var si = _systems[i];
				var idx = map.get(Type.getClassName(Type.getClass(si)));
				if (idx == null) {
					trace('System ${i} ${si} is not a system');
					continue;
				}
				var s = cast(si, ecs.System);
				var n = Type.getClassName(Type.getClass(s));
				trace('System ${i} ${n}:score ${scores[idx]} : incoming ${incoming[idx]} : children ${allChildren[idx]}');
			}

			orderDirty = false;
		}
	}



	/**
	 * Update 
	 * @param dt deltatime
	 */
	public function update(dt:Float) {
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
	public function reset() {
		for (e in _entities) {
			e.destroy();
		}
		for (s in systems) {
			removeSystem(s);
		}
		for (v in definedViews) {
			v.reset(_worldID);
		}
		#if ecs_legacy_containers
		for (c in definedContainers) {
			c.reset();
		}
		#end

		idPool.resize(0);
		#if !ecs_max_entities
		statuses.resize(0);
		tags.resize(0);
		#end

		nextId = ecs.Entity.INVALID_ID + 1;
	}

	// System

	/**
	 * Adds the system to the workflow
	 * @param s `System` instance
	 */


	function addSystem(sys:ISystem, prime = true, updatePref:UpdatePreference = UpdatePreference.Agnostic) {
		//		trace('Initializing ${sys}');
		sys.__initialize__(this);
		//		trace('Activating ${sys}');
		sys.__activate__();
		if (prime)
			sys.prime(this);
		this._systems.push(sys);
		switch (updatePref) {
			case UpdatePreference.First:
				if (_firstSystem != null) throw 'Only one system can be marked as first';
				_firstSystem = sys;
			case UpdatePreference.Last:
				if (_lastSystem != null) throw 'Only one system can be marked as last';
				_lastSystem = sys;
			default:
		};

		orderDirty = true;
		return sys;
	}

	function _getSystemOfType(sysType:Class<ISystem>) {
		for (s in _systems) {
			if (Std.isOfType(s, sysType)) {
				return s;
			}
		}
		return null;
	}

	

	public function prime() {
		for (s in _systems) {
			s.prime(this);
		}
	}

	macro public function get<T>(self:Expr, type:ExprOf<Class<T>>):ExprOf<T> {
		var pos = Context.currentPos();
		var info = (type.parseClassName().getType().follow().toComplexType()).getComponentContainerInfo(pos);

		var e = info.getGetExpr(self);
		e.pos = Context.currentPos();
		return e;
	}

	#if macro
	@:allow(ecs.System) static function _prepareSystem<T:ecs.System>(eThis:ExprOf<World>, sysType:ExprOf<Class<T>>,
			?updatePref:ExprOf<UpdatePreference>):ExprOf<T> {

		var tp = sysType.parseClassName().asTypePath();
		var cp = sysType.parseClassName().asComplexType();

		if (updatePref == null) {
			updatePref = macro ecs.World.UpdatePreference.Agnostic;
		}

		var tpn = '$tp';
		var thisN = new Printer().printExpr(eThis);
		var r = macro {
			var _st_ = @:privateAccess ($eThis)._getSystemOfType($sysType);
			_st_ != null ? cast(_st_, $cp) : cast(@:privateAccess ($eThis).addSystem(new $tp(), false, $updatePref), $cp);
		};

		// var p = new Printer();
		// trace(p.printExpr(r));
		return r;

	}
	#end

	macro public function prepareSystem<T:ISystem>(eThis:ExprOf<World>, sysType:ExprOf<Class<T>>,
			?updatePref:ExprOf<UpdatePreference>):ExprOf<T> {
		
		var x= _prepareSystem(eThis, sysType, updatePref);

		return macro {
			trace('prepareSystem() system ' + $sysType);
			$x;

		};
	}

	var _firstSystem:ISystem;
	var _lastSystem:ISystem;

	/**
	 * Removes the system from the workflow
	 * @param s `System` instance
	 */
	public function removeSystem(s:ISystem) {
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
	public function hasSystem(s:ISystem):Bool {
		return _systems.contains(s);
	}

	// Entity

	public inline function newEntity(immediate:Bool = true):Entity {
		var id = idPool.pop();

		if (id == null) {
			id = nextId++;
			_generations[id] = 0;
		}

		#if ecs_max_entities
		if (id >= Parameters.MAX_ENTITIES) {
			throw 'Maximum number of entities reached';
		}
		#end

		var e = Entity.fromWorldAndId(_worldID, id, _generations[id]);
		if (immediate) {
			statuses[id] = Active;
			_entities.add(e);
		} else {
			statuses[id] = Inactive;
		}
		tags[id] = 0;
		return e;
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
		 function exprOfClassToTypePath( e : ExprOf<Class<Any>>) : TPath {
			var x =  e.parseClassName().getType().follow().toComplexType();
			trace("tpath: " + x);
			return x;
		}
	 */
	// var allocation = components.map(function(c) return  {expr: ENew(exprOfClassToTypePath(c)),  pos:Context.currentPos()});
	#end
	/*
		 macro public function addNoViews(self:Expr, components:Array<ExprOf<Any>>):ExprOf<ecs.Entity> {
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
	// macro public function createFactory(worlds:ExprOf<Any>, components:Array<ExprOf<Class<Any>>>) { // :ExprOf<ecs.Factory> {
	// 	#if macro
	// 	var pos = Context.currentPos();
	// 	if (components.length == 0) {
	// 		Context.error('Required one or more Components', Context.currentPos());
	// 	}
	// 	// var pp = new haxe.macro.Printer();
	// 	var classNames = components.map(function(c) return {expr: c.exprOfClassToFullTypeName(null, pos).asTypeIdent(pos).expr, pos: pos});
	// 	var allocation = components.map(function(c) return {expr: ENew(c.exprOfClassToTypePath(null, pos), []), pos: pos});
	// 	var addComponentsToContainersExprs = components.map((c) -> {
	// 		// trace("parsetname|" + c.parseClassName().getType().toComplexType());
	// 		var ct = c.parseClassName().getType().follow().toComplexType();
	// 		var info = ct.getComponentContainerInfo(pos);
	// 		// trace('add and alloc ${c}');
	// 		var alloc = {expr: ENew(ct.toString().asTypePath(), []), pos: Context.currentPos()};
	// 		return info.getAddExpr(macro __entity__, alloc);
	// 	});
	// 	// trace(pp.printExprs(allocation, "\n"));
	// 	var body = [].concat([macro var _views:Array<ecs.core.AbstractView> = []])
	// 		.concat([
	// 			// macro trace("Tracing against " + ecs.Workflow.views.length)
	// 		])
	// 		.concat([
	// 			macro for (v in ecs.Workflow.views) {
	// 				if (@:privateAccess v.isMatchedByTypes($worlds, $a{classNames})) {
	// 					_views.push(v);
	// 				}
	// 			}
	// 		])
	// 		.concat([
	// 			macro return function() {
	// 				var __entity__ = new ecs.Entity($worlds);
	// 				//                ecs.Workflow.addNoViews(e, $a{allocation});
	// 				$b{addComponentsToContainersExprs};
	// 				// trace("adding to views " + _views.length);
	// 				for (v in _views) {
	// 					// trace("adding to view ");
	// 					@:privateAccess v.addMatchedNew(__entity__);
	// 				}
	// 				return __entity__;
	// 			}
	// 		]);
	// 	var ret = macro inline(function() $b{body})();
	// 	// trace(pp.printExpr(ret));
	// 	return ret;
	// 	#else
	// 	return macro "";
	// 	#end
	// 	#if false.concat
	// 	(addComponentsToContainersExprs) var addComponentsToContainersExprs = components.map(function(c) {
	// 		var info = (c.typeof().follow().toComplexType()).getComponentContainerInfo();
	// 		var containerName = (c.typeof().follow().toComplexType()).getComponentContainer().followName();
	// 		return macro @:privateAccess $i{containerName}.inst();
	// 	});
	// 	return macro "";
	// 	#end
	// }
	#if factories
	#end
	@:allow(ecs.Entity) inline function cache(e:Entity) {
		// Active or Inactive
		if (status(e) < Cached) {
			removeAllComponentsOf(e);
			_entities.remove(e);

			// TODO: somehow we managed to double-add an id to the pool by destroying an entity multiple times... !
			// idPool.remove(id); Need to figure out a better way to do this [RC]
			var id = e.id;
			idPool.push(id);
			_generations[id] = (_generations[id] + 1) % Entity.GENERATION_COUNT;
			statuses[id] = Cached;
		}
	}

	@:allow(ecs.Entity) inline function add(e:Entity) {
		if (status(e) == Inactive) {
			statuses[e.id] = Active;
			_entities.add(e);
			for (v in views)
				v.addIfMatched(e);
		}
	}

	@:allow(ecs.Entity) inline function remove(e:Entity) {
		if (status(e) == Active) {
			for (v in views)
				v.removeIfExists(e);
			_entities.remove(e);
			statuses[e.id] = Inactive;
		}
	}

	@:allow(ecs.Entity) inline function status(e:Entity):Status {
		if (e.id <= ecs.Entity.INVALID_ID)
			return Status.Invalid;
		return statuses[e.id];
	}

	@:allow(ecs.Entity) inline function pauseAdding(id:Entity) {}

	@:allow(ecs.Entity) inline function resumeAdding(id:Entity) {}

	@:allow(ecs.Entity) inline function getTag(e:Entity, tag:Int) {
		final offset = tag >> 5;
		final bitOffset = tag - (offset << 5);
		final tagField = tags[e.id * TAG_STRIDE + offset];
		return tagField & (1 << bitOffset) != 0;
	}

	@:allow(ecs.Entity) inline function setTag(e:Entity, tag:Int) {
		var id = e.id;
		//		trace('Setting tag  ${tag} on ${id}');
		final offset = tag >> 5;
		final bitOffset = tag - (offset << 5);
		final idx = id * TAG_STRIDE + offset;
		final tagField = tags[id * TAG_STRIDE + offset];
		tags[id * TAG_STRIDE + offset] = tagField | (1 << bitOffset);
	}

	@:allow(ecs.Entity) inline function clearTag(e:Entity, tag:Int) {
		var id = e.id;
		final offset = tag >> 5;
		final bitOffset = tag - (offset << 5);
		final idx = id * TAG_STRIDE + offset;
		final tagField = tags[id * TAG_STRIDE + offset];
		tags[id * TAG_STRIDE + offset] = tagField & ~(1 << bitOffset);
	}

	// var removeAllFunction:(ecs.Entity) -> Void = null;
	// public dynamic function numComponentTypes() {
	// 	return 0;
	// }
	// public dynamic function componentNames():Array<String> {
	// 	return [];
	// }
	// public dynamic function entityComponentNames(e:ecs.Entity):Array<String> {
	// 	return [];
	// }
	// public dynamic function componentsToStrings(e:ecs.Entity):Array<String> {
	// 	return [];
	// }
	// public dynamic function componentsToDynamic(e:ecs.Entity):Array<Dynamic> {
	// 	return [];
	// }
	// public dynamic function componentNameToString(e:ecs.Entity, name:String):String {
	// 	return "";
	// }
	// macro function removeAllComponents(e:Expr):Expr {
	// 	return macro {
	// 		if (removeAllFunction == null) {
	// 			var c = Type.resolveClass("LateCalls");
	// 			if (c == null)
	// 				throw "Internal ecs Error - no LateCalls class available in reflection. Required compilation macro: --macro ecs.core.macro.Global.setup()";
	// 			var i = Type.createInstance(c, null);
	// 			if (i == null)
	// 				throw "Internal ecs Error - could not instance LateCalls. Required compilation macro: --macro ecs.core.macro.Global.setup()";
	// 			removeAllFunction = i.getRemoveFunc();
	// 		}
	// 		removeAllFunction($e);
	// 	}
	// }

	@:allow(ecs.Entity) inline function removeAllComponentsOf(e:ecs.Entity) {
		//        var id = e.id;
		if (status(e) == Active) {
			for (v in views) {
				v.removeIfExists(e);
			}
		}

		Workflow.removeAllComponents(e);
	}

	@:allow(ecs.Entity) inline function printAllComponentsOf(id:Int):String {
		var ret = '#$id:';

		return ret.substr(0, ret.length - 1);
	}

	@:allow(ecs.Entity) inline function getGeneration(id:Int):Int {
		return _generations[id];
	}
}
