package ecs.core;

import ecs.ds.Signal;
import haxe.ds.Vector;

class EntityManager
{
    final storage : Vector<Entity>;

    var nextID : Int;

    public function new(_max)
    {
        storage = new Vector(_max);
        nextID  = 0;
    }

    public function create()
    {
        final idx = nextID++;
        final e   = new Entity(idx);

        storage[idx] = e;

        return e;
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