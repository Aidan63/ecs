package ecs.macros;

import haxe.macro.Type;
import ecs.macros.Helpers;

using Safety;
using haxe.macro.Tools;

private final resources = new Map<String, Int>();

private final complexTypes = new Array<Type>();

private var resourceIncrementer = 0;

/**
 * Returns the total number of unique components.
 */
function getResourceCount()
{
    return resourceIncrementer;
}

/**
 * Given a complex type it will return an integer representing that type.
 * If this type has not yet been seen the returned integer is stored for future lookups.
 * @param _ct ComplexType to get ID for.
 */
function getResourceID(_type : Type)
{
    final name = getTypeName(_type);

    return if (resources.exists(name))
    {
        resources.get(name);
    }
    else
    {
        final id = resourceIncrementer++;

        resources.set(name, id);
        complexTypes.push(_type);

        id;
    }
}