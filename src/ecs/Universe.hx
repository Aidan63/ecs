package ecs;

import haxe.Exception;
import haxe.ds.Vector;
import ecs.core.EntityManager;
import ecs.core.FamilyManager;
import ecs.core.ResourceManager;
import ecs.core.ComponentManager;

#if macro
import ecs.ds.Set;
import ecs.ds.Result;
import ecs.macros.Utils;
import ecs.macros.UniverseMacros;
import ecs.macros.ComponentCache;
import ecs.macros.ResourceCache;
import ecs.macros.FamilyCache;
import haxe.macro.Type;
import haxe.macro.Expr;
import haxe.macro.Context;

using Safety;
using Lambda;
using EnumValue;
using haxe.macro.Tools;

private class SystemSpec
{
    public final type : Type;

    public final pos : Position;

    public final enabled : Bool;

    public function new(_type, _pos, _enabled)
    {
        type    = _type;
        pos     = _pos;
        enabled = _enabled;
    }
}

private class PhaseSpec
{
    public final name : String;

    public final enabled : Bool;

    public final systems : Array<SystemSpec>;

    public function new(_name, _enabled, _systems)
    {
        name    = _name;
        enabled = _enabled;
        systems = _systems;
    }
}

private class UniverseSpec
{
    public final name : String;

    public final entities : Int;

    public final phases : Array<PhaseSpec>;

    public function new(_name, _entities, _phases)
    {
        name     = _name;
        entities = _entities;
        phases   = _phases;
    }
}

private function buildTypePath(_existing : String, _expr : Expr) : Result<String, String>
{
    return switch _expr.expr
    {
        case EConst(CIdent(s)):
            Ok('$s.$_existing');
        case EField(e, field):
            buildTypePath('$field.$_existing', e);
        case other:
            Error('unsupported expression in type path : $other');
    }
}

#end

