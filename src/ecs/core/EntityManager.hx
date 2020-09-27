package ecs.core;

import ecs.ds.Signal;
import haxe.ds.Vector;

class EntityManager
{
    public final onEntityCreated : Signal<Entity>;

    public final onEntityRemoved : Signal<Entity>;

    final storage : Vector<Entity>;

    var nextID : Int;

    public function new(_max)
    {
        onEntityCreated = new Signal();
        onEntityRemoved = new Signal();
        storage         = new Vector(_max);
        nextID          = 0;
    }

    public function create()
    {
        final idx = nextID++;
        final e   = new Entity(idx);

        storage[idx] = e;

        onEntityCreated.notify(e);

        return e;
    }

    public function destroy(_entity : Entity)
    {
        onEntityRemoved.notify(_entity);
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