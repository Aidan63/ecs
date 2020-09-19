package ecs.macros;

import haxe.macro.Expr;
import haxe.macro.Context;
import ecs.macros.ComponentCache;

using Safety;
using haxe.macro.Tools;

/**
 * Returns an expression creating a `haxe.ds.Vector` with capacity to store all the seen components.
 */
macro function createComponentVector()
{
    return macro new haxe.ds.Vector($v{ getComponentCount() });
}

/**
 * Called in the constructor of `ecs.core.ComponentManager` and instantiates a components table for every component used to the `components` vector.
 * @param _size Expression which contains the maximum number of entities.
 */
macro function setupComponents(_size : Expr)
{
    final creation = [];

    for (name => idx in getComponentMap())
    {
        final ct = Context.getType(name).toComplexType();

        creation.push(macro components.set($v{ idx }, new ecs.Components<$ct>($e{ _size })));
    }

    return macro $b{ creation };
}

/**
 * Adds the specified components to the provided entity through the component manager.
 * Many types of expressions are accepted, TODO : Document them.
 * @param _manager 
 * @param _entity 
 * @param _components 
 */
macro function setComponents(_manager : ExprOf<ecs.core.ComponentManager>, _entity : ExprOf<ecs.Entity>, _components : Array<Expr>)
{
    final exprs = [ macro final ecsEntityTemp = $e{ _entity } ];

    for (comp in _components)
    {
        switch comp.expr
        {
            // EConst(CIdent(_)) will either be a field or type name.
            // In the case of a field we get its type and pass on the expression.
            // If its a type we create a new instance of it using an empty constructor.
            case EConst(CIdent(s)):
                final type = Context.getLocalType().getClass();
                final vars = Context.getLocalTVars();

                // Check if this identifier is a field type.
                final found = type.findField(s).or(type.findField(s, true));

                if (found != null)
                {
                    final ct = found.type.toComplexType();

                    switch getComponentID(ct)
                    {
                        case Some(id):
                            exprs.push(macro $e{ _manager }.set(ecsEntityTemp, $v{ id }, $e{ comp }));
                        case None:
                            Context.warning('Component ${ ct.toString() } is not used in any families', comp.pos);
                    }

                    continue;
                }

                // Check if this identifier is a local var.
                final found = vars.get(s);

                if (found != null)
                {
                    final ct = found.t.toComplexType();

                    switch getComponentID(ct)
                    {
                        case Some(id):
                            exprs.push(macro $e{ _manager }.set(ecsEntityTemp, $v{ id }, $e{ comp }));
                        case None:
                            Context.warning('Component ${ ct.toString() } is not used in any families', comp.pos);
                    }

                    continue;
                }

                // If the above checks fail then treat the ident as a type

                final ct = Context.getType(s).toComplexType();

                switch ct
                {
                    case TPath(p):
                        switch getComponentID(ct)
                        {
                            case Some(id):
                                exprs.push(macro $e{ _manager }.set(ecsEntityTemp, $v{ id }, new $p()));
                            case None:
                                Context.warning('Component ${ ct.toString() } is not used in any families', comp.pos);
                        }
                    case other:
                }
            // For other constants just get its type and pass on the expression.
            case EConst(_):
                final ct = Context.typeof(comp).toComplexType();

                switch getComponentID(ct)
                {
                    case Some(id):
                        exprs.push(macro $e{ _manager }.set(ecsEntityTemp, $v{ id }, $e{ comp }));
                    case None:
                        Context.warning('Component ${ ct.toString() } is not used in any families', comp.pos);
                }
            // Pass construction calls through
            case ENew(t, _):
                final ct = Context.getType(t.name).toComplexType();

                switch getComponentID(ct)
                {
                    case Some(id):
                        exprs.push(macro $e{ _manager }.set(ecsEntityTemp, $v{ id }, $e{ comp }));
                    case None:
                        Context.warning('Component ${ ct.toString() } is not used in any families', comp.pos);
                }
            case other: Context.error('Unsupported expression ${ comp.toString() }', comp.pos);
        }
    }

    // After we've added all out components publish the entity ID through the components added subject.
    // TODO : somehow expose this without privateAccess?
    exprs.push(macro @:privateAccess $e{ _manager }.onComponentsAdded.onNext(ecsEntityTemp));

    return macro $b{ exprs };
}

macro function removeComponents(_manager : ExprOf<ecs.core.ComponentManager>, _entity : ExprOf<ecs.Entity>, _components : Array<Expr>)
{
    final exprs = [ macro final ecsEntityTemp = $e{ _entity } ];

    for (comp in _components)
    {
        switch comp.expr
        {
            case EConst(CIdent(s)):
                // If the above checks fail then treat the ident as a type
                final type = Context.getType(s).toComplexType();

                switch getComponentID(type)
                {
                    case Some(id):
                        exprs.push(macro $e{ _manager }.remove(ecsEntityTemp, $v{ id }));
                    case None:
                        Context.warning('Component ${ type.toString() } is not used in any families', comp.pos);
                }
                
            case other:
                Context.error('Unsupported expression ${ comp.toString() }', comp.pos);
        }
    }

    exprs.push(macro @:privateAccess $e{ _manager }.onComponentsRemoved.onNext(ecsEntityTemp));

    return macro $b{ exprs };
}