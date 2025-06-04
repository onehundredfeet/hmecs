package ecs;

/**
 * System  
 * 
 * You must extend this class to make your own system.  
 * 
 * Functions with `@update` (or `@up`, or `@u`) meta are called for each entity that contains all the defined components.  
 * So, a function like: 
 * ```
 *   @u function f(a:A, b:B, entity:Entity) { }
 * ```
 * does a two things: 
 * - Defines and initializes a `View<A, B>` (if the `View<A, B>` has not been previously defined)  
 * - Creates a loop in the system update method  
 * ```
 *   for (entity in viewOfAB.entities) {  
 *     f(entity.get(A), entity.get(B), entity);  
 *   }  
 * ```
 * 
 * Functions with `@added`, `@ad`, `@a` meta become callbacks that will be called on each entity to be assembled by the view.  
 * Functions with `@removed`, `@rm`, `@r` does the same but when entity is removed.  
 * 
 * You can define the `View` manually (no initialization required)  
 * 
 * @author https://github.com/deepcake
 */
import haxe.macro.Printer;
#if macro
import haxe.macro.Expr;

using ecs.core.macro.MacroTools;
#end

enum RelativeUpdate {
	Agnostic; // order independent
	Before; // Specified system needs to go before the system
	After; // Specified system needs to go after the system
	First; // Specified system needs to go first
	Last; // Specified system needs to go last
}

#if !macro
@:autoBuild(ecs.core.macro.SystemBuilder.build())
#end
@:keepSub
class System implements ecs.core.ISystem {
	#if ecs_profiling
	var __updateTime__ = .0;
	#end

	var activated = false;
	var __world__:World;
	var __world_id__:Int;

	@:noCompletion public function __initialize__(world:World) {
		addDependencies(__world__);
		onInitialize(world);
	}

	// will get replaced by the macro
	@:noCompletion public function __activate__() {
		onactivate();
	}

	@:noCompletion public function __deactivate__() {
		ondeactivate();
	}

	@:noCompletion public function __update__(dt:Float) {
		// macro
	}

	public function isActive():Bool {
		return activated;
	}

	public function info(indent = '    ', level = 0):String {
		var span = StringTools.rpad('', indent, indent.length * level);

		#if ecs_profiling
		return '$span$this : $__updateTime__ ms';
		#else
		return '$span$this';
		#end
	}

	/**
	 * Calls when system is added to the workflow
	 */
	public function onactivate() {}

	public function prime(world:World) {}

	public function addDependencies(world:World) {}

	public function onInitialize(world:World) {}

	/**
	 * Calls when system is removed from the workflow
	 */
	public function ondeactivate() {}

	public function toString():String
		return 'System';

	static function relativeToAbsoluteUpdate(updateType:RelativeUpdate) : ecs.World.UpdatePreference {
//        trace('relativeToAbsoluteUpdate $updateType');
		return switch (updateType) {
			case null, RelativeUpdate.Agnostic, RelativeUpdate.Before, RelativeUpdate.After:
				ecs.World.UpdatePreference.Agnostic;
			case RelativeUpdate.First:
				ecs.World.UpdatePreference.First;
			case RelativeUpdate.Last:
				ecs.World.UpdatePreference.Last;
		};
	}

    function addUpdateDependency(sysType:Class<ecs.System>, updateType:RelativeUpdate) {
        switch (updateType) {
			case RelativeUpdate.Before:
                trace('Adding before (the current on is after the specified one)');
				updateAfter(sysType);
			case RelativeUpdate.After:
                trace('Adding after (the current on is before the specified one)');
				updateBefore(sysType);
			case RelativeUpdate.First:
				updateAfter(sysType);
			case RelativeUpdate.Last:
				updateBefore(sysType);
            case null:
			default:
				// do nothing
		}
        return this;
    }
	macro function dependsOn(This:ExprOf<ecs.System>, sysType:ExprOf<Class<ecs.System>>, ?updateType:ExprOf<RelativeUpdate>,
			createSys:Bool = true) {
		#if macro
        var cn = haxe.macro.Context.getLocalClass().get().name;
        var tn = '$sysType';
		var blockExpr = [macro var x = null];
		if (createSys) {
            blockExpr.push(macro if ($This == null) 
                throw ('This is null for ' + $v{tn}));
                blockExpr.push(macro if ($This.__world__ == null) 
                throw ('World is null for ' + $v{tn}));
        
            var create = World._prepareSystem(macro $This.__world__, sysType, macro ecs.System.relativeToAbsoluteUpdate($updateType));
			blockExpr.push(macro x = $create);            
		}

        if (updateType != null) {
            blockExpr.push(macro $This.addUpdateDependency($sysType, $updateType));
        }
        blockExpr.push(macro x);
		var res = EBlock(blockExpr).at(sysType.pos);

		return res;
		#end
	}

	function updateBefore(type:Class<ecs.System>) {
		if (_updateBefore.indexOf(type) == -1) {
			_updateBefore.push(type);
			__world__.orderDirty = true;
		}
	}

	function updateAfter(type:Class<ecs.System>) {
		if (_updateAfter.indexOf(type) == -1) {
            trace('Adding $type to _updateAfter');
			_updateAfter.push(type);
            __world__.orderDirty = true;
		}
	}

	@:allow(ecs.World) var _updateBefore:Array<Class<ecs.System>> = [];
	@:allow(ecs.World) var _updateAfter:Array<Class<ecs.System>> = [];
}
