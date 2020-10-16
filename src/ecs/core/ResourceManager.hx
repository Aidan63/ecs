package ecs.core;

import haxe.ds.Vector;
import bits.Bits;
import ecs.ds.Unit;
import ecs.ds.Signal;
import ecs.macros.ResourceMacros;

class ResourceManager
{
    /**
     * Bits which indicate which resources are currently stored in the system.
     */
    public final flags : Bits;

    /**
     * Vector for storing all active resources.
     */
    final resources : Vector<Any>;

    public function new()
    {
        flags     = createResourceBits();
        resources = createResourceVector();
    }

    /**
     * Gets the resource with the provided ID.
     * If the resource is not in the system null is returned.
     * @param _id Resource ID.
     */
    public function get(_id : Int)
    {
        return resources[_id];
    }

    /**
     * Add a resource into the world.
     * @param _id Resource ID.
     * @param _resource Resource object.
     */
    public function insert(_id : Int, _resource : Any)
    {
        resources[_id] = _resource;

        flags.set(_id);
    }

    /**
     * Remove a resource from the world.
     * @param _id Resource ID.
     */
    public function remove(_id : Int)
    {
        flags.unset(_id);

        resources[_id] = null;
    }
}