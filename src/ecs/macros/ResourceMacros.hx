package ecs.macros;

#if macro
import ecs.macros.ResourceCache;
#end

macro function createResourceVector()
{
    return macro new haxe.ds.Vector($v{ getResourceCount() });
}

macro function createResourceBits()
{
    return macro new bits.Bits($v{ getResourceCount() });
}