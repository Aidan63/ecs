package ecs.core;

import bits.Bits;
import rx.observables.IObservable;
import rx.Unit;
import rx.Subject;
import haxe.ds.Vector;

class ResourceManager
{
    public final flags : Bits;

    final resources : Vector<Any>;

    final onResourcesAdded : Subject<Unit>;

    final onResourcesRemoved : Subject<Unit>;

    public function new()
    {
        resources          = new Vector(10);
        onResourcesAdded   = new Subject();
        onResourcesRemoved = new Subject();
        flags              = new Bits(10);
    }

    public function resourcesAdded() : IObservable<Unit>
    {
        return onResourcesAdded;
    }

    public function resourcesRemoved() : IObservable<Unit>
    {
        return onResourcesRemoved;
    }

    @:generic public function get<T>(_idx : Int, _type : Class<T>) : T
    {
        return resources[_idx];
    }

    public function insert(_idx : Int, _resource : Any)
    {
        resources[_idx] = _resource;

        flags.set(_idx);
    }

    public function remove(_idx : Int)
    {
        resources[_idx] = null;

        flags.unset(_idx);
    }
}