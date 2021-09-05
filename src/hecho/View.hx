package hecho;

/**
 * View  
 * 
 * @author https://github.com/deepcake
 */
#if !macro
@:genericBuild(hecho.core.macro.ViewBuilder.build())
#end
class View<Rest> extends hecho.core.AbstractView { }
