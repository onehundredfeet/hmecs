package hcqe;

/**
 * View  
 * 
 * @author https://github.com/deepcake
 */
#if !macro
@:genericBuild(hcqe.core.macro.ViewBuilder.build())
#end
class View<Rest> extends hcqe.core.AbstractView { }
