package ecs.core;

import haxe.ds.Vector;
import ecs.core.ComponentManager;
import ecs.macros.FamilyMacros;

using rx.Observable;

class FamilyManager
{
    final components : ComponentManager;

    final resources : ResourceManager;

    final families : Vector<Family>;

    public function new(_components, _resources, _size)
    {
        components = _components;
        resources  = _resources;
        families   = createFamilyVector();

        setupFamilies(_size);

        components.componentsAdded().subscribeFunction(onComponentsAdded);
        components.componentsRemoved().subscribeFunction(onComponentsRemoved);
        resources.resourcesAdded().subscribeFunction(onResourcesAdded);
        resources.resourcesRemoved().subscribeFunction(onResourcesRemoved);
    }

    public function get(_index : Int)
    {
        return families[_index];
    }

    function onComponentsAdded(_entity : Entity)
    {
        final compFlags = components.flags[_entity.id()];

        for (family in families)
        {
            if (compFlags.areSet(family.componentsMask))
            {
                family.add(_entity);
            }
		}
    }

    function onComponentsRemoved(_entity : Entity)
    {
        final compFlags = components.flags[_entity.id()];

        for (family in families)
        {          
            if (!compFlags.areSet(family.componentsMask))
            {
                family.remove(_entity);
            }
        }
    }

    function onResourcesAdded(_)
    {
        for (family in families)
        {
            if (!family.isActive() && resources.flags.areSet(family.resourcesMask))
            {
                family.activate();
            }
        }
    }

    function onResourcesRemoved(_)
    {
        for (family in families)
        {
            if (family.isActive() && !resources.flags.areSet(family.resourcesMask))
            {
                family.deactivate();
            }
        }
    }
}