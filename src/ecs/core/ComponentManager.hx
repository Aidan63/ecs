package ecs.core;

import haxe.ds.Vector;
import bits.Bits;

class ComponentManager
{
    final entities : EntityManager;

    /**
     * All components stored in this system.
     * Index into the vector with the components ID to get all components of that type.
     */
    final components : Vector<Any>;

    /**
     * Bit flags for each entity in the universe.
     * If a bit is set then it has the component of that index / id.
     */
    public final flags : Vector<Bits>;

    public function new(_entities)
    {
        entities = _entities;
        flags    = new Vector(_entities.capacity());

#if ecs.no_dyn_load
        components = ecs.macros.ComponentMacros.createComponentVector();

        ecs.macros.ComponentMacros.setupComponents(_entities.capacity());
#else
        final meta           = haxe.rtti.Meta.getType(ComponentManager);
        final componentCount = meta.componentCount[0];
        final componentIDs   = meta.components;

        components = new Vector(componentCount);

        for (id in componentIDs)
        {
            components.set(id, new ecs.Components<Any>(_entities.capacity()));
        }
#end

        for (i in 0...flags.length)
        {
            flags[i] = new Bits();
        }
    }

    /**
     * Get the components table for the specified component ID.
     * @param _compID Unique component ID.
     */
    public function getTable<T>(_compID : Int) : Any
    {
        return components[_compID];
    }

#if ecs.no_dyn_load
    @:generic public function set<T>(_entity : Entity, _id : Int, _component : T)
    {
        (components[_id] : Components<T>).set(_entity, _component);

        flags[_entity.id()].set(_id);
    }
#else
    public function set(_entity : Entity, _id : Int, _component : Any)
    {
        (components[_id] : Components<Any>).set(_entity, _component);

        flags[_entity.id()].set(_id);
    }
#end

    public function remove(_entity : Entity, _id : Int)
    {
        flags[_entity.id()].unset(_id);
    }

    public function clear(_entity : Entity)
    {
        flags[_entity.id()].clear();
    }
}