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
                    final ct = found.type.toComplexType();

                    switch getResourceID(ct)
                    {
                        case Some(id):
                            exprs.push(macro $e{ _manager }.insert($v{ id }, $e{ resource }));
                        case None:
                            Context.warning('Resource ${ ct.toString() } is not used in any families', resource.pos);
                    }

                    continue;
                }

                // Check if this identifier is a local var.
                final found = vars.get(s);

                if (found != null)
                {
                    final ct = found.t.toComplexType();

                    switch getResourceID(ct)
                    {
                        case Some(id):
                            exprs.push(macro $e{ _manager }.insert($v{ id }, $e{ resource }));
                        case None:
                            Context.warning('Resource ${ ct.toString() } is not used in any families', resource.pos);
                    }

                    continue;
                }

                // If the above checks fail then treat the ident as a type
                final ct = Context.getType(s).toComplexType();

                switch ct
                {
                    case TPath(tp):
                        switch getResourceID(ct)
                        {
                            case Some(id):
                                exprs.push(macro $e{ _manager }.insert($v{ id }, new $tp()));
                            case None:
                                Context.warning('Resource ${ ct.toString() } is not used in any families', resource.pos);
                        }
                    case other:
                        Context.warning('Unsupported resource complex type $other', resource.pos);
                }
            case _:
                Context.error('Unsupported expression ${ resource.toString() }', resource.pos);
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
                final ct = Context.getType(s).toComplexType();

                switch getResourceID(ct)
                {
                    case Some(id):
                        exprs.push(macro $e{ _manager }.remove($v{ id }));
                    case None:
                        Context.warning('Resource ${ ct.toString() } is not used in any families', resource.pos);
                }
            case _:
                Context.error('Unsupported expression ${ resource.toString() }', resource.pos);
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