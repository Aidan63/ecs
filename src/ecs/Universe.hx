package ecs;

import haxe.ds.Vector;

import ecs.macros.FamilyCache;

class Universe {
    final entities : EntityManager;
    final components : ComponentManager;
    final families : FamilyManager;
    final systems : SystemManager;

    public function new() {
        entities   = new EntityManager(1024);
        components = new ComponentManager(entities);
        families   = new FamilyManager(components);
        systems    = new SystemManager(entities, components, families);
    }
}

class EntityManager {
    final storage : Vector<Entity>;

    var nextID : Int;

    public function new(_max) {
        storage = new Vector(_max);
        nextID  = 0;
    }

    public function create() {
        final idx = nextID++;
        final e   = new Entity(idx);

        storage[idx] = e;

        return e;
    }

    public function get(_id : Int) {
        return storage[_id];
    }

    public function capacity() {
        return storage.length;
    }
}

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

class FamilyManager {
    final components : ComponentManager;

    var families : Vector<Family>;

    public function new(_components) {
        components = _components;
        families   = createVector();
    }

    public function get(_index : Int) {
        return families[_index];
    }

    static macro function createVector() {
        final count = getFamilyCount();

        return macro new haxe.ds.Vector($v{ count });
    }
}

class SystemManager {
    final entities : EntityManager;
    final components : ComponentManager;
    final families : FamilyManager;

    public function new(_entities, _components, _families) {
        entities   = _entities;
        components = _components;
        families   = _families;
    }
}