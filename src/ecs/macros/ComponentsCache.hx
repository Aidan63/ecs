package ecs.macros;

import haxe.macro.ComplexTypeTools;
import haxe.macro.Type;
import haxe.macro.Expr;
import haxe.macro.Context;
import ecs.macros.Helpers;

using Safety;
using haxe.macro.Tools;

private final components = new Map<String, Int>();

private final complexTypes = new Array<Type>();

private var componentIncrementer = 0;

/**
 * Returns the total number of unique components.
 */
function getComponentCount() {
    return componentIncrementer;
}

/**
 * Given a complex type it will return an integer representing that type.
 * If this type has not yet been seen the returned integer is stored for future lookups.
 * @param _ct ComplexType to get ID for.
 */
function getComponentID(_type : Type) {
    final name = getTypeName(_type);

    return if (components.exists(name))
    {
        components.get(name);
    }
    else
    {
        final id = componentIncrementer++;

        components.set(name, id);
        complexTypes.push(_type);

        id;
    }
}

/**
 * Returns an expression creating a `haxe.ds.Vector` with capacity to store all the seen components.
 */
macro function createComponentVector()
{
    return macro new haxe.ds.Vector($v{ componentIncrementer });
}

macro function setupComponents()
{
    final creation = [];

    for (idx => type in complexTypes)
    {
        final ct   = type.toComplexType();
        final expr = macro components.set($v{ idx }, new ecs.Components<$ct>());

        creation.push(expr);
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
macro function setComponents(_manager : ExprOf<ecs.core.ComponentManager>, _entity : ExprOf<ecs.Entity>, _components : Array<Expr>) {
    final exprs = [];

    for (comp in _components) {
        switch comp.expr {
            // Will create a new instance of the constant type
            case EConst(c):
                switch c {
                    case CIdent(s):
                        final type = Context.getLocalType().getClass();
                        final vars = Context.getLocalTVars();

                        // Check if this identifier is a field type.
                        final found = type.findField(s, true);

                        if (found != null)
                        {
                            final name = getTypeName(found.type);
                            final cidx = components.get(name);

                            if (cidx != null)
                            {
                                exprs.push(macro $e{ _manager }.set($e{ _entity }, $v{ cidx }, $e{ comp }));

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
                            final cidx = components.get(name);

                            if (cidx != null)
                            {
                                exprs.push(macro $e{ _manager }.set($e{ _entity }, $v{ cidx }, $e{ comp }));
    
                                continue;
                            }
                            else
                            {
                                Context.error('Component $name is not used in any families', Context.currentPos());
                            }
                        }

                        // If the above checks fail then treat the ident as a type
                        final type = Context.getType(s);
                        final cidx = getComponentID(type);

                        switch type
                        {
                            case TInst(_.get() => t, _):
                                // Not sure if this is right, but seems to work...
                                final path = {
                                    name : t.module.split('.').pop().or(t.name),
                                    pack : t.pack,
                                    sub  : t.name
                                }

                                exprs.push(macro $e{ _manager }.set($e{ _entity }, $v{ cidx }, new $path()));
                            case other:
                        }
                    case basic:
                        final type = switch basic {
                            case CInt(_)       : Context.getType('Int');
                            case CFloat(_)     : Context.getType('Float');
                            case CString(_, _) : Context.getType('String');
                            case other: throw 'Unsupported CIdent $other';
                        }
                        final name = getTypeName(type);
                        final cidx = getComponentID(type);

                        if (cidx != null)
                        {
                            exprs.push(macro $e{ _manager }.set($e{ _entity }, $v{ cidx }, $e{ comp }));
                        }
                        else
                        {
                            Context.error('Component $name is not used in any families', Context.currentPos());
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
                if (components.exists(t.name))
                {
                    exprs.push(macro $e{ _manager }.set($e{ _entity }, $v{ components.get(t.name) }, $e{ comp }));
                }
                else
                {
                    Context.error('Component ${ t.name } is not used in any families', Context.currentPos());
                }
            case other: Context.error('Unsupported expression $other', Context.currentPos());
        }
    }

    // After we've added all out components publish the entity ID through the components added subject.
    // TODO : somehow expose this without privateAccess?
    exprs.push(macro @:privateAccess $e{ _manager }.onComponentsAdded.onNext($e{ _entity }));

    return macro $b{ exprs };
}