package ecs.core.macro;
#if macro
import haxe.macro.Type;
import haxe.macro.Expr;

using ecs.core.macro.MacroTools;
using haxe.macro.Context;
using haxe.macro.ComplexTypeTools;
using haxe.macro.TypeTools;
using Lambda;
using tink.MacroApi;
#end

class Global {
	#if macro
	static var addedLate = false;
	static var lateDef:TypeDefinition;

	static function defineLateCalls():TypeDefinition {
		var containers = ComponentBuilder.containerNames();
		var removeExprs = new Array<Expr>();

		for (container in containers) {
			var info = ComponentBuilder.getComponentContainerInfoByName(container);
			removeExprs.push(info.getRemoveExpr(macro e));
		}

		var lateClass = macro class LateCalls {
			public static function removeAllComponents(e:ecs.Entity) {
				trace('Removing all on ${e}');
				$b{removeExprs}
			}

			public function getRemoveFunc():(ecs.Entity) -> Void {
				return removeAllComponents;
			}
		};

		// var p = new Printer();
		// trace ('${p.printTypeDefinition(lateClass)}');

		lateClass.meta.push({name: ":keep", pos: Context.currentPos()});
		return lateClass;
	}

	
	#end

	public macro static function setup():Expr {
		//trace ('now!');
		defineLateCalls().defineTypeSafe("ecs");

		var x = macro {
			trace('setting remove all function'); 
			@:privateAccess Workflow.removeAllFunction = ecs.LateCalls.removeAllComponents; 
		}
		return x;
	}


}