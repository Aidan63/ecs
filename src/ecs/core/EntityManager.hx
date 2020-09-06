package ecs.core;

import rx.Subject;
import haxe.ds.Vector;

class EntityManager
{
    final onEntityCreated : Subject<Entity>;

    final onEntityRemoved : Subject<Entity>;

    final storage : Vector<Entity>;

    var nextID : Int;

    public function new(_max)
    {
        onEntityCreated = new Subject();
        onEntityRemoved = new Subject();
        storage         = new Vector(_max);
        nextID          = 0;
    }

    public function entityCreated() : Subject<Entity>
    {
        return onEntityCreated;
    }

    public function entityRemoved() : Subject<Entity>
    {
        return onEntityRemoved;
    }

    public function create()
    {
        final idx = nextID++;
        final e   = new Entity(idx);

        storage[idx] = e;

        onEntityCreated.onNext(e);

        return e;
    }

    public function destroy(_entity : Entity)
    {
        onEntityRemoved.onNext(_entity);
    }

    public function get(_id : Int)
    {
        return storage[_id];
    }

    public function capacity()
    {
        return storage.length;
    }
}