package ecs.core;

import haxe.ds.Vector;

import ecs.macros.ComponentsCache;

class ComponentManager {
    final entities : EntityManager;

    final components : Vector<Components<Any>>;

    public function new(_entities) {
        entities   = _entities;
        components = createComponentVector();
    }

    public function getTable(_compID : Int) {
        return components[_compID];
    }

    public function set(_entity : Entity, _id : Int, _component : Any) {
        components[_id].set(_entity, _component);
    }
}