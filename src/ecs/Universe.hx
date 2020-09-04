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

    public function new()
    {
        entities   = new EntityManager(1024);
        components = new ComponentManager(entities);
        resources  = new ResourceManager();
        families   = new FamilyManager(components, resources);
        systems    = new SystemManager(components, families);
    }
}