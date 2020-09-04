package ecs.core;

import haxe.ds.Vector;
import ecs.core.ComponentManager;
import ecs.macros.FamilyCache;

using rx.Observable;

class FamilyManager
{
    final components : ComponentManager;

    final resources : ResourceManager;

    final families : Vector<Family>;

    public function new(_components, _resources)
    {
        components = _components;
        resources  = _resources;
        families   = createFamilyVector();

        setupFamilies();

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
        final compFlags = components.flags[_entity];

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
        final compFlags = components.flags[_entity];

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
            if (!family.hasResources && resources.flags.areSet(family.resourcesMask))
            {
                family.hasResources = true;
            }
        }
    }

    function onResourcesRemoved(_)
    {
        for (family in families)
        {
            if (family.hasResources && !resources.flags.areSet(family.resourcesMask))
            {
                family.hasResources = false;
            }
        }
    }
}