package ecs.ds;

using Lambda;

class Set<T>
{
    final data : Array<T>;

    public function new()
    {
        data = [];
    }

    public function add(_value : T)
    {
        if (!data.has(_value))
        {
            data.push(_value);
        }
    }

    public function iterator() : Iterator<T>
    {
        return data.iterator();
    }
}