package ecs.core;

class ComponentManager {
    final entities : EntityManager;

    final components : Array<Components<Any>>;

    public function new(_entities) {
        entities   = _entities;
        components = [];
    }

    public function getTable(_compID : Int) {
        return components[_compID];
    }
}