class Universe
{
    @:ignoreInstrument public static macro function create(_spec : Expr)
    {
        final registerSystem = (e : Expr) -> {
            return switch e.expr
            {
                case EConst(CIdent(i)):
                    final t = try Context.getType(i) catch (exn) Context.error('Failed to get the type of "$i" : $exn', e.pos);

                    return new SystemSpec(t, e.pos, true);
                case EField(inner, field):
                    switch buildTypePath(field, inner)
                    {
                        case Ok(path):
                            final t = try Context.getType(path) catch (exn) Context.error('Failed to get the type of "$path" : $exn', e.pos);

                            return new SystemSpec(t, e.pos, true);
                        case Error(error):
                            Context.error(error, e.pos);
                    }
                case other:
                    Context.error('Expression is not a valid type path : $other', e.pos);
            }
        }

        final extractPhase = (e : Expr) -> {
            return switch e.expr
            {
                case EObjectDecl(fields):
                    final name = switch fields.find(i -> i.field == 'name')
                    {
                        case null:
                            Context.error('Phase does not contain a field called "name"', e.pos);
                        case field:
                            switch field.expr.expr
                            {
                                case EConst(CString(v)): v;
                                case _: Context.error('field called "name" was not a string literal', field.expr.pos);
                            }
                    }
                    final enabled = switch fields.find(i -> i.field == 'enabled')
                    {
                        case null:
                            true;
                        case field:
                            switch field.expr.expr
                            {
                                case EConst(CIdent('true')): true;
                                case EConst(CIdent('false')): false;
                                case _: Context.error('field called "enabled" was not a boolean literal', field.expr.pos);
                            }
                    }
                    final systems = switch fields.find(i -> i.field == 'systems')
                    {
                        case null:
                            Context.error('Phase does not contain a field called "systems"', e.pos);
                        case field:
                            switch field.expr.expr
                            {
                                case EArrayDecl(values):
                                    values.map(registerSystem);
                                case _:
                                    Context.error('field called "systems" was not an array declaration', field.expr.pos);
                            }
                    }

                    new PhaseSpec(name, enabled, systems);
                case _:
                    Context.error('Phase definition must be an object declaration', e.pos);
            }
        }

        final spec = switch _spec.expr
        {
            case EObjectDecl(fields):
                final name = switch fields.find(i -> i.field == 'name')
                {
                    case null:
                        'universe';
                    case field:
                        switch field.expr.expr
                        {
                            case EConst(CString(v)): v;
                            case _: Context.error('field called "name" was not a string literal', field.expr.pos);
                        }
                }
                final capacity = switch fields.find(i -> i.field == 'entities')
                {
                    case null:
                        Context.error('Object has no field with the name "entities"', _spec.pos);
                    case field:
                        switch field.expr.expr
                        {
                            case EConst(CInt(v)): Std.parseInt(v);
                            case _: Context.error('field called "entities" was not an integer literal', field.expr.pos);
                        }
                }
                final phases = switch fields.find(i -> i.field == 'phases')
                {
                    case null:
                        Context.error('Object has no field with the name "phases"', _spec.pos);
                    case field:
                        switch field.expr.expr
                        {
                            case EArrayDecl(values):
                                values.map(extractPhase);
                            case _: Context.error('field called "phases" was not an array declaratioon', field.expr.pos);
                        }
                }

                new UniverseSpec(name, capacity, phases);
            case _:
                Context.error('Universe definition must be an object declaration', _spec.pos);
        }

#if display
        // Register a dependency to the calling module and the invalidation file
        // This means the compiler will invalidate the module whenever the file changes

        Context.registerModuleDependency(Context.getLocalModule(), invalidationFile);
#end

        return macro {
            // pre-allocate the phases and reserve a vector to contain all a phases systems.
            // Do not allocate the phases right now, they need a reference to the universe so we defer that til afterwards.
            final phases = {
                final vec = new haxe.ds.Vector($v{ spec.phases.length });

                $b{ [
                    for (idx => phase in spec.phases)
                    {
                        macro vec.set(
                            $v{ idx },
                            new ecs.Phase(
                                $v{ phase.enabled },
                                $v{ phase.name },
                                new haxe.ds.Vector($v{ phase.systems.length }),
                                new haxe.ds.Vector($v{ phase.systems.length }))
                        );
                    }
                ] }

                vec;
            }

            final entities = new ecs.core.EntityManager($v{ spec.entities });
            final components = {
                final vec = new haxe.ds.Vector<Any>($v{ getComponentCount() });
    
                $b{
                    [
                        for (_ => value in getComponentMap())
                        {
                            final ct = value.type.toComplexType();
            
                            macro vec.set($v{ value.id }, new ecs.Components<$ct>($v{ getComponentCount() }));
                        }
                    ]
                }

                new ecs.core.ComponentManager(entities, vec);
            }
            final resources = new ecs.core.ResourceManager(new bits.Bits($v{ getResourceCount() }), new haxe.ds.Vector($v{ getResourceCount() }));
            final families = {
                final vec = new haxe.ds.Vector($v{ getFamilyCount() });

                $b{ [
                    for (idx => family in getFamilies())
                    {
                        macro {
                            final cmpBits = new bits.Bits($v{ getComponentCount() });
    
                            $b{ [
                                for (field in family.components)
                                {
                                    macro cmpBits.set($v{ field.uID });
                                }
                            ] }
    
                            final resBits = new bits.Bits($v{ getResourceCount() });
    
                            $b{ [
                                for (field in family.resources)
                                {
                                    macro resBits.set($v{ field.uID });
                                }
                            ] }
    
                            vec.set($v{ idx }, new ecs.Family($v{ idx }, cmpBits, resBits, $v{ spec.entities }));
                        }
                    }
                ] }

                new ecs.core.FamilyManager(components, resources, vec);
            }

            final u = new ecs.Universe(entities, components, resources, families, phases);

            // Second iteration over phases, now we allocate all our systems.
            $b{ [
                for (i => phase in spec.phases)
                {
                    macro {
                        final phase = phases.get($v{ i });

                        $b{ [
                            for (j => system in phase.systems)
                            {
                                final tp = switch system.type
                                {
                                    case TInst(_.get() => cType, params):
                                        @:privateAccess haxe.macro.TypeTools.toTypePath(cType, params);
                                    case other:
                                        // TODO : Keep the pos of the type so we can report the error at the right location.
                                        Context.error('Expected system to be an instance : $other', system.pos);
                                }

                                macro {
                                    final s = new $tp(u);

                                    @:privateAccess phase.systems.set($v{ j }, s);
                                    @:privateAccess phase.enabledSystems.set($v{ j }, $v{ system.enabled });

                                    $e{ if (system.enabled) macro s.onEnabled(); else macro null }
                                };
                            }
                        ] }
                    }
                }
            ] }

            u;
        }
    }

    public final entities : EntityManager;
    public final components : ComponentManager;
    public final resources : ResourceManager;
    public final families : FamilyManager;
    public final phases : Vector<Phase>;

