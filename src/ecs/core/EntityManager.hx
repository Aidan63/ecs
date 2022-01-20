package ecs.core;

import haxe.ds.Vector;

class EntityManager
{
    final storage : Vector<Entity>;
    final recycleBin : Vector<Int>;
    
    var nextID : Int;
    var binSize : Int;

    public function new(_max)
    {
        storage = new Vector(_max);
        recycleBin = new Vector(_max);
        nextID  = 0;
	binSize = 0;
    }

    public function create()
    {
        if (binSize > 0)
        {
            return storage[recycleBin[--binSize]];
        }
	   
        final idx = nextID++;
        final e   = new Entity(idx);

        storage[idx] = e;

        return e;
    }
    
    public function destroy(_id : Int)
    {
        recycleBin[binSize++] = _id;
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
