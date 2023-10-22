package ecs.core;

import ecs.Entity;
/**
 * ...
 * @author https://github.com/deepcake
 */

 typedef ViewEntitySet = ecs.utils.FastEntitySet;

@:ecs_view
@:keepSub
class AbstractView {
    static var _idCount = 0;
    var _id = 0;
    public function new() {
        _id = _idCount++;
    }

    public function hashCode():Int {
        return _id;
    }
    /** List of matched entities */
    public var entities(default, null) = new ViewEntitySet();

//    var collected = new Array<Bool>();  // Membership is already being stored

    var activations = 0;


    public function activate() {
        activations++;
        if (activations == 1) {
            Workflow.views.push(this);
            for (e in Workflow.entities) {
                addIfMatched(e);
            }
        }
    }

    public function deactivate() {
        activations--;
        if (activations == 0) {
            Workflow.views.remove(this);

            for (e in entities) {
                dispatchRemovedCallback(e);
            }
            entities.removeAll();
        }
    }

    public inline function isActive():Bool {
        return activations > 0;
    }


    public inline function size():Int {
        return entities.length;
    }


    function isMatched(id:Int):Bool {
        // each required component exists in component container with this id
        // macro generated
        return false;
    }

    function isMatchedByTypes(worlds:Int, typeNames : Array<String>):Bool {
        // each required component exists in component container with this id
        // macro generated
        return false;
    }


    function dispatchAddedCallback(id:Int) {
        // macro generated
    }

    function dispatchRemovedCallback(id:Int) {
        // macro generated
    }


    @:allow(ecs.Workflow) function addIfMatched(id:Int) {
        if (isMatched(id) && !entities.exists(id)) {
            entities.add(id);
            dispatchAddedCallback(id);
        }
    }

    @:allow(ecs.Workflow) function addIfMatchedNoCheck(id:Int) {
        if (isMatched(id)) {
            entities.add(id);
            dispatchAddedCallback(id);
        }
    }


    @:allow(ecs.Workflow) function addMatchedNew(id:Int) {
        entities.add(id);
        dispatchAddedCallback(id);
    }

    @:allow(ecs.Workflow) function removeIfExists(id:Int) {
        if(entities.remove(id)) {
            dispatchRemovedCallback(id);
        }
    }


    @:allow(ecs.Workflow) function reset() {
        activations = 0;
        Workflow.views.remove(this);
        for (e in entities) {
            dispatchRemovedCallback(e);
        }
        entities.removeAll();
//        collected.splice(0, collected.length);
    }


    public function toString():String {
        return 'AbstractView';
    }


}
