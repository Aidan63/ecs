package ecs.macros;

import haxe.macro.Expr;
import haxe.macro.Context;
import ecs.macros.ResourceCache;

using Safety;
using haxe.macro.Tools;

macro function setResources(_manager : ExprOf<ecs.core.ResourceManager>, _resources : Array<Expr>)
{
    final exprs = [];

    for (resource in _resources)
    {
        switch resource.expr
        {
            case EConst(CIdent(s)):
                final type = Context.getLocalType().getClass();
                final vars = Context.getLocalTVars();

                // Check if this identifier is a member field or static field.
                final found = type.findField(s).or(type.findField(s, true));

                if (found != null)
                {
                    final ct   = found.type.toComplexType();
                    final cidx = getResourceID(ct);

                    if (cidx != null)
                    {
                        exprs.push(macro $e{ _manager }.insert($v{ cidx }, $e{ resource }));

                        continue;
                    }
                    else
                    {
                        Context.error('Component ${ ct.toString() } is not used in any families', Context.currentPos());
                    }
                }

                // Check if this identifier is a local var.
                final found = vars.get(s);

                if (found != null)
                {
                    final ct   = found.t.toComplexType();
                    final cidx = getResourceID(ct);

                    if (cidx != null)
                    {
                        exprs.push(macro $e{ _manager }.insert($v{ cidx }, $e{ resource }));

                        continue;
                    }
                    else
                    {
                        Context.error('Component ${ ct.toString() } is not used in any families', Context.currentPos());
                    }
                }

                // If the above checks fail then treat the ident as a type
                final type = Context.getType(s).toComplexType();
                final cidx = getResourceID(type);

                switch type
                {
                    case TPath(tp): exprs.push(macro $e{ _manager }.insert($v{ cidx }, new $tp()));
                    case _:
                }
            case _:
        }
    }

    exprs.push(macro @:privateAccess $e{ _manager }.onResourcesAdded.onNext(rx.Unit.unit));

    return macro $b{ exprs };
}

macro function removeResources(_manager : ExprOf<ecs.core.ResourceManager>, _resources : Array<Expr>)
{
    final exprs = [];

    for (resource in _resources)
    {
        switch resource.expr
        {
            case EConst(CIdent(s)):
                final type = Context.getType(s).toComplexType();
                final ridx = getResourceID(type);

                exprs.push(macro $e{ _manager }.remove($v{ ridx }));
            case _:
        }
    }

    exprs.push(macro @:privateAccess $e{ _manager }.onResourcesRemoved.onNext(rx.Unit.unit));

    return macro $b{ exprs };
}

macro function getByType(_manager : ExprOf<ecs.core.ResourceManager>, _resource : Expr)
{
    switch _resource.expr
    {
        case EConst(CIdent(s)):
            final type = Context.getType(s).toComplexType();
            final cidx = getResourceID(type);

            return macro ($e{ _manager }.get($v{ cidx }) : $type);
        case _:
    }

    throw 'Expect an EConst(CIdent) expression';
}