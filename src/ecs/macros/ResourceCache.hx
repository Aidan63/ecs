package ecs.macros;

import haxe.macro.Expr.ComplexType;

using Safety;
using haxe.macro.ComplexTypeTools;

private final resources = new Map<String, Int>();

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
function getResourceID(_ct : ComplexType)
{
    final name = _ct.toString();

    if (resources.exists(name))
    {
        return resources.get(name);
    }

    throw '$name has not been registered as a resource';
}

function registerResource(_ct : ComplexType)
{
    final name = _ct.toString();

    return if (!resources.exists(name))
    {
        final id = resourceIncrementer++;

        resources.set(name, id);

        id;
    }
    else
    {
        resources.get(name).unsafe();
    }
}