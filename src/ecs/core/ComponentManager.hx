package ecs.core;

import rx.observables.IObservable;
import rx.Subject;
import bits.Bits;
import haxe.ds.Vector;

import ecs.macros.ComponentsCache;

class ComponentManager
{
    final entities : EntityManager;

    final onComponentsAdded : Subject<Entity>;

    final onComponentsRemoved : Subject<Entity>;

    /**
     * Bit flags for each entity in the universe.
     * If a bit is set then it has the component of that index / id.
     */
    public final flags : Vector<Bits>;

    /**
     * All components stored in this system.
     * Index into the vector with the components ID to get all components of that type.
     */
    public final components : Vector<Any>;

    public function new(_entities)
    {
        entities            = _entities;
        onComponentsAdded   = new Subject();
        onComponentsRemoved = new Subject();

        flags      = new Vector(1024);
        components = createComponentVector();

        setupComponents();

        for (i in 0...flags.length) {
            flags[i] = new Bits();
        }
    }

    public function componentsAdded() : IObservable<Entity>
    {
        return onComponentsAdded;
    }

    public function componentsRemoved() : IObservable<Entity>
    {
        return onComponentsRemoved;
    }

    /**
     * Get the components table for the specified component ID.
     * @param _compID Unique component ID.
     */
    public function getTable<T>(_compID : Int) : Any
    {
        return components[_compID];
    }

    @:generic public function set<T>(_entity : Entity, _id : Int, _component : T)
    {
        (components[_id] : Components<T>).set(_entity, _component);

        flags[_entity].set(_id);
    }

    public function remove(_entity : Entity, _id : Int)
    {
        flags[_entity].unset(_id);
    }
}