package ecs.core;

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