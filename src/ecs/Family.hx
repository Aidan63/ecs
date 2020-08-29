package ecs;

import bits.Bits;

class Family {
    public final id : Int;

    public final mask : Bits;

    public function new(_id, _mask) {
        id   = _id;
        mask = _mask;
    }

    public function size() {
        return 0;
    }
}