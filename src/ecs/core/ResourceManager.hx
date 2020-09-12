package ecs.core;

import haxe.ds.Vector;
import rx.Unit;
import rx.Subject;
import rx.observables.IObservable;
import bits.Bits;
import ecs.macros.ResourceMacros;

class ResourceManager
{
    /**
     * Bits which indicate which resources are currently stored in the system.
     */
    public final flags : Bits;

    /**
     * Vector for storing all active resources.
     */
    final resources : Vector<Any>;

    /**
     * Subject which emits a new unit value when a resource is added.
     */
    final onResourcesAdded : Subject<Unit>;

    /**
     * Subject which emits a new unit value when a resource is removed.
     */
    final onResourcesRemoved : Subject<Unit>;

    public function new()
    {
        flags              = createResourceBits();
        resources          = createResourceVector();
        onResourcesAdded   = new Subject();
        onResourcesRemoved = new Subject();
    }

    /**
     * Observable that ticks a value every time a resource is added to the world.
     * @return IObservable<Unit>
     */
    public function resourcesAdded() : IObservable<Unit>
    {
        return onResourcesAdded;
    }

    /**
     * Observable that ticks a value every time a resource is removed from the world.
     * @return IObservable<Unit>
     */
    public function resourcesRemoved() : IObservable<Unit>
    {
        return onResourcesRemoved;
    }

    /**
     * Gets the resource with the provided ID.
     * If the resource is not in the system null is returned.
     * @param _id Resource ID.
     */
    public function get(_id : Int)
    {
        return resources[_id];
    }

    /**
     * Add a resource into the world.
     * @param _id Resource ID.
     * @param _resource Resource object.
     */
    public function insert(_id : Int, _resource : Any)
    {
        resources[_id] = _resource;

        flags.set(_id);
    }

    /**
     * Remove a resource from the world.
     * @param _id Resource ID.
     */
    public function remove(_id : Int)
    {
        resources[_id] = null;

        flags.unset(_id);
    }
}