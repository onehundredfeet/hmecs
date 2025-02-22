package ecs.core.macro;

#if macro
import ecs.core.macro.MacroTools.*;
import haxe.macro.Expr.ComplexType;
import haxe.macro.Printer;
import ecs.utils.Const;

using ecs.core.macro.MacroTools;
using haxe.macro.Context;
using haxe.macro.ComplexTypeTools;
using haxe.macro.TypeTools;
using ecs.core.macro.Extensions;

class ViewsOfComponentBuilder {
	public static final VIEW_OF_NAMESPACE = "ecs.viewsof";

	// viewsOfComponentTypeName / viewsOfComponentType
	public static function createViewsOfComponentType(componentComplexType:ComplexType, pos):haxe.macro.Type {
		//		Context.warning('Making view of component ${componentComplexType.toString()}', Context.currentPos());
		var errorStage = "";
		var componentTypeName = componentComplexType.followName(pos);
		var viewsOfComponentTypeName = 'ViewsOfComponent' + componentComplexType.typeFullName(pos);
		var viewsOfComponentTypePath = VIEW_OF_NAMESPACE + "." + viewsOfComponentTypeName;
		var viewsOfComponentCT = viewsOfComponentTypePath.asComplexType();
		var viewsOfComponentType = viewsOfComponentCT.toTypeOrNull(Context.currentPos());

		errorStage = "checking in cache";
		if (viewsOfComponentType == null) {
			// first time call in current build
			// type was not cached in previous build
			errorStage = "building";

			var viewsOfComponenttpath = tpath([], viewsOfComponentTypeName, []);

			errorStage = "defining";

			var def = macro class $viewsOfComponentTypeName {
				static var instance = new $viewsOfComponenttpath();

				@:keep public static inline function inst():$viewsOfComponentCT {
					return instance;
				}

				// instance

				var views = new Array<ecs.core.AbstractView>();

				function new() {}

				public inline function addRelatedView(v:ecs.core.AbstractView) {
					views.push(v);
				}

				public inline function addIfMatched(id:Int) {
					for (v in views) {
						if (v.isActive()) { // This is likely a bug - Needs to be removed even if not active
							// trace('addIfMatched: $v');
							@:privateAccess v.addIfMatched(id);
						}
					}
				}

				public inline function removeIfExists(id:Int) {
					for (v in views) {
						if (v.isActive()) { // This is likely a bug - Needs to be removed even if not active
							// trace('removeIfExists: $v');
							@:privateAccess v.removeIfExists(id);
						}
					}
				}
			}

			errorStage = "calling define";

			def.defineTypeSafe(VIEW_OF_NAMESPACE, Const.ROOT_MODULE);

			#if false
			trace('ViewType: ${def.name}');
			var p = new Printer();
			trace(p.printTypeDefinition(def));
			#end

			errorStage = "post define";

			viewsOfComponentType = viewsOfComponentCT.toTypeOrNull(Context.currentPos());

			if (viewsOfComponentType == null) {
				Context.error('Could not find or create view of component type', Context.currentPos());
				return null;
			}
			errorStage = "caching";
		}

		return viewsOfComponentType;
	}

	public static function getViewsOfComponent(componentComplexType:ComplexType, pos):ComplexType {
		return createViewsOfComponentType(componentComplexType, pos).toComplexType();
	}
}
#end
