package ecs.macros;

import haxe.macro.Type;
import haxe.crypto.Md5;

using haxe.macro.TypeTools;
using haxe.macro.ComplexTypeTools;

var invalidationFile : String;

/**
 * Calculates a string hash of the given type.
 * @param _type Type to hash.
 */
function signature(_type : Type)
{
    return Md5.encode(_type.toString());
}
