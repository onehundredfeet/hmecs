package ecs.core;
import ecs.World;

interface ISystem {

    function __initialize__(world : World): Void;

    function __activate__():Void;

    function __deactivate__():Void;

    function __update__(dt:Float):Void;


    function isActive():Bool;

    function info(indent:String = '    ', level:Int = 0):String;


}
