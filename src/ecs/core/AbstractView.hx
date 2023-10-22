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
    var _entities(default, null) = new FastEntitySet();

//    var collected = new Array<Bool>();  // Membership is already being stored

    var activations = 0;


    public function activate() {
        activations++;
        if (activations == 1) {
            Workflow._views.push(this);
            for (e in Workflow.entities) {
                addIfMatched(e);
            }
        }
    }

    public function deactivate() {
        activations--;
        if (activations == 0) {
            Workflow._views.remove(this);

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
        if (isMatched(id) && !_entities.exists(id)) {
            _entities.add(id);
            dispatchAddedCallback(id);
        }
    }

    @:allow(ecs.Workflow) function addIfMatchedNoCheck(id:Int) {
        if (isMatched(id)) {
            _entities.add(id);
            dispatchAddedCallback(id);
        }
    }


    @:allow(ecs.Workflow) function addMatchedNew(id:Int) {
        _entities.add(id);
        dispatchAddedCallback(id);
    }

    @:allow(ecs.Workflow) function removeIfExists(id:Int) {
        if(_entities.remove(id)) {
            dispatchRemovedCallback(id);
        }
    }


    @:allow(ecs.Workflow) function reset() {
        activations = 0;
        Workflow._views.remove(this);
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
