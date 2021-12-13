package ecs.macros;

import haxe.ds.Option;
import haxe.macro.Type.ClassType;
import haxe.macro.Type.TVar;
import haxe.macro.Expr;

using Safety;
using haxe.macro.Tools;

/**
 * Given an expression it will try and extract the EBlock expressions acting as if it is a function expression.
 * It expects an `EMeta(EReturn(EBlock))` expression three.
 * @param _expr Expression to operate on.
 * @return Option<Array<Expr>>
 */
function extractFunctionBlock(_expr : Expr) : Option<Array<Expr>>
{
    return switch _expr.expr
    {
        case EMeta(_, { expr : EReturn({ expr : EBlock(exprs) }) }):
            Some(exprs);
        case _:
            None;
    }
}

/**
 * Given an identified string, class type, and local variables it will return the type of the identified if it exists in the class or local variables.
 * @param _target Identifier string.
 * @param _classType Class type to check local and static variables.
 * @param _vars Map of local variables to check.
 * @return Option<haxe.macro.Type>
 */
function isLocalIdent(_target : String, _classType : ClassType, _vars : Map<String, TVar>) : Option<haxe.macro.Type>
{
    return switch _classType.findField(_target).or(_classType.findField(_target, true))
    {
        case null:
            if (_vars.exists(_target))
            {
                Some(_vars.get(_target).unsafe().t);
            }
            else
            {
                None;
            }
        case found:
            Some(found.type);
    }
}

abstract TableType(String) from String to String
{
	function new(value)
    {
        this = value;
	}
	
	@:from static function fromClass(input:Class<Dynamic>)
    {
        return new TableType(Type.getClassName(input));
	}
}