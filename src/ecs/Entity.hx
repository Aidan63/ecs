package ecs;

abstract Entity(Int) to Int {
    public inline function new(_id) {
        this = _id;
    }
}