package ecs.core;

import ecs.Entity;
import ecs.utils.FastEntitySet;
/**
 * ...
 * @author https://github.com/deepcake, https://github.com/onehundredfeet
 */


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

    public var entities(get,null):ReadOnlyFastEntitySet;
    inline function get_entities() {
        return _entities;
    }

    /** List of matched entities */
    var _entities = new FastEntitySet();

//    var collected = new Array<Bool>();  // Membership is already being stored

    var activations = 0;


    public function activate(world:Int) {
        activations++;
        if (activations == 1) {
            Workflow.world(world)._views.push(this);
            for (e in Workflow.world(world).entities) {
                addIfMatched(e);
            }
        }
    }

    public function deactivate(world:Int) {
        activations--;
        if (activations == 0) {
            Workflow.world(world)._views.remove(this);

            for (e in _entities) {
                dispatchRemovedCallback(e);
            }
            _entities.removeAll();
        }
    }

    public inline function isActive():Bool {
        return activations > 0;
    }


    public inline function size():Int {
        return _entities.length;
    }


    function isMatched(id:Entity):Bool {
        // each required component exists in component container with this id
        // macro generated
        return false;
    }

    function isMatchedByTypes(worlds:Int, typeNames : Array<String>):Bool {
        // each required component exists in component container with this id
        // macro generated
        return false;
    }


    function dispatchAddedCallback(id:Entity) {
        // macro generated
    }

    function dispatchRemovedCallback(id:Entity) {
        // macro generated
    }


    @:allow(ecs.Workflow, ecs.World) function addIfMatched(id:Entity) {
        // trace(this);
        if (isMatched(id) && !_entities.exists(id)) {
            // trace('ADDING $id');
            _entities.add(id);
            dispatchAddedCallback(id);
        }
    }

    @:allow(ecs.Workflow, ecs.World) function addIfMatchedNoCheck(id:Entity) {
        if (isMatched(id)) {
            _entities.add(id);
            dispatchAddedCallback(id);
        }
    }


    @:allow(ecs.Workflow, ecs.World) function addMatchedNew(id:Entity) {
        _entities.add(id);
        dispatchAddedCallback(id);
    }

    @:allow(ecs.Workflow, ecs.World) function removeIfExists(id:Entity) {
        if(_entities.remove(id)) {
            dispatchRemovedCallback(id);
        }
    }


    @:allow(ecs.Workflow, ecs.World) function reset(world:Int) {
        activations = 0;
        Workflow.world(world)._views.remove(this);
        for (e in _entities) {
            dispatchRemovedCallback(e);
        }
        _entities.removeAll();
//        collected.splice(0, collected.length);
    }


    public function toString():String {
        return 'AbstractView';
    }


}
