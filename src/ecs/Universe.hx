package ecs;

import ecs.ds.Set;
import ecs.core.EntityManager;
import ecs.core.FamilyManager;
import ecs.core.SystemManager;
import ecs.core.ResourceManager;
import ecs.core.ComponentManager;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
import ecs.macros.Utils;
import ecs.macros.UniverseMacros;
import ecs.macros.ComponentCache;
import ecs.macros.ResourceCache;
import ecs.macros.FamilyCache;

using haxe.macro.Tools;
#end


class Universe
{
    public final entities : EntityManager;
    public final components : ComponentManager;
    public final resources : ResourceManager;
    public final families : FamilyManager;
    public final systems : SystemManager;

    public function new(_maxEntities)
    {
        entities   = new EntityManager(_maxEntities);
        components = new ComponentManager(entities);
        resources  = new ResourceManager();
        families   = new FamilyManager(components, resources, _maxEntities);
        systems    = new SystemManager();
    }

    public function update(_dt : Float)
    {
        systems.update(_dt);
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
    public macro function setComponents(self : Expr, _entity : Expr, _components : Array<Expr>)
    {
        final staticLoading = haxe.macro.Context.defined('ecs.static_loading');
        final exprs         = [ macro final _ecsTmpEntity = $e{ _entity } ];
        final added         = new Set();
        final insert        = (id, compExpr) -> {
            exprs.push(macro $e{ self }.components.set(_ecsTmpEntity, $v{ id }, $e{ compExpr }));
    
            if (staticLoading)
            {
                for (familyID in ecs.macros.FamilyCache.getFamilyIDsWithComponent(id))
                {
                    added.add(familyID);
                }
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
                            if (staticLoading)
                            {
                                switch getComponentID(signature(type))
                                {
                                    case Some(id): insert(id, component);
                                    case None: Context.warning('Local ident $s : $type is not used in any families', component.pos);
                                }
                            }
                            else
                            {
                                insert(registerComponent(signature(type), type), component);
                            }
                        case None:
                            final resolved  = Context.getType(s);
                            final signature = signature(resolved);
    
                            if (staticLoading)
                            {
                                switch getComponentID(signature)
                                {
                                    case Some(id):
                                        switch resolved.toComplexType()
                                        {
                                            case TPath(tp): insert(id, macro new $tp());
                                            case other: Context.error('Component $other should be TPath', component.pos);
                                        }
                                    case None: Context.warning('Component $resolved is not used in any families', component.pos);
                                }
                            }
                            else
                            {
                                switch resolved.toComplexType()
                                {
                                    case TPath(tp): insert(registerComponent(signature, resolved), macro new $tp());
                                    case other: Context.error('Component $other should be TPath', component.pos);
                                }
                            }
                    }
                case _:
                    try
                    {
                        final resolved  = Context.typeof(component);
                        final signature = signature(resolved);
    
                        switch getComponentID(signature)
                        {
                            case Some(id): insert(id, component);
                            case None: Context.warning('Component ${ resolved } is not used in any families', component.pos);
                        }
                    }
                    catch (_)
                    {
                        Context.error('Unable to get type of component expression ${ component.toString() }', component.pos);
                    }
            }
        }
    
        // After all `set` functions are called check each family which could have been modified by the components added.
        exprs.push(macro final ecsEntCompFlags = $e{ self }.components.flags[_ecsTmpEntity.id()]);
        if (staticLoading)
        {
            // With static loaded the `added` set contains all families which could have been effected by the components added.
            // So we only need to check those ones.
            for (familyID in added)
            {
                exprs.push(macro final ecsTmpFamily = $e{ self }.families.get($v{ familyID }));
                exprs.push(macro if (ecsEntCompFlags.areSet(ecsTmpFamily.componentsMask)) {
                    ecsTmpFamily.add(_ecsTmpEntity);
                });
            }
        }
        else
        {
            // With dynamic loaded we have no choice but to check all families.
            exprs.push(macro for (i in 0...$e{ self }.families.number) {
                final ecsTmpFamily = $e{ self }.families.get(i);
                if (ecsEntCompFlags.areSet(ecsTmpFamily.componentsMask))
                {
                    ecsTmpFamily.add(_ecsTmpEntity);
                }
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
    public macro function removeComponents(_universe : ExprOf<Universe>, _entity : Expr, _components : Array<Expr>)
    {
        final staticLoading = Context.defined('ecs.static_loading');
        final exprs         = [ macro final _ecsTmpEntity = $e{ _entity } ];
        final added         = new Set();
        final insert        = id -> {
            exprs.push(macro $e{ _universe }.components.remove(_ecsTmpEntity, $v{ id }));
    
            if (staticLoading)
            {
                for (familyID in getFamilyIDsWithComponent(id))
                {
                    added.add(familyID);
                }
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
                            final resolved  = Context.getType(s);
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
        if (staticLoading)
        {
            // With static loaded the `added` set contains all families which could have been effected by the components added.
            // So we only need to check those ones.
            for (familyID in added)
            {
                exprs.push(macro final ecsTmpFamily = $e{ _universe }.families.get($v{ familyID }));
                exprs.push(macro if (!ecsEntCompFlags.areSet(ecsTmpFamily.componentsMask)) {
                    ecsTmpFamily.remove(_ecsTmpEntity);
                });
            }
        }
        else
        {
            // With dynamic loaded we have no choice but to check all families.
            exprs.push(macro for (i in 0...$e{ _universe }.families.number) {
                final ecsTmpFamily = $e{ _universe }.families.get(i);
                if (!ecsEntCompFlags.areSet(ecsTmpFamily.componentsMask))
                {
                    ecsTmpFamily.add(_ecsTmpEntity);
                }
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
    public macro function setResources(_universe : ExprOf<Universe>, _resources : Array<Expr>)
    {
        final staticLoading = Context.defined('ecs.static_loading');
        final exprs         = [];
        final added         = new Set();
        final insert        = (id, resExpr) -> {
            exprs.push(macro $e{ _universe }.resources.insert($v{ id }, $e{ resExpr }));
    
            if (staticLoading)
            {
                for (familyID in getFamilyIDsWithResource(id))
                {
                    added.add(familyID);
                }   
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
                            final resolved  = Context.getType(s);
                            final signature = signature(resolved);
                            final id        = registerResource(signature);
    
                            switch resolved.toComplexType()
                            {
                                case TPath(tp): insert(id, macro new $tp());
                                case other: Context.error('Resource $other should be TPath', resource.pos);
                            }
                    }
                case _:
                    try
                    {
                        final resolved  = Context.typeof(resource);
                        final signature = signature(resolved);
                        final id        = registerResource(signature);
    
                        insert(id, resource);
                    }
                    catch (_)
                    {
                        Context.error('Unable to get type of resource expression $resource', resource.pos);
                    }
            }
        }
    
        // Add a call to try and activate each families which requested the resources.
        // If we are not dynamically loading we can reduced the number of families we try and activate
        // When dynamically loading we have no choice by to try and load each family.
        if (staticLoading)
        {
            for (familyID in added)
            {
                exprs.push(macro $e{ _universe }.families.tryActivate($v{ familyID }));
            }
        }
        else
        {
            exprs.push(macro for (i in 0...$e{ _universe }.families.number) $e{ _universe }.families.tryActivate(i));
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
    public macro function removeResources(_universe : ExprOf<Universe>, _resources : Array<Expr>)
    {
        final staticLoading = Context.defined('ecs.static_loading');
        final exprs         = [];
        final adder         = new Set();
        final insert        = id -> {
            adder.add(id);
    
            if (staticLoading)
            {
                for (familyID in getFamilyIDsWithResource(id))
                {
                    exprs.push(macro $e{ _universe }.families.get($v{ familyID }).deactivate());
                }
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
                            final resolved  = Context.getType(s);
                            final signature = signature(resolved);
    
                            switch getResourceID(signature)
                            {
                                case Some(id):
                                    switch resolved.toComplexType()
                                    {
                                        case TPath(_): insert(id);
                                        case other:
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
            if (!staticLoading)
            {
                exprs.push(macro for (i in 0...$e{ _universe }.families.number) $e{ _universe }.families.tryDeactivate(i, $v{ resourceID }));
            }
    
            exprs.push(macro $e{ _universe }.resources.remove($v{ resourceID }));
        }
    
        return macro $b{ exprs };
    }
    
    /**
     * Add any number of systems to be ran by the provided universe.
     * The final argument is a rest argument meaning it can take in any number of arguments.
     * 
     * Example usage for `using ecs.macros.UniverseMacros;`
     * 
     * ```
     * unverse.setSystems(
     *     new VelocitySystem(),
     *     new SpriteDrawingSystem());
     * ```
     * 
     * Along with the usual variable, function, and constructor expressions if the system does not have a custom
     * constructor you can provide just the type and it will be constructed for you.
     * 
     * ```
     * universe.setSystems(
     *     new VelocitySystem(),
     *     SpriteDrawingSystem);
     * ```
     * 
     * Systems are updated in the order they were added, and adding the same system to the universe twice will cause it
     * to be updated twice on every universe update.
     * @param _universe Universe to add systems to.
     * @param _systems Systems to add.
     */
    public macro function setSystems(_universe : ExprOf<Universe>, _systems : Array<Expr>)
    {
        final exprs = [];
    
        for (system in _systems)
        {
            switch system.expr
            {
                case EConst(CIdent(s)):
                    // Systems don't have unique IDs so we pass a function which will always return 0.
                    // This way we can still use the same resolution logic
                    switch isLocalIdent(s, Context.getLocalType().getClass(), Context.getLocalTVars())
                    {
                        case Some(_):
                            exprs.push(macro $e{ _universe }.systems.add($e{ system }));
                        case None:
                            switch Context.getType(s).toComplexType()
                            {
                                case TPath(tp): exprs.push(macro $e{ _universe }.systems.add(new $tp($e{ _universe })));
                                case other: Context.error('System $other should be TPath', system.pos);
                            }
                    }
                case ENew(tp, _):
                    exprs.push(macro $e{ _universe }.systems.add($e{ system }));
                case _:
                    Context.error('Unsupported system expression ${ system }', system.pos);
            }
        }
    
        return macro $b{ exprs };
    }
    
    /**
     * Remove any number of systems from the provided universe.
     * The final argument is a rest argument meaning it can take in any number of arguments.
     * 
     * Example usage for `using ecs.macros.UniverseMacros;`
     * 
     * ```
     * unverse.removeSystems(
     *     someField,
     *     functionWhichReturnsSomeSystem());
     * ```
     * 
     * The system expressions must refer to a system object, as currently systems do not have a unique ID.
     * 
     * @param _universe Universe to remove systems from.
     * @param _systems fields pointing to system objects to remove.
     */
    public macro function removeSystems(_universe : ExprOf<Universe>, _systems : Array<Expr>)
    {
        final exprs = [];
    
        for (system in _systems)
        {
            switch system.expr
            {
                case EConst(CIdent(s)):
                    switch isLocalIdent(s, Context.getLocalType().getClass(), Context.getLocalTVars())
                    {
                        case Some(_):
                            exprs.push(macro $e{ _universe }.systems.remove($e{ system }));
                        case None:
                            Context.error('Only expressions which reference a system object can be used to remove a system', system.pos);
                    }
                case _: Context.error('Only expressions which reference a system object can be used to remove a system', system.pos);
            }
        }
    
        return macro $b{ exprs };
    }
}