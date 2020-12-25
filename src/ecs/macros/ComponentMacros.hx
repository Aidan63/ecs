package ecs.macros;

import haxe.macro.Expr;
import ecs.macros.ComponentCache;

using Safety;
using haxe.macro.Tools;

/**
 * Returns an expression creating a `haxe.ds.Vector` with capacity to store all the seen components.
 */
macro function createComponentVector()
{
    return macro new haxe.ds.Vector($v{ getComponentCount() });
}

/**
 * Called in the constructor of `ecs.core.ComponentManager` and instantiates a components table for every component used to the `components` vector.
 * @param _size Expression which contains the maximum number of entities.
 */
macro function setupComponents(_size : Expr)
{
    final creation = [];

    for (key => value in getComponentMap())
    {
        final ct = value.type.toComplexType();

        creation.push(macro components.set($v{ value.id }, new ecs.Components<$ct>($e{ _size })));
    }

    return macro $b{ creation };
}