package ecs.core.macro;

#if macro
import ecs.core.macro.MacroTools.*;
import haxe.macro.Expr.ComplexType;
using ecs.core.macro.MacroTools;
using haxe.macro.Context;
using haxe.macro.ComplexTypeTools;

class ViewsOfComponentBuilder {


    // viewsOfComponentTypeName / viewsOfComponentType
    static var viewsOfComponentTypeCache = new Map<String, haxe.macro.Type>();


    public static function createViewsOfComponentType(componentComplexType:ComplexType):haxe.macro.Type {
        var errorStage = "";
        try {
        var componentTypeName = componentComplexType.followName();
        var viewsOfComponentTypeName = 'ViewsOfComponent' + componentComplexType.typeFullName();
        var viewsOfComponentType = viewsOfComponentTypeCache.get(viewsOfComponentTypeName);

        errorStage = "checking in cache";
        if (viewsOfComponentType == null) {
            // first time call in current build
            errorStage = "checking in previous build";
            try viewsOfComponentType = Context.getType(viewsOfComponentTypeName) catch (e) {
                // type was not cached in previous build
                errorStage = "building";

                var viewsOfComponentTypePath = tpath([], viewsOfComponentTypeName, []);
                var viewsOfComponentComplexType = TPath(viewsOfComponentTypePath);

                errorStage = "defining";

                var def = macro class $viewsOfComponentTypeName {

                    static var instance = new $viewsOfComponentTypePath();

                    @:keep public static inline function inst():$viewsOfComponentComplexType {
                        return instance;
                    }

                    // instance

                    var views = new Array<ecs.core.AbstractView>();

                    function new() { }

                    public inline function addRelatedView(v:ecs.core.AbstractView) {
                        views.push(v);
                    }

                    public inline function removeIfMatched(id:Int) {
                        for (v in views) {
                            if (v.isActive()) { // This is likely a bug - Needs to be removed even if not active
                                 @:privateAccess v.removeIfExists(id);
                            }
                        }
                    }
                }

                errorStage = "calling define";

                try {
                    Context.defineType(def);
                } catch (e) {
                    Context.reportError('Could not define type ${def}', Context.currentPos());
                    Context.reportError('Exception ${e.toString()}', Context.currentPos());
                    throw 'Could not define type ${viewsOfComponentTypeName}';
                }

                errorStage = "post define";

                viewsOfComponentType = viewsOfComponentComplexType.toType();
            }
            errorStage = "caching";
            // caching current build
            viewsOfComponentTypeCache.set(viewsOfComponentTypeName, viewsOfComponentType);
        }

        return viewsOfComponentType;
        }
        catch(e) {
            Context.reportError('Could not create view of component ${componentComplexType.toString()}: ${e.toString()}', Context.currentPos());
            Context.reportError('Info: ${errorStage}', Context.currentPos());
            return null;
        }
    }

    public static function getViewsOfComponent(componentComplexType:ComplexType):ComplexType {
        return createViewsOfComponentType(componentComplexType).toComplexType();
    }


}
#end
