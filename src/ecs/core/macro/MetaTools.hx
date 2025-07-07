package ecs.core.macro;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;

using ecs.core.macro.MacroTools;
using Lambda;

class MetaTools {
	public static final SKIP_META = ['skip'];
	public static final PRINT_META = ['print', ':print'];
	public static final ADD_META = ['added', 'ad', 'a', ':added', ':ad', ':a'];
	public static final ADD_COMPONENT_META = ['added_component', ':added_component'];
	public static final REMOVED_COMPONENT_META = ['removed_component', ':removed_component'];
	public static final RM_META = ['removed', 'rm', 'r', ':removed', ':rm', ':r'];
	public static final UPD_META = ['update', 'up', 'u', ':update', ':up', ':u'];
	public static final LISTEN_META = ['listen', ':listen'];
	public static final PARALLEL_META = [':parallel', 'parallel', 'p', ':p'];
	public static final FORK_META = [':fork', 'fork', 'f', ':f'];
	public static final JOIN_META = [':join', 'join', 'j', ":j"];
	public static final LOCAL_META = [':local', 'local', 'l', ":l"];
	public static final WORLD_META = [':world', 'world', 'w', ":w"];
	public static final VIEW_FUNC_META = UPD_META.concat(ADD_META).concat(RM_META);

	public static function containsMeta(field:Field, metas:Array<String>) {
		var metaData = field.meta;
		if (metaData != null) {
			for (t in metas) {
				if (metaData.exists((e) -> e.name == t)) {
					return true;
				}
			}
		}
		return false;
	}

	public static function notSkipped(field:Field) {
		return !MetaTools.containsMeta(field, MetaTools.SKIP_META);
	}

	// public static function isSpecialParameter(meta:Metadata) : Bool{
	// 	if (meta == null)
	// 		return false;

	// 	var mm = meta.toMap();
	// 	for (l in LOCAL_META) if (mm.exists(l)) return true;
	// 	for (l in WORLD_META) if (mm.exists(l)) return true;
	// 	return false;
	// }
	
	public static function isSpecialParameter(mm : Map<String, Array<Array<Expr>>>) : Bool{
		if (mm == null)
			return false;

		for (l in LOCAL_META) if (mm.exists(l)) return true;
		for (l in WORLD_META) if (mm.exists(l)) return true;
		return false;
	}

	public static function hasAttr(mm : Map<String, Array<Array<Expr>>>, metas:Array<String>, requireExpr = false) : Bool {
		for (m in metas) if (mm.exists(m)) {
			var t = mm.get(m);
			if (!requireExpr || t.length > 0 && t[0].length > 0) {
				return true;
			} else {
				Context.fatalError('Parameter requires expression for meta ${m}', Context.currentPos());
			}
		}	
		return false;
	}
	public static function getExprForAttr(mm : Map<String, Array<Array<Expr>>>, metas:Array<String>) : Expr {
		for (m in metas) if (mm.exists(m)) {
			var t = mm.get(m);
			if (t.length > 0 && t[0].length > 0) {
				return t[0][0];
			} 
			return null;
		}	
		return null;
	}
	public static function getLocalAttrExpr(mm : Map<String, Array<Array<Expr>>>) : Expr {
		return getExprForAttr(mm, LOCAL_META);
	}
	public static function isLocal(mm : Map<String, Array<Array<Expr>>>) : Bool {
		return hasAttr(mm, LOCAL_META, true);
	}
	public static function isWorld(mm : Map<String, Array<Array<Expr>>>) : Bool {
		return hasAttr(mm, WORLD_META);
	}

}
#end
