package ecs.macros;

import haxe.ds.Option;
import haxe.macro.Expr.ComplexType;

using haxe.macro.ComplexTypeTools;

private final components = new Map<String, Int>();

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
function registerComponent(_type : ComplexType)
{
    final name = _type.toString();

    return if (components.exists(name))
    {
        components.get(name);
    }
    else
    {
        final id = componentIncrementer++;

        components.set(name, id);

        id;
    }
}

/**
 * Returns the component ID of a complex type.
 * If the complex type has not been registered as a component `None` is returned.
 * @param _type Complex type of the component.
 * @return Option<Int>
 */
function getComponentID(_type : ComplexType) : Option<Int>
{
    final name = _type.toString();

    return if (components.exists(name))
    {
        Some(components.get(name));
    }
    else
    {
        None;
    }
}