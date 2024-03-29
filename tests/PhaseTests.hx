import ecs.System;
import ecs.Phase;
import ecs.Universe;
import haxe.Exception;
import haxe.ds.Vector;
import buddy.BuddySuite;

using buddy.Should;

class PhaseTests extends BuddySuite
{
    public function new()
    {
        describe('Phase Tests', {
            it('allows getting a system by type', {
                final system  = new CountingSystem(null);
                final systems = Vector.fromArrayCopy([ (system : System) ]);
                final enabled = Vector.fromArrayCopy([ true ]);
                final phase   = new Phase(true, '', systems, enabled);

                phase.getSystem(CountingSystem).should.be(system);
            });
            it('will throw an exception if the system could not be found', {
                final system  = new CountingSystem(null);
                final systems = Vector.fromArrayCopy([ (system : System) ]);
                final enabled = Vector.fromArrayCopy([ true ]);
                final phase   = new Phase(true, '', systems, enabled);

                try
                {
                    phase.getSystem(MyOtherSystem);

                    fail('exception was not thrown');
                }
                catch (_)
                {
                    //
                }
            });

            describe('update', {
                it('will update all enabled systems if enabled', {
                    final system  = new CountingSystem(null);
                    final systems = Vector.fromArrayCopy([ (system : System) ]);
                    final enabled = Vector.fromArrayCopy([ true ]);
                    final phase   = new Phase(true, '', systems, enabled);
    
                    phase.update(0);
                    system.updateCounter.should.be(1);
                });
                it('will update no systems if not enabled', {
                    final system  = new CountingSystem(null);
                    final systems = Vector.fromArrayCopy([ (system : System) ]);
                    final enabled = Vector.fromArrayCopy([ true ]);
                    final phase   = new Phase(false, '', systems, enabled);
    
                    phase.update(0);
                    system.updateCounter.should.be(0);
                });
                it('will not update disabled systems if enabled', {
                    final system  = new CountingSystem(null);
                    final systems = Vector.fromArrayCopy([ (system : System) ]);
                    final enabled = Vector.fromArrayCopy([ false ]);
                    final phase   = new Phase(true, '', systems, enabled);
    
                    phase.update(0);
                    system.updateCounter.should.be(0);
                });
                it('will not update disabled systems if disabled', {
                    final system  = new CountingSystem(null);
                    final systems = Vector.fromArrayCopy([ (system : System) ]);
                    final enabled = Vector.fromArrayCopy([ false ]);
                    final phase   = new Phase(false, '', systems, enabled);
    
                    phase.update(0);
                    system.updateCounter.should.be(0);
                });
            });

            describe('enabling', {
                describe('phases', {
                    it('will not call onEnabled on systems when enabling an already enabled phase', {
                        final system  = new CountingSystem(null);
                        final systems = Vector.fromArrayCopy([ (system : System) ]);
                        final enabled = Vector.fromArrayCopy([ true ]);
                        final phase   = new Phase(true, '', systems, enabled);
        
                        phase.enable();
                        system.addedCounter.should.be(0);
                    });
                    it('will call onEnabled on systems which are enabled when enabling a phase', {
                        final system  = new CountingSystem(null);
                        final systems = Vector.fromArrayCopy([ (system : System) ]);
                        final enabled = Vector.fromArrayCopy([ true ]);
                        final phase   = new Phase(false, '', systems, enabled);
        
                        phase.enable();
                        system.addedCounter.should.be(1);
                    });
                    it('will not call onEnabled on systems which were manually disabled when enabling a phase', {
                        final system  = new CountingSystem(null);
                        final systems = Vector.fromArrayCopy([ (system : System) ]);
                        final enabled = Vector.fromArrayCopy([ false ]);
                        final phase   = new Phase(false, '', systems, enabled);
        
                        phase.enable();
                        system.addedCounter.should.be(0);
                    });
                });
                describe('systems', {
                    it('will call the onEnabled function on a system when enabled', {
                        final system  = new CountingSystem(null);
                        final systems = Vector.fromArrayCopy([ (system : System) ]);
                        final enabled = Vector.fromArrayCopy([ false ]);
                        final phase   = new Phase(true, '', systems, enabled);

                        phase.enableSystem(CountingSystem);
                        system.addedCounter.should.be(1);
                    });
                    it('will not call the onEnabled function on a system which is already enabled', {
                        final system  = new CountingSystem(null);
                        final systems = Vector.fromArrayCopy([ (system : System) ]);
                        final enabled = Vector.fromArrayCopy([ true ]);
                        final phase   = new Phase(true, '', systems, enabled);

                        phase.enableSystem(CountingSystem);
                        system.addedCounter.should.be(0);
                    });
                    it('will throw an exception if a system of the specified type is not found', {
                        final system  = new CountingSystem(null);
                        final systems = Vector.fromArrayCopy([ (system : System) ]);
                        final enabled = Vector.fromArrayCopy([ true ]);
                        final phase   = new Phase(true, '', systems, enabled);

                        try
                        {
                            phase.enableSystem(MyOtherSystem);

                            fail('exception was not thrown');
                        }
                        catch (_)
                        {
                            //
                        }
                    });
                });
            });

            describe('disabling', {
                describe('phases', {
                    it('will not call onDisabled on systems when disabling an already disabled phase', {
                        final system  = new CountingSystem(null);
                        final systems = Vector.fromArrayCopy([ (system : System) ]);
                        final enabled = Vector.fromArrayCopy([ true ]);
                        final phase   = new Phase(false, '', systems, enabled);
        
                        phase.disable();
                        system.removedCounter.should.be(0);
                    });
                    it('will call onDisabled on systems which are enabled when disabling a phase', {
                        final system  = new CountingSystem(null);
                        final systems = Vector.fromArrayCopy([ (system : System) ]);
                        final enabled = Vector.fromArrayCopy([ true ]);
                        final phase   = new Phase(true, '', systems, enabled);
        
                        phase.disable();
                        system.removedCounter.should.be(1);
                    });
                    it('will not call onDisabled on systems which were manually disabled when disabling a phase', {
                        final system  = new CountingSystem(null);
                        final systems = Vector.fromArrayCopy([ (system : System) ]);
                        final enabled = Vector.fromArrayCopy([ false ]);
                        final phase   = new Phase(true, '', systems, enabled);
        
                        phase.disable();
                        system.removedCounter.should.be(0);
                    });
                });
                describe('systems', {
                    it('will call the onDisabled function on a system when disabled', {
                        final system  = new CountingSystem(null);
                        final systems = Vector.fromArrayCopy([ (system : System) ]);
                        final enabled = Vector.fromArrayCopy([ true ]);
                        final phase   = new Phase(true, '', systems, enabled);

                        phase.disableSystem(CountingSystem);
                        system.removedCounter.should.be(1);
                    });
                    it('will not call the onDisabled function on a system which is already disabled', {
                        final system  = new CountingSystem(null);
                        final systems = Vector.fromArrayCopy([ (system : System) ]);
                        final enabled = Vector.fromArrayCopy([ false ]);
                        final phase   = new Phase(true, '', systems, enabled);

                        phase.disableSystem(CountingSystem);
                        system.removedCounter.should.be(0);
                    });
                    it('will throw an exception if a system of the specified type is not found', {
                        final system  = new CountingSystem(null);
                        final systems = Vector.fromArrayCopy([ (system : System) ]);
                        final enabled = Vector.fromArrayCopy([ true ]);
                        final phase   = new Phase(true, '', systems, enabled);

                        try
                        {
                            phase.disableSystem(MyOtherSystem);

                            fail('exception was not thrown');
                        }
                        catch (_)
                        {
                            //
                        }
                    });
                });
            });
        });
    }
}

private class CountingSystem extends System
{
    public var updateCounter = 0;

    public var addedCounter = 0;

    public var removedCounter = 0;

    override function update(_ : Float)
    {
        updateCounter++;
    }

    override function onEnabled()
    {
        addedCounter++;
    }

    override function onDisabled()
    {
        removedCounter++;
    }
}

private class MyOtherSystem extends System {}