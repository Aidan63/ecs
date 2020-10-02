package ecs.macros;

import haxe.macro.Expr;
import haxe.macro.Context;
import ecs.macros.ResourceCache;

using Safety;
using haxe.macro.Tools;

macro function createResourceVector()
{
    return macro new haxe.ds.Vector($v{ getResourceCount() });
}

macro function createResourceBits()
{
    return macro new bits.Bits($v{ getResourceCount() });
}

macro function getByType(_manager : ExprOf<ecs.core.ResourceManager>, _resource : Expr)
{
    switch _resource.expr
    {
        case EConst(CIdent(s)):
            final ct = Context.getType(s).toComplexType();

            switch getResourceID(ct)
            {
                case Some(id):
                    return macro ($e{ _manager }.get($v{ id }) : $ct);
                case None:
                    Context.error('Resource ${ ct.toString() } is not used in any families', _resource.pos);
            }
        case _:
            Context.error('Unsupported expression ${ _resource.pos }', _resource.pos);
    }

    return macro null;
}