package ecs;

/**
 * View  
 * 
 * @author https://github.com/deepcake
 */
#if !macro
@:genericBuild(ecs.core.macro.ViewBuilder.build())
#end
class View<Rest> extends ecs.core.AbstractView { }
