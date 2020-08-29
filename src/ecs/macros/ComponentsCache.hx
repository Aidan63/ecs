package ecs.macros;

import haxe.macro.TypeTools;
import haxe.macro.Context;
import haxe.macro.Expr;

using Safety;
using haxe.macro.Tools;

private final components = new Map<String, Int>();

private var componentIncrementer = 0;

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
    return macro new haxe.ds.Vector($v{ componentIncrementer });
}

macro function setComponents(_manager : ExprOf<ecs.core.ComponentManager>, _entity : ExprOf<ecs.Entity>, _components : Array<Expr>) {
    trace(_manager);
    trace(_entity.expr);

    final exprs = new Array<Expr>();

    for (comp in _components) {
        // trace(comp);
        
        switch comp.expr {
            // Will create a new instance of the constant type
            case EConst(c):
                switch c {
                    case CInt(_):
                        final reif = macro : Int;

                        // trace(reif.toString());
                    case CFloat(_):
                        final reif = macro : Float;

                        // trace(reif.toString());
                    case CString(s, _):
                        final reif = macro : String;

                        // trace(reif.toString());
                    case CIdent(s):
                        trace(s);

                        final type  = Context.getLocalType().getClass();
                        final vars  = Context.getLocalTVars();

                        // Check if this identifier is a field type.
                        final found = type.findField(s, true);
                        if (found != null) {
                            trace('found class field');
                            trace(found.type.toString());
                            trace(found.type.toComplexType());

                            continue;
                        }

                        // Check if this identifier is a local var.
                        final found = vars.get(s);
                        if (found != null) {
                            trace('found local var');
                            trace(found.t.toString());
                            trace(found.t.toComplexType());

                            continue;
                        }

                        // If the above checks fail then treat the ident as a type
                        switch Context.getType(s) {
                            case TInst(ref, _):
                                final t    = ref.get();
                                final id   = components.get(t.name);
                                final path = if (t.module != '') {
                                    name : t.module,
                                    pack : t.pack,
                                    sub  : t.name
                                } else {
                                    name : t.name,
                                    pack : t.pack,
                                    sub  : ''
                                }

                                exprs.push({
                                    pos  : Context.currentPos(),
                                    expr : ECall(
                                        { expr : EField(_manager, 'set'), pos : Context.currentPos() },
                                        [
                                            _entity,
                                            { pos : Context.currentPos(), expr : EConst(CInt('$id')) },
                                            { pos : Context.currentPos(), expr : ENew(path, []) }
                                        ])
                                });
                            case other:
                        }

                    case other: Context.error('Unsupported constant expression $other', Context.currentPos());
                }
            // Pass field access through
            case EField(e, field):
                // trace(e);
                // trace(field);
            // Pass function calls through
            case ECall(e, params):
                // trace(e);
            // Pass construction calls through
            case ENew(t, params):
                // trace(t);
            case other: Context.error('Unsupported expression $other', Context.currentPos());
        }
    }

    return {
        pos  : Context.currentPos(),
        expr : EBlock(exprs)
    }
}