package ecs.macros;

import ecs.macros.ComponentsCache;
import ecs.macros.SystemMacros.FamilyField;
import haxe.ds.ReadOnlyArray;
import haxe.macro.Context;
import haxe.macro.Expr;

using haxe.macro.ComplexTypeTools;

/**
 * Map of family IDs keyed by concatenated type names which compose that family.
 */
private final familyIDs = new Map<String, Int>();

/**
 * Array of all fields in a family. Index by the family ID.
 */
private final familyFields = new Array<ReadOnlyArray<FamilyField>>();

/**
 * Current family counter. Incremented each time a new family is encountered.
 */
private var familyIncrementer = 0;

/**
 * Given an array of family fields returns the associated integer ID.
 * @param _fields Array of types in the family.
 */
function getFamilyID(_fields : ReadOnlyArray<FamilyField>)
{
    final buffer = new StringBuf();

    for (field in _fields)
    {
        buffer.add(field.type.toString());
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
        familyFields.push(_fields);

        id;
    }
}

macro function createFamilyVector()
{
    return macro new haxe.ds.Vector($v{ familyIncrementer });
}

/**
 * Used by `ecs.core.FamiliesManager`.
 * Returns a code block which creates the `faimilies` vector,
 * adds `Family` instances for each family,
 * and generates the bit mask for the components used in it.
 */
macro function setupFamilies()
{
    final creation = [];

    for (idx => fields in familyFields)
    {
        creation.push(macro final tmpBits = new bits.Bits($v{ getComponentCount() }));

        for (field in fields)
        {
            creation.push(macro tmpBits.set($v{ getComponentID(field.aType) }));
        }
        
        creation.push(macro families.set($v{ idx }, new ecs.Family($v{ idx }, tmpBits)));
    }

    return macro $b{ creation }
}