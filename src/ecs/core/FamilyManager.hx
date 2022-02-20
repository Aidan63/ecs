package ecs.core;

import haxe.ds.Vector;
import ecs.core.ComponentManager;

class FamilyManager
{
    final components : ComponentManager;

    final resources : ResourceManager;

    final families : Vector<Family>;

    public final number : Int;

    public function new(_components, _resources, _families)
    {
        components = _components;
        resources  = _resources;
        families   = _families;
        number     = families.length;
    }

    public function get(_index : Int)
    {
        return families[_index];
    }

    public function tryActivate(_id : Int)
    {
        if (!families[_id].isActive() && resources.flags.areSet(families[_id].resourcesMask))
        {
            families[_id].activate();
        }
    }

    public function tryDeactivate(_id : Int, resourceID : Int)
    {
        if (!resources.flags.isSet(resourceID))
        {
            return;
        }
        if (!families[_id].isActive())
        {
            return;
        }
        if (families[_id].resourcesMask.isSet(resourceID))
        {
            families[_id].deactivate();
        }
    }

    public function whenEntityDestroyed(_entity : Entity)
    {
        for (family in families)
        {          
            family.remove(_entity);
        }
    }
}