package ecs;

import haxe.ds.Vector;

#if ecs.static_loading @:generic #end class Components<T>
{
    final components : Vector<T>;

    public function new(_size)
    {
        components = new Vector(_size);
    }

    public function set(_entity : Entity, _component : T)
    {
        components[_entity.id()] = _component;
    }

    public function get(_entity : Entity) : T
    {
        return components[_entity.id()];
    }
}