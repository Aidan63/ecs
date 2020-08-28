import Main.IComponent;
import haxe.macro.Expr.ExprOf;
import haxe.macro.Context;

private var componentsID  = 0;
private var componentsIDs = new Map<String, Int>();

macro function hashTypes(_types : Array<ExprOf<IComponent>>) {
    final builder = new StringBuf();

    for (cType in _types) {
        switch Context.typeof(cType) {
            case TType(_.get() => t, _):
                if (doesImplementIComponent(t.type)) {
                    builder.add(t.pack);
                    builder.add(t.name);
                } else {
                    Context.error('${ t.name } does not implement IComponent', Context.currentPos());
                }
            case other: Context.error('Expected TType but got $other', Context.currentPos());
        }
    }

    final str  = builder.toString();
    final hash = if (componentsIDs.exists(str)) {
        componentsIDs.get(str);
    } else {
        final val = componentsID++;
        componentsIDs.set(str, val);

        val;
    }

    return macro $v{ hash };
}

private function doesImplementIComponent(_type : haxe.macro.Type) {
    switch _type {
        case TAnonymous(_.get() => a):
            switch a.status {
                case AClassStatics(_.get() => t):
                    for (iface in t.interfaces) {
                        if (iface.t.get().name == Type.getClassName(IComponent)) {
                            return true;
                        }
                    }
                case _:
            }
        case _:
    }

    return false;
}