package ecs.macros;

import haxe.Exception;
import haxe.macro.Type;
import haxe.macro.Printer;
import haxe.crypto.Md5;

using haxe.macro.TypeTools;

var invalidationFile : String;

private var printer = new Printer();

/**
 * Calculates a string hash of the given type.
 * @param _type Type to hash.
 */
function signature(_type : Type)
{
    return Md5.encode(switch _type
    {
        case TMono(_):
            throw new Exception('Cannot create signature of TMono');
        case TFun(_, _):
            throw new Exception('Cannot create signature of TFun');
        case TLazy(_):
            throw new Exception('Cannot create signature of TLazy');
        case TAnonymous(_):
            throw new Exception('Cannot create signature of TAnonymous');
        case TEnum(_.get() => eType, params):
            printTypePath(eType, params);
        case TInst(_.get() => cType, params):
            printTypePath(cType, params);
        case TType(_.get() => tType, params):
            printTypePath(tType, params);
        case TAbstract(_.get() => aType, params):
            printTypePath(aType, params);
        case TDynamic(t):
            'Dynamic<${ signature(t) }>';
    });
}

private function printTypePath(t, params)
{
    return printer.printTypePath(@:privateAccess TypeTools.toTypePath(t, params));
}