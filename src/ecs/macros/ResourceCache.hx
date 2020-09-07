package ecs.macros;

import haxe.macro.Type;
import haxe.macro.Expr;
import haxe.macro.Context;
import ecs.macros.Helpers;

using Safety;
using haxe.macro.Tools;

private final resources = new Map<String, Int>();

private final complexTypes = new Array<Type>();

private var resourceIncrementer = 0;

/**
 * Returns the total number of unique components.
 */
function getResourceCount()
{
    return resourceIncrementer;
}

/**
 * Given a complex type it will return an integer representing that type.
 * If this type has not yet been seen the returned integer is stored for future lookups.
 * @param _ct ComplexType to get ID for.
 */
function getResourceID(_type : Type)
{
    final name = getTypeName(_type);

    return if (resources.exists(name))
    {
        resources.get(name);
    }
    else
    {
        final id = resourceIncrementer++;

        resources.set(name, id);
        complexTypes.push(_type);

        id;
    }
}

macro function setResources(_manager : ExprOf<ecs.core.ResourceManager>, _resources : Array<Expr>)
{
    final exprs = [];

    for (resource in _resources)
    {
        switch resource.expr
        {
            case EConst(c):
                switch c
                {
                    case CIdent(s):
                        final type = Context.getLocalType().getClass();
                        final vars = Context.getLocalTVars();

                        // Check if this identifier is a member or static field type.
                        final found = type.findField(s).or(type.findField(s, true));

                        if (found != null)
                        {
                            final name = getTypeName(found.type);
                            final cidx = resources.get(name);

                            if (cidx != null)
                            {
                                exprs.push(macro $e{ _manager }.insert($v{ cidx }, $e{ resource }));

                                continue;
                            }
                            else
                            {
                                Context.error('Component $name is not used in any families', Context.currentPos());
                            }
                        }

                        // Check if this identifier is a local var.
                        final found = vars.get(s);

                        if (found != null)
                        {
                            final name = getTypeName(found.t);
                            final cidx = resources.get(name);

                            if (cidx != null)
                            {
                                exprs.push(macro $e{ _manager }.insert($v{ cidx }, $e{ resource }));
    
                                continue;
                            }
                            else
                            {
                                Context.error('Component $name is not used in any families', Context.currentPos());
                            }
                        }

                        // If the above checks fail then treat the ident as a type
                        final type = Context.getType(s);
                        final cidx = getResourceID(type);

                        switch type
                        {
                            case TInst(_.get() => t, _):
                                // Not sure if this is right, but seems to work...
                                final path = {
                                    name : t.module.split('.').pop().or(t.name),
                                    pack : t.pack,
                                    sub  : t.name
                                }

                                exprs.push(macro $e{ _manager }.insert($v{ cidx }, new $path()));
                            case _:
                        }
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
            case EConst(c):
                switch c
                {
                    case CIdent(s):
                        final type = Context.getType(s);
                        final ridx = getResourceID(type);

                        switch type
                        {
                            case TInst(_.get() => t, _):
                                // Not sure if this is right, but seems to work...
                                final path = {
                                    name : t.module.split('.').pop().or(t.name),
                                    pack : t.pack,
                                    sub  : t.name
                                }

                                exprs.push(macro $e{ _manager }.remove($v{ ridx }));
                            case other:
                        }
                    case _:
                }
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
        case EConst(c):
            switch c
            {
                case CIdent(s):
                    final type = Context.getType(s);
                    final cidx = getResourceID(type);
                    final ct   = type.toComplexType();

                    return macro ($e{ _manager }.get($v{ cidx }) : $ct);
                case _:
            }
        case _:
    }

    throw 'Expect an EConst(CIdent) expression';
}