package ecs.macros;

import haxe.macro.Expr;
import ecs.macros.FamilyCache;
import ecs.macros.ResourceCache;
import ecs.macros.ComponentCache;

using haxe.macro.Tools;

/**
 * Creates a vector large enough to store all unique families.
 */
macro function createFamilyVector()
{
    return macro new haxe.ds.Vector($v{ getFamilyCount() });
}

/**
 * Used by `ecs.core.FamiliesManager`, returns a code block which populates the `faimilies` vectors.
 * Adds an `ecs.Family` instance for each family, generating a bit mask for the components and resources requested by it.
 * @param _size Expression which contains the maximum number of entities.
 */
macro function setupFamilies(_size : Expr)
{
    final creation = [];

    for (idx => family in getFamilies())
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
            creation.push(macro resBits.set($v{ field.uID }));
        }
        
        creation.push(macro families.set($v{ idx }, new ecs.Family($v{ idx }, cmpBits, resBits, $e{ _size })));
    }

    return macro $b{ creation }
}