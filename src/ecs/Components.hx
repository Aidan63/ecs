package ecs;

import haxe.ds.Vector;

class Components<T> {
    // final manager : ComponentManager;
    // final id : Int;
    final components : Vector<T>;

    public function new() {
        components = new Vector(1024);
    }

    public function set(_entity : Entity, _component : T) {
        components[_entity] = _component;
    }

    public function get(_entity : Entity) : T {
        return components[_entity];
    }
}