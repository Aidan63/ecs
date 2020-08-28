package ecs;

import haxe.ds.Vector;

import ecs.core.EntityManager;
import ecs.core.FamilyManager;
import ecs.core.SystemManager;
import ecs.core.ComponentManager;
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