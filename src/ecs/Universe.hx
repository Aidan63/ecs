package ecs;

import ecs.core.ResourceManager;
import ecs.core.EntityManager;
import ecs.core.FamilyManager;
import ecs.core.SystemManager;
import ecs.core.ComponentManager;

class Universe
{
    public final entities : EntityManager;
    public final components : ComponentManager;
    public final resources : ResourceManager;
    public final families : FamilyManager;
    public final systems : SystemManager;

    public function new(_maxEntities)
    {
        entities   = new EntityManager(_maxEntities);
        components = new ComponentManager(entities);
        resources  = new ResourceManager();
        families   = new FamilyManager(components, resources, _maxEntities);
        systems    = new SystemManager(components, resources, families);
    }

    public function update(_dt : Float)
    {
        systems.update(_dt);
    }
}