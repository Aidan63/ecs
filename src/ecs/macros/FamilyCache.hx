package ecs.macros;

import ecs.macros.ResourceCache;
import ecs.macros.ComponentsCache;
import ecs.macros.SystemMacros.FamilyDefinition;
import haxe.macro.Expr;
import haxe.macro.Context;

using haxe.macro.Tools;

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

/**
 * Given an array of family fields returns the associated integer ID.
 * @param _fields Array of types in the family.
 */
function getFamilyID(_family : FamilyDefinition)
{
    final buffer = new StringBuf();

    for (comp in _family.components)
    {
        buffer.add(comp.type.toString());
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

macro function createFamilyVector()
{
    return macro new haxe.ds.Vector($v{ familyIncrementer });
}

/**
 * Used by `ecs.core.FamiliesManager`, returns a code block which populates the `faimilies` vectors.
 * Adds an `ecs.Family` instance for each family, generating a bit mask for the components and resources requested by it.
 */
macro function setupFamilies()
{
    final creation = [];

    for (idx => family in familyFields)
    {
        // Create a bit flag set for all components in this family.
        creation.push(macro final cmpBits = new bits.Bits($v{ getComponentCount() }));

        for (field in family.components)
        {
            creation.push(macro cmpBits.set($v{ field.uID }));
        }

        // Create a bit flag set for all resources in this family.
        creation.push(macro final resBits = new bits.Bits($v{ getResourceCount() }));

        for (field in family.resources)
        {
            creation.push(macro resBits.set($v{ getResourceID(field.ct) }));
        }
        
        creation.push(macro families.set($v{ idx }, new ecs.Family($v{ idx }, cmpBits, resBits)));
    }

    return macro $b{ creation }
}