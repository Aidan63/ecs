package ecs.core;

import bits.Bits;
import haxe.ds.Vector;

import ecs.macros.ComponentsCache;

class ComponentManager {
    final entities : EntityManager;

    /**
     * Bit flags for each entity in the universe.
     * If a bit is set then it has the component of that index / id.
     */
    public final flags : Vector<Bits>;

    /**
     * All components stored in this system.
     * Index into the vector with the components ID to get all components of that type.
     */
    public final components : Vector<Components<Any>>;

    public function new(_entities) {
        entities   = _entities;
        flags      = new Vector(1024);
        components = createComponentVector();

        for (i in 0...flags.length) {
            flags[i] = new Bits();
        }
    }

    public function getTable(_compID : Int)
    {
        return components[_compID];
    }

    public function set(_entity : Entity, _id : Int, _component : Any)
    {
        components[_id].set(_entity, _component);

        flags[_entity].set(_id);
    }

    public function remove(_entity : Entity, _id : Int)
    {
        flags[_entity].unset(_id);
    }
}