    public function new(_entities, _components, _resources, _families, _phases)
    {
        entities   = _entities;
        components = _components;
        resources  = _resources;
        families   = _families;
        phases     = _phases;
    }

    public function update(_dt : Float)
    {
        for (phase in phases)
        {
            phase.update(_dt);
        }
    }

    /**
     * Creates a new entity within this universe.
     * If the maximum number of entities has been reached an exception is thrown.
     */
    public function createEntity()
    {
        return entities.create();
    }

    /**
     * Destroy an entity and all its attached components from this universe.
     * If the universe does not contain the entity then no operation is performed.
     * @param _entity Entity to delete.
     */
    public function deleteEntity(_entity)
    {
        components.clear(_entity);
        families.whenEntityDestroyed(_entity);
        entities.destroy(_entity.id());
    }

    public function getPhase(_name)
    {
        for (phase in phases)
        {
            if (phase.name == _name)
            {
                return phase;
            }
        }

        throw new Exception('Unable to find a phase with the name $_name');
    }

    /**
     * Sets any number of components on an entity in a specific universe.
     * The final argument is a rest argument meaning it can take in any number of arguments.
     * 
     * Example usage for `using ecs.macros.UniverseMacros;`
     * 
     * ```
     * unverse.setComponents(myEntity,
     *     new Position(32, 32),
     *     new Velocity(),
     *     new Sprite('assets/player.png'));
     * ```
     * 
     * Along with the usual variable, function, and constructor expressions if the component has a constructor
     * with no arguments then simply passing in the type will construct a new component for it.
     * 
     * ```
     * universe.setComponents(myEntity,
     *     new Position(32, 32),
     *     Velocity,
     *     new Sprite('assets/player.png));
     * ```
     * 
     * It is also possible to use basic types for components.
     * 
     * ```
     * universe.setComponents(myEntity, 7, 4.2, true, 'hello world');
     * ```
     * 
     * Attempting to add a component which is not used in any families will result in a compiler warning and that
     * expression will not be typed (no functions or property getters would be called if used).
     * Setting a component onto an entity which already has a component of that type will replace it.
     * 
     * @param _entity Entity to add components to.
     * @param _components Components to add.
     */
    @:ignoreInstrument public macro function setComponents(self : Expr, _entity : Expr, _components : Array<Expr>)
    {
        final exprs  = [ macro final _ecsTmpEntity = $e{ _entity } ];
        final added  = new Set();
        final insert = (id, compExpr) -> {
            exprs.push(macro $e{ self }.components.set(_ecsTmpEntity, $v{ id }, $e{ compExpr }));
    
            for (familyID in ecs.macros.FamilyCache.getFamilyIDsWithComponent(id))
            {
                added.add(familyID);
            }
        }
    
        for (component in _components)
        {
            switch component.expr
            {
                case EConst(CIdent(s)):
                    switch isLocalIdent(s, Context.getLocalType().getClass(), Context.getLocalTVars())
                    {
                        case Some(type):
                            switch getComponentID(signature(type))
                            {
                                case Some(id): insert(id, component);
                                case None: Context.warning('Local ident $s : $type is not used in any families', component.pos);
                            }
                        case None:
                            final resolved  = try Context.getType(s) catch (_) Context.error('Unable to get type of component expression ${ component.toString() }', component.pos);
                            final signature = signature(resolved);
    
                            switch getComponentID(signature)
                            {
                                case Some(id):
                                    switch resolved.toComplexType()
                                    {
                                        case TPath(tp): insert(id, macro new $tp());
                                        case other: Context.error('Component ${ other.toString() } should be TPath', component.pos);
                                    }
                                case None: Context.warning('Component $resolved is not used in any families', component.pos);
                            }
                    }
                // We need to handle ENew separately as Context.typeof won't give typedef as a type.
                case ENew(tp, _):
                    final resolved = {
                        try
                        {
                            final t = Context.getType(printTypePath(tp));

                            switch t
                            {
                                case TType(_, _):
                                    t;
                                case _:
                                    throw new Exception('Not a typedef');
                            }
                        }
                        catch (exn)
                        {
                            try Context.typeof(component) catch (exn) Context.error('unable to get type ${ component.toString() } : $exn', component.pos);
                        }
                    }
                    final signature = signature(resolved);

                    switch getComponentID(signature)
                    {
                        case Some(id): insert(id, component);
                        case None: Context.warning('Component ${ resolved } is not used in any families', component.pos);
                    }
                case _:
                    final resolved  = try Context.typeof(component) catch (e) Context.error('Unable to get the type of ${ component.toString() } : $e', component.pos);
                    final signature = signature(resolved);

                    switch getComponentID(signature)
                    {
                        case Some(id): insert(id, component);
                        case None: Context.warning('Component ${ resolved } is not used in any families', component.pos);
                    }
            }
        }
    
        // After all `set` functions are called check each family which could have been modified by the components added.
        exprs.push(macro final ecsEntCompFlags = $e{ self }.components.flags[_ecsTmpEntity.id()]);

        // With static loaded the `added` set contains all families which could have been effected by the components added.
        // So we only need to check those ones.
        for (familyID in added)
        {
            exprs.push(macro final ecsTmpFamily = $e{ self }.families.get($v{ familyID }));
            exprs.push(macro if (ecsEntCompFlags.areSet(ecsTmpFamily.componentsMask)) {
                ecsTmpFamily.add(_ecsTmpEntity);
            });
        }
    
        return macro $b{ exprs };
    }

