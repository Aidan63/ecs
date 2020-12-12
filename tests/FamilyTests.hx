import bits.Bits;
import ecs.Family;
import ecs.Entity;
import buddy.BuddySuite;

using buddy.Should;

class FamilyTests extends BuddySuite
{
    public function new()
    {
        describe('Family Tests', {
            describe('construction', {
                it('will immediately activate the family if it requires no resources', {
                    final family = new Family(0, new Bits(), new Bits(), 8);

                    family.isActive().should.be(true);
                });
                it('will not activate the family on creation if it requires resources', {
                    final bits = new Bits(4);
                    bits.set(0);

                    final family = new Family(0, new Bits(), bits, 8);

                    family.isActive().should.be(false);
                });
            });
            describe('entities', {
                it('will publish added entities through the onEntityAdded signal if the family is activated', {
                    final entity = new Entity(7);
                    final family = new Family(0, new Bits(), new Bits(), 8);

                    var id = -1;
                    family.onEntityAdded.subscribe(e -> id = e.id());
                    family.add(entity);

                    id.should.be(7);
                });
                it('will not publish added entities through the onEntityAdded signal if the family is not activated', {
                    final bits = new Bits(4);
                    bits.set(0);

                    final entity = new Entity(7);
                    final family = new Family(0, new Bits(), bits, 8);

                    var id = -1;
                    family.onEntityAdded.subscribe(e -> id = e.id());
                    family.add(entity);

                    id.should.be(-1);
                });
                it('will not publish added entities through the onEntityAdded signal if the entity is already in the family', {
                    final entity = new Entity(7);
                    final family = new Family(0, new Bits(), new Bits(), 8);

                    var id = 0;
                    family.onEntityAdded.subscribe(e -> id += e.id());
                    family.add(entity);
                    family.add(entity);

                    id.should.be(7);
                });
                it('will publish removed entities through the onEntityRemoved signal if the family is activated', {
                    final entity = new Entity(7);
                    final family = new Family(0, new Bits(), new Bits(), 8);

                    var id = -1;
                    family.onEntityRemoved.subscribe(e -> id = e.id());
                    family.add(entity);
                    family.remove(entity);

                    id.should.be(7);
                });
                it('will not publish removed entities through the onEntityRemoved signal if the family is not activated', {
                    final bits = new Bits(4);
                    bits.set(0);

                    final entity = new Entity(7);
                    final family = new Family(0, new Bits(), bits, 8);

                    var id = -1;
                    family.onEntityRemoved.subscribe(e -> id = e.id());
                    family.add(entity);
                    family.remove(entity);

                    id.should.be(-1);
                });
                it('will not publish removed entities through the onEntityRemoved signal if the entity is not in the family', {
                    final entity = new Entity(7);
                    final family = new Family(0, new Bits(), new Bits(), 8);

                    var id = 0;
                    family.onEntityRemoved.subscribe(e -> id += e.id());
                    family.add(entity);
                    family.remove(entity);
                    family.remove(entity);

                    id.should.be(7);
                });
                it('will publish all entities through the onEntityAdded when a family is activated', {
                    final bits = new Bits(4);
                    bits.set(0);

                    final e1     = new Entity(5);
                    final e2     = new Entity(6);
                    final e3     = new Entity(7);
                    final family = new Family(0, new Bits(), bits, 8);
                    final added  = [];
                    
                    family.onEntityAdded.subscribe(e -> added.push(e));
                    family.add(e1);
                    family.add(e2);
                    family.add(e3);

                    added.should.containExactly([]);

                    family.activate();

                    added.should.containExactly([ e1, e2, e3 ]);
                });
                it('will publish all entities through the onEntityRemoved when a family is deactivated', {
                    final e1      = new Entity(5);
                    final e2      = new Entity(6);
                    final e3      = new Entity(7);
                    final family  = new Family(0, new Bits(), new Bits(), 8);
                    final removed = [];

                    family.onEntityRemoved.subscribe(e -> removed.push(e));
                    family.add(e1);
                    family.add(e2);
                    family.add(e3);

                    removed.should.containExactly([]);

                    family.deactivate();

                    removed.should.containExactly([ e1, e2, e3 ]);
                });
            });
            describe('iteration', {
                it('will return an iterator for all added entities', {
                    final e1 = new Entity(5);
                    final e2 = new Entity(6);
                    final e3 = new Entity(7);

                    final family = new Family(0, new Bits(), new Bits(), 8);
                    family.add(e1);
                    family.add(e2);
                    family.add(e3);

                    final out = [ for (e in family) e ];
                    out.should.containExactly([ e1, e2, e3 ]);
                });
            });
        });
    }
}