// JailAnchor.h - captive furniture-kind conflict policy (pure, zero
// game/Win32 deps).
//
// A caged prisoner is often ALSO shackled: the owner's reliable furniture
// state settles on the cage (publish kind priority bed=1 > cage=2 >
// chained=3) while the lossy continuous bodyState batch can still say
// CHAINED-only, so the driven copy sees streamKind=3 against a vouched
// localKind=2. The kind=3 self-heal used to resolve that by BREAKING the
// cage and re-chaining every FURN_HEAL_MS - a median 75-88 u (tail 885 u)
// re-seat teleport on 10-15 bodies per session (spike 58, findings 1-2).
//
// The rule (spike 58 follow-up 1): while a RELIABLE edge vouches the local
// cage/bed, the cage/bed is the transform anchor and the shackle is an
// EQUIP-only state - never break the anchor over a continuous-bit
// disagreement. A local cage NO edge vouches for is a stale attach at the
// wrong spot (the Flashbox case) and must still be broken and re-chained.
//
// Vouch sources: the original PR stamped it on the legacy RECV ENTER
// furniture events; under protocol 59 beds/cages no longer travel as events
// but as the host's canonical FURNITURE_STATE row, so the vouch is stamped
// when that row is applied (furnEdgeVouchFromState) and withdrawn on a
// canonical release or the debounced HEAL EXIT. The legacy chained-only
// (kind 3) events never touch the vouch: chain and cage are orthogonal.
// Tested in src/prototest/main.cpp (testJailAnchor); used by
// Replicator::applyTargets (ReplicatorDrive.cpp) and
// Replicator::applyFurniturePackets (ReplicatorSpawn.cpp).

#ifndef COOP_JAIL_ANCHOR_H
#define COOP_JAIL_ANCHOR_H

namespace coop {

enum ChainAnchorAct {
    CHAIN_ANCHOR_NONE    = 0, // stream not chained, or already chained locally
    CHAIN_ANCHOR_HOLD    = 1, // edge-vouched cage/bed anchors the transform;
                              //   re-assert the chain EQUIP-only, never break
    CHAIN_ANCHOR_RECHAIN = 2  // no/stale local furniture: existing heal path
                              //   (break an unvouched cage/bed, re-chain)
};

// One decision for one driven body per tick. streamKind = what the owner's
// continuous batch reports (0 none / 1 bed / 2 cage / 3 chained); localKind =
// where our copy actually sits (readFurniture, 0 when absent/invalid);
// edgeKind = the furniture kind last vouched for this body by a RELIABLE
// edge (an applied canonical FURNITURE_STATE row; 0 = none, cleared on a
// canonical release / the debounced HEAL EXIT).
inline ChainAnchorAct chainAnchorStep(int streamKind, int localKind,
                                      int edgeKind) {
    if (streamKind != 3) return CHAIN_ANCHOR_NONE; // conflict is kind-3 only
    if (localKind == 3)  return CHAIN_ANCHOR_NONE; // already chained: in sync
    if ((localKind == 1 || localKind == 2) && edgeKind == localKind)
        return CHAIN_ANCHOR_HOLD;                  // vouched anchor wins
    return CHAIN_ANCHOR_RECHAIN;                   // stale/absent: heal as before
}

// The vouch an applied canonical FURNITURE_STATE row (protocol 59) stamps on
// the driven record: the row's kind while occupied, 0 on a canonical
// release. Pure so the canonical-path stamping shares the tested contract.
inline int furnEdgeVouchFromState(bool on, int kind) {
    return on ? kind : 0;
}

} // namespace coop

#endif // COOP_JAIL_ANCHOR_H