    /**
     * Removes any number of components from an entity in a given universe.
     * The final argument is a rest argument meaning it can take in any number of arguments.
     * 
     * Example usage for `using ecs.macros.UniverseMacros;`
     * 
     * ```
     * universe.removeComponents(myEntity, Position, Velocity, Sprite);
     * ```
     * 
     * Attempting to remove a component which is not used in any families will result in a compiler warning
     * and that expression will be skipped.
     * @param _universe Universe which contains the entity.
     * @param _entity Entity to remove components from.
     * @param _components Components to remove.
     */
    @:ignoreInstrument public macro function removeComponents(_universe : ExprOf<Universe>, _entity : Expr, _components : Array<Expr>)
    {
        final exprs  = [ macro final _ecsTmpEntity = $e{ _entity } ];
        final added  = new Set();
        final insert = id -> {
            exprs.push(macro $e{ _universe }.components.remove(_ecsTmpEntity, $v{ id }));

            for (familyID in getFamilyIDsWithComponent(id))
            {
                added.add(familyID);
            }
        };
    
        for (component in _components)
        {
            switch component.expr
            {
                case EConst(CIdent(s)):
                    switch isLocalIdent(s, Context.getLocalType().getClass(), Context.getLocalTVars())
                    {
                        case Some(type):
                            switch getComponentID(signature(type))
                            {
                                case Some(id): insert(id);
                                case None: Context.warning('Component ${ type } is not used in any families', component.pos);
                            }
                        case None:
                            final resolved  = try Context.getType(s) catch (_) Context.error('Unable to get type of component expression ${ component.toString() }', component.pos);
                            final signature = signature(resolved);
    
                            switch getComponentID(signature)
                            {
                                case Some(id): insert(id);
                                case None: Context.warning('Component ${ resolved } is not used in any families', component.pos);
                            }
                    }
                case _: Context.error('Unsupported component expression ${ component.toString() }', component.pos);
            }
        }
    
        // After all `remove` functions are called check each family which could have been modified by the components removed.
        exprs.push(macro final ecsEntCompFlags = $e{ _universe }.components.flags[_ecsTmpEntity.id()]);

        // With static loaded the `added` set contains all families which could have been effected by the components added.
        // So we only need to check those ones.
        for (familyID in added)
        {
            exprs.push(macro final ecsTmpFamily = $e{ _universe }.families.get($v{ familyID }));
            exprs.push(macro if (!ecsEntCompFlags.areSet(ecsTmpFamily.componentsMask)) {
                ecsTmpFamily.remove(_ecsTmpEntity);
            });
        }
    
        return macro $b{ exprs };
    }

