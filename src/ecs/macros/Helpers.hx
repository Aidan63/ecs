package ecs.macros;

import haxe.macro.Type;

using haxe.macro.TypeTools;

/**
 * Given a specific Type it will create a string form of it.
 * This will only work with TInst.
 * @param _type Type to return the string of.
 */
function getTypeName(_type : Type)
{
    return switch _type
    {
        case TInst(_.get() => t, _): t.module + '.' + t.name;
        case other: throw 'Expected TInst but instead found $other';
    }
}