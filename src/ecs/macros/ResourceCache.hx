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
function getResourceID(_ct : ComplexType)
{
    final name = _ct.toString();

    if (resources.exists(name))
    {
        return resources.get(name);
    }

    throw '$name has not been registered as a resource';
}

function registerResource(_ct : ComplexType)
{
    final name = _ct.toString();

    if (!resources.exists(name))
    {
        resources.set(name, resourceIncrementer++);
    }
}

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