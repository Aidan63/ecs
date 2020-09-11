package ecs.macros;

import haxe.ds.ReadOnlyArray;
import ecs.macros.SystemMacros.FamilyDefinition;

/**
 * Map of family IDs keyed by concatenated component types which compose that family.
 */
private final familyIDs = new Map<String, Int>();

/**
 * Array of all fields in a family. Index by the family ID.
 */
private final familyFields = new Array<FamilyDefinition>();

/**
 * Current family counter. Incremented each time a new family is encountered.
 */
private var familyIncrementer = 0;

function getFamilyCount()
{
    return familyIncrementer;
}

function getFamilies() : ReadOnlyArray<FamilyDefinition>
{
    return familyFields;
}

/**
 * Given an array of family fields returns the associated integer ID.
 * @param _fields Array of types in the family.
 */
function registerFamily(_family : FamilyDefinition)
{
    final buffer = new StringBuf();

    for (comp in _family.components)
    {
        buffer.add(comp.type);
    }

    final concat = buffer.toString();

    return if (familyIDs.exists(concat))
    {
        familyIDs.get(concat);
    }
    else
    {
        final id = familyIncrementer++;

        familyIDs.set(concat, id);
        familyFields.push(_family);

        id;
    }
}