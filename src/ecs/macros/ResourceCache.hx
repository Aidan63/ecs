package ecs.macros;

import haxe.ds.Option;

using Safety;

private final resources = new Map<String, Int>();

private var resourceIncrementer = 0;

/**
 * Returns the total number of unique components.
 */
function getResourceCount()
{
    return resourceIncrementer;
}

function getResourceMap()
{
    return resources;
}

/**
 * Given a complex type it will return an integer representing that type.
 * If this type has not yet been seen the returned integer is stored for future lookups.
 * @param _ct ComplexType to get ID for.
 */
function getResourceID(_hash : String) : Option<Int>
{
    return if (resources.exists(_hash))
    {
        Some(resources.get(_hash));
    }
    else
    {
        None;
    }
}

function registerResource(_hash : String)
{
    return if (!resources.exists(_hash))
    {
        final id = resourceIncrementer++;

        resources.set(_hash, id);

        id;
    }
    else
    {
        resources.get(_hash).unsafe();
    }
}