    /**
     * Add any number of resources to a given universe.
     * The final argument is a rest argument meaning it can take in any number of arguments.
     * 
     * Example usage for `using ecs.macros.UniverseMacros;`
     * 
     * ```
     * unverse.setResource(
     *     new LevelData('assets/level1.json'),
     *     new SpriteBatcher());
     * ```
     * 
     * Along with the usual variable, function, and constructor expressions if the resource has a constructor
     * with no arguments then simply passing in the type will construct it.
     * 
     * ```
     * universe.setResources(
     *     new LevelData('assets/level1.json'),
     *     SpriteBatcher);
     * ```
     * 
     * It is also possible to use basic types for resources.
     * 
     * ```
     * universe.setResources(7, 4.2, true, 'hello world');
     * ```
     * 
     * Attempting to add a resource which is not used in any families will result in a compiler warning and that
     * expression will not be typed (no functions or property getters would be called if used).
     * Setting a resource which has already been set will replace.
     * @param _universe Universe to add resources to.
     * @param _resources Resources to add.
     */
    @:ignoreInstrument public macro function setResources(_universe : ExprOf<Universe>, _resources : Array<Expr>)
    {
        final exprs  = [];
        final added  = new Set();
        final insert = (id, resExpr) -> {
            exprs.push(macro $e{ _universe }.resources.insert($v{ id }, $e{ resExpr }));
    
            for (familyID in getFamilyIDsWithResource(id))
            {
                added.add(familyID);
            }
        };
    
        for (resource in _resources)
        {
            switch resource.expr
            {
                case EConst(CIdent(s)):
                    switch isLocalIdent(s, Context.getLocalType().getClass(), Context.getLocalTVars())
                    {
                        case Some(type):
                            insert(registerResource(signature(type)), resource);
                        case None:
                            final resolved  = try Context.getType(s) catch (_) Context.error('Unable to get type of resource expression ${ resource.toString() }', resource.pos);
                            final signature = signature(resolved);
                            final id        = registerResource(signature);
    
                            switch resolved.toComplexType()
                            {
                                case TPath(tp): insert(id, macro new $tp());
                                case other: Context.error('Resource ${ other.toString() } should be TPath', resource.pos);
                            }
                    }
                case _:
                    final resolved  = try Context.typeof(resource) catch (_) Context.error('Unable to get type of resource expression $resource', resource.pos);
                    final signature = signature(resolved);
                    final id        = registerResource(signature);

                    insert(id, resource);
            }
        }
    
        // Add a call to try and activate each families which requested the resources.
        for (familyID in added)
        {
            exprs.push(macro $e{ _universe }.families.tryActivate($v{ familyID }));
        }
    
        return macro $b{ exprs };
    }
    
    /**
     * Removes any number of resource from the given universe.
     * The final argument is a rest argument meaning it can take in any number of arguments.
     * 
     * Example usage for `using ecs.macros.UniverseMacros;`
     * 
     * ```
     * universe.removeResources(LevelData, SpriteBatcher);
     * ```
     * 
     * Attempting to remove a resource which is not used in any families will result in a compiler warning
     * and that expression will be skipped.
     * @param _universe Universe to remove the resource from.
     * @param _components Resources to remove.
     */
    @:ignoreInstrument public macro function removeResources(_universe : ExprOf<Universe>, _resources : Array<Expr>)
    {
        final exprs  = [];
        final adder  = new Set();
        final insert = id -> {
            adder.add(id);
    
            for (familyID in getFamilyIDsWithResource(id))
            {
                exprs.push(macro $e{ _universe }.families.get($v{ familyID }).deactivate());
            }
        };
    
        for (resource in _resources)
        {
            switch resource.expr
            {
                case EConst(CIdent(s)):
                    switch isLocalIdent(s, Context.getLocalType().getClass(), Context.getLocalTVars())
                    {
                        case Some(type):
                            switch getResourceID(signature(type))
                            {
                                case Some(id): insert(id);
                                case None: Context.warning('Resource $type is not used in any families', resource.pos);
                            }
                        case None:
                            final resolved  = try Context.getType(s) catch (_) Context.error('Unable to get type of resource expression ${ resource.toString() }', resource.pos);
                            final signature = signature(resolved);
    
                            switch getResourceID(signature)
                            {
                                case Some(id):
                                    switch resolved.toComplexType()
                                    {
                                        case TPath(_): insert(id);
                                        case other: Context.error('Resource ${ other.toString() } should be TPath', resource.pos);
                                    }
                                case None: Context.warning('Resource $resolved is not used in any families', resource.pos);
                            }
                    }
                case _:
                    Context.error('Unsupported resource expression ${ resource.toString() }', resource.pos);
            }
        }
    
        // Remove the resources once each family has been deactivated
        for (resourceID in adder)
        {
            exprs.push(macro for (i in 0...$e{ _universe }.families.number) $e{ _universe }.families.tryDeactivate(i, $v{ resourceID }));
    
            exprs.push(macro $e{ _universe }.resources.remove($v{ resourceID }));
        }
    
        return macro $b{ exprs };
    }
}