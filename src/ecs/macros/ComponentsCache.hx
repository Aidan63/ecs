package ecs.macros;

import haxe.macro.Expr;
import haxe.macro.Context;

using Safety;
using haxe.macro.Tools;

private final components = new Map<String, Int>();

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
function getComponentID(_ct : ComplexType) {
    final name = _ct.toString();

    return if (components.exists(name)) {
        components.get(name);
    } else {
        final id = componentIncrementer++;

        components.set(name, id);

        id;
    }
}

/**
 * Returns an expression creating a `haxe.ds.Vector` with capacity to store all the seen components.
 */
macro function createComponentVector() {
    return macro {
        final tmp = new haxe.ds.Vector($v{ componentIncrementer });

        for (i in 0...tmp.length)
        {
            tmp[i] = new ecs.Components<Any>();
        }

        tmp;
    }
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
                            final name = found.type.toString();
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
                            final name = found.t.toString();
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
                        switch Context.getType(s) {
                            case TInst(ref, _):
                                final type = ref.get();
                                final cidx = components.get(type.name);
                                final path = if (type.module != '') {
                                    name : type.module,
                                    pack : type.pack,
                                    sub  : type.name
                                } else {
                                    name : type.name,
                                    pack : type.pack,
                                    sub  : ''
                                }

                                exprs.push(macro $e{ _manager }.set($e{ _entity }, $v{ cidx }, new $path()));
                            case other:
                        }
                    case basic:
                        final name = switch basic {
                            case CInt(_)       : (macro : Int).toString();
                            case CFloat(_)     : (macro : Float).toString();
                            case CString(_, _) : (macro : String).toString();
                            case other: throw 'Unsupported CIdent $other';
                        }
                        final cidx = components.get(name);

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