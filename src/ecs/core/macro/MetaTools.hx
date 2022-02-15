package ecs.core.macro;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;

using Lambda;

class MetaTools {
	public static final SKIP_META = ['skip'];
	public static final PRINT_META = ['print'];
	public static final AD_META = ['added', 'ad', 'a', ':added', ':ad', ':a'];
	public static final RM_META = ['removed', 'rm', 'r', ':removed', ':rm', ':r'];
	public static final UPD_META = ['update', 'up', 'u', ':update', ':up', ':u'];
	public static final PARALLEL_META = [':parallel', 'parallel', 'p', ':p'];
	public static final FORK_META = [':fork', 'fork', 'f', ':f'];
	public static final JOIN_META = [':join', 'join', 'j', ":j"];
	public static final VIEW_FUNC_META = UPD_META.concat(AD_META).concat(RM_META);


	public static function containsMeta(field:Field, metas:Array<String>) {
		var metaData = field.meta;
		if (metaData != null) {
			for (t in metas) {
				if (metaData.exists( (e) -> e.name == t)) {
					return true;
				}
			}
		}
		return false;
	}

	public static function notSkipped(field:Field) {
		return !MetaTools.containsMeta(field, MetaTools.SKIP_META);
	}
}
#end
