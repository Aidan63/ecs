package ecs.macros;

import haxe.ds.Option;
import haxe.macro.Type;
import haxe.macro.Context;

using Safety;

private final components = new Map<String, { id : Int, type : Type }>();

private var componentIncrementer = 0;

/**
 * Returns the total number of unique components.
 */
function getComponentCount()
{
    return componentIncrementer;
}

function getComponentMap()
{
    return components;
}

/**
 * Given a complex type it will return an integer representing that type.
 * If this type has not yet been seen the returned integer is stored for future lookups.
 * @param _ct ComplexType to get ID for.
 */
function registerComponent(_hash : String, _type : Type) : Int
{
    return if (components.exists(_hash))
    {
        components.get(_hash).unsafe().id;
    }
    else
    {
        final id = componentIncrementer++;

        components.set(_hash, { id : id, type : _type });

        id;
    }
}

/**
 * Returns the component ID of a complex type.
 * If the complex type has not been registered as a component `None` is returned.
 * @param _type Complex type of the component.
 * @return Option<Int>
 */
function getComponentID(_type : String) : Option<Int>
{
    return if (components.exists(_type))
    {
        Some(components.get(_type).unsafe().id);
    }
    else
    {
        None;
    }
}