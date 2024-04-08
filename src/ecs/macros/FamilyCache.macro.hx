package ecs.macros;

import haxe.ds.Option;
import haxe.ds.ReadOnlyArray;
import ecs.macros.SystemMacros.FamilyDefinition;

using Lambda;
using haxe.macro.TypeTools;

/**
 * Map of family IDs keyed by concatenated component types which compose that family.
 */
@:persistent private final familyIDs = new Map<String, Int>();

/**
 * Array of all family definitions. Index of each family is its unique ID.
 */
@:persistent private final familyDefinitions = new Array<FamilyDefinition>();

/**
 * All family definitions keyed by the name of the system and its used typed variable name.
 * The definition objects are fetched from the `familyDefinition` array.
 */
@:persistent private final keyedFamilies = new Map<String, FamilyDefinition>();

/**
 * Current family counter. Incremented each time a new family is encountered.
 */
@:persistent private var familyIncrementer = 0;

/**
 * Returns the number of families registered.
 * Only safe to use in expression macros.
 */
function getFamilyCount()
{
    return familyIncrementer;
}

/**
 * Returns all registered family definitions. Index of each family in the array is its unique ID.
 * Only safe to use in expression macros.
 * @return ReadOnlyArray<FamilyDefinition>
 */
function getFamilies() : ReadOnlyArray<FamilyDefinition>
{
    return familyDefinitions;
}

/**
 * Returns an array of family IDs which request the resource with the provided ID.
 * @param _id Resource ID to search for in families.
 * @return ReadOnlyArray<Int>
 */
function getFamilyIDsWithResource(_id : Int) : ReadOnlyArray<Int>
{
    final filtered = [];

    for (idx => family in familyDefinitions)
    {
        if (family.resources.exists(f -> f.uID == _id))
        {
            filtered.push(idx);
        }
    }

    return filtered;
}

function getFamilyIDsWithComponent(_id : Int) : ReadOnlyArray<Int>
{
    final filtered = [];

    for (idx => family in familyDefinitions)
    {
        if (family.components.exists(f -> f.uID == _id))
        {
            filtered.push(idx);
        }
    }

    return filtered;
}

/**
 * Find a family by its `class-variable` unique key.
 * Only safe to use in expression macros.
 * @param _key Unique key.
 * @return Option<FamilyDefinition>
 */
function getFamilyByKey(_key : String) : Option<FamilyDefinition>
{
    return if (keyedFamilies.exists(_key))
    {
        Some(keyedFamilies.get(_key));
    }
    else
    {
        None;
    }
}

/**
 * Stores the provided family if one with the same hash does not exist.
 * @param _key Unique `class-var` string key.
 * @param _family Family definition object.
 */
function registerFamily(_key : String, _family : FamilyDefinition)
{
    final familyHash = hash(_family);

    // Always store our new family regardless of if a matching family hash is found.
    // This is because if we search by family key we care about the component variables names, not just their types.
    keyedFamilies.set(_key, _family);

    return if (familyIDs.exists(familyHash))
    {
        familyIDs.get(familyHash);
    }
    else
    {
        final id = familyIncrementer++;

        familyIDs.set(familyHash, id);
        familyDefinitions.push(_family);

        id;
    }
}

private function hash(_family : FamilyDefinition) : String
{
    final buffer = new StringBuf();

    buffer.add('c:');
    for (comp in _family.components)
    {
        buffer.add(comp.type.toString());
    }

    buffer.add('r:');
    for (res in _family.resources)
    {
        buffer.add(res.type.toString());
    }

    return buffer.toString();
}