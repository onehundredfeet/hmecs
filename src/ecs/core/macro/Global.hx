package ecs.core.macro;
import haxe.macro.Printer;
#if macro
import haxe.macro.Type;
import haxe.macro.Expr;
import ecs.utils.Const;

using ecs.core.macro.MacroTools;
using ecs.core.macro.Extensions;
using haxe.macro.Context;
using haxe.macro.ComplexTypeTools;
using haxe.macro.TypeTools;
using Lambda;

#end

class Global {
	#if macro
	static var addedLate = false;
	static var lateDef:TypeDefinition;

	static function defineLateCalls():TypeDefinition {
		var containerNames = [for (c in ComponentBuilder.componentTypeNames())  c];
		var removeExprs = new Array<Expr>();
		var nameExprs = containerNames.map( (x) -> EConst(CString(x)).at() );
  
		var countExpr : Expr = EConst( CInt(Std.string(containerNames.length))).at();

		#if ecs_late_debug
		trace('Container count is ${containerNames.length} expr ${countExpr}');

		for (i in 0...containerNames.length) {
			trace('Component ${i} name: ${containerNames[i]}');
		}
		#end

		var infos = containerNames.map( (x) -> ComponentBuilder.containerInfo(x) );

		for (info in infos) {
			removeExprs.push(info.getRemoveExpr(macro e));
		}
 
		var listComponentsExists = infos.map( (x) -> {
			var testExpr = x.getExistsExpr(macro e );
			var name = EConst(CString(x.name)).at();

			return macro if ($testExpr) componentNames.push( $name );
		});

		var toStringComponents = infos.map( (x) -> {
			var testExpr = x.getExistsExpr(macro e );
			var name = EConst(CString(x.name)).at();
			var getExpr = x.getGetExpr(macro e );

			return macro if ($testExpr) strings.push( Std.string($getExpr) );
		});

		var toStringByComponentCases = infos.map( (x) -> {
			var getExpr = x.getGetExpr(macro e);
			var getStr = macro Std.string($getExpr);

			var name = EConst(CString(x.name)).at();
			var c : Case = {
				values:[name],
				expr: getStr
			};
			return c;
		});
		var toStringByComponentSwitch = 
			ESwitch(macro name, toStringByComponentCases, macro null).at();


		

		var lateClass = macro class LateCalls  {
			public static function removeAllComponents(e:ecs.Entity) {
				$b{removeExprs}
			}

			public static function listComponents( e:ecs.Entity ) {
				var componentNames = new Array<String>();
				$b{listComponentsExists}
				return componentNames;
			}
			public static function numComponentTypes() {
				return $countExpr;
			}
			static var _componentNames = $a{nameExprs};
			public static function getComponentNames() : Array<String> {
				return _componentNames;
			}

			public function getRemoveFunc():(ecs.Entity) -> Void {
				return removeAllComponents;
			}

			public static function componentsToStrings(e:ecs.Entity) : Array<String> {
				var strings = [];

				$b{toStringComponents}
				return strings;
			}

			public static function componentNameToString(e:ecs.Entity, name : String) : String {
				return $toStringByComponentSwitch;
			}
		};

		//var p = new Printer();
		//trace ('${p.printTypeDefinition(lateClass)}');

		lateClass.meta.push({name: ":keep", pos: Context.currentPos()});
		return lateClass;
	}

	#end

	public macro static function setup():Expr {
		//trace ('now!');
		defineLateCalls().defineTypeSafe("ecs", Const.ROOT_MODULE);

		//ViewBuilder.createAllViewType();
		var x = macro {
			trace('ECS: Setting up ECS late bind functions'); 
			@:privateAccess Workflow.removeAllFunction = ecs.LateCalls.removeAllComponents; 
			@:privateAccess Workflow.numComponentTypes = ecs.LateCalls.numComponentTypes;
			@:privateAccess Workflow.componentNames = ecs.LateCalls.getComponentNames;
			@:privateAccess Workflow.entityComponentNames = ecs.LateCalls.listComponents;
			@:privateAccess Workflow.componentsToStrings = ecs.LateCalls.componentsToStrings;
			@:privateAccess Workflow.componentNameToString = ecs.LateCalls.componentNameToString;
		}
		return x;
	}


}
