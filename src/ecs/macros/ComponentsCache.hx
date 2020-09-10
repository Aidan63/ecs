package ecs.macros;

import haxe.ds.Option;
import haxe.macro.Expr;
import haxe.macro.Context;

using Safety;
using haxe.macro.Tools;

private final components = new Map<String, Int>();

private var componentIncrementer = 0;

/**
 * Returns the total number of unique components.
 */
function getComponentCount()
{
    return componentIncrementer;
}

/**
 * Given a complex type it will return an integer representing that type.
 * If this type has not yet been seen the returned integer is stored for future lookups.
 * @param _ct ComplexType to get ID for.
 */
function registerComponent(_type : ComplexType)
{
    final name = _type.toString();

    return if (components.exists(name))
    {
        components.get(name);
    }
    else
    {
        final id = componentIncrementer++;

        components.set(name, id);

        id;
    }
}

/**
 * Returns the component ID of a complex type.
 * If the complex type has not been registered as a component `None` is returned.
 * @param _type Complex type of the component.
 * @return Option<Int>
 */
function getComponentID(_type : ComplexType) : Option<Int>
{
    final name = _type.toString();

    return if (components.exists(name))
    {
        Some(components.get(name));
    }
    else
    {
        None;
    }
}

/**
 * Returns an expression creating a `haxe.ds.Vector` with capacity to store all the seen components.
 */
macro function createComponentVector()
{
    return macro new haxe.ds.Vector($v{ componentIncrementer });
}

/**
 * Called in the constructor of `ecs.core.ComponentManager` and instantiates a components table for every component used to the `components` vector.
 */
macro function setupComponents()
{
    final creation = [];

    for (name => idx in components)
    {
        final ct = Context.getType(name).toComplexType();

        creation.push(macro components.set($v{ idx }, new ecs.Components<$ct>()));
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
            // Will create a new instance of the constant type
            case EConst(c):
                switch c
                {
                    case CIdent(s):
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

                                    continue;
                                case None:
                                    Context.warning('Component ${ ct.toString() } is not used in any families', comp.pos);
                            }
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
    
                                    continue;
                                case None:
                                    Context.warning('Component ${ ct.toString() } is not used in any families', comp.pos);
                            }
                        }

                        // If the above checks fail then treat the ident as a type
                        final type = Context.getType(s).toComplexType();

                        switch type
                        {
                            case TPath(p):
                                switch getComponentID(type)
                                {
                                    case Some(id):
                                        exprs.push(macro $e{ _manager }.set(ecsEntityTemp, $v{ id }, new $p()));
                                    case None:
                                        Context.warning('Component ${ type.toString() } is not used in any families', comp.pos);
                                }
                            case other:
                        }
                        
                    case basic:
                        final type = switch basic
                        {
                            case CInt(_)       : Context.getType('Int');
                            case CFloat(_)     : Context.getType('Float');
                            case CString(_, _) : Context.getType('String');
                            case CRegexp(_, _) : Context.getType('EReg');
                            case other : throw 'Unsupported CIdent $other';
                        }

                        final ct = type.toComplexType();

                        switch getComponentID(ct)
                        {
                            case Some(id):
                                exprs.push(macro $e{ _manager }.set(ecsEntityTemp, $v{ id }, $e{ comp }));
                            case None:
                                Context.warning('Component ${ ct.toString() } is not used in any families', comp.pos);
                        }
                }
            // Pass field access through
            case EField(e, field):
                // trace('EField');
                // trace(e);
                // trace(field);
            // Pass function calls through
            case ECall(e, params):
                // trace('ECall');
                // trace(e);
            // Pass construction calls through
            case ENew(t, params):
                final type = Context.getType(t.name).toComplexType();

                switch getComponentID(type)
                {
                    case Some(id):
                        exprs.push(macro $e{ _manager }.set(ecsEntityTemp, $v{ id }, $e{ comp }));
                    case None:
                        Context.warning('Component ${ type.toString() } is not used in any families', comp.pos);
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