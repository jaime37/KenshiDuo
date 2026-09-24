// ResearchUnion.h - symmetric grow-only union for the research channel
// (protocol 38; pure, zero game/Win32 deps).
//
// The known-research set is MONOTONIC in Kenshi: startResearch flips isKnown
// and nothing ever un-knows a sid. The channel therefore runs as a grow-only
// CRDT set: BOTH clients publish their known set AND apply the peer's rows,
// and the union converges without arbitration or authority. It used to be
// hostAuth=true (one-directional host->join), so a research completed by the
// JOIN never reached the host (extracted from PR #21, 2026-07-20).
//
// Apply-side idempotence (researchRowDecision): a duplicate/stale row drops
// (scalar per-sid seq guard - safe TODAY because a row's content is
// emitter-independent: any sender asserting sid X means the exact same thing;
// re-audit for 3+ emitters, see ResearchRow in Replicator.h), and a resend of
// an already-landed sid advances the guard but never re-applies, so a known
// research persists.
//
// Tested in src/prototest/main.cpp (testResearchUnion); used by
// Replicator::applyResearch and the kCh[] table in ReplicatorChannels.cpp.

#ifndef COOP_RESEARCH_UNION_H
#define COOP_RESEARCH_UNION_H

#include "../sync/ChangeGate.h" // sync::gateSeqAccept

namespace coop {

// Channel direction contract for the kCh[] table: symmetric union => NOT
// host-authoritative; both sides publish AND apply.
inline bool researchChannelHostAuth() { return false; }

// Per-row apply decision for an incoming known-research row.
enum ResearchRowDecision {
    RESEARCH_ROW_DROP_STALE,  // duplicate/reordered row: ignore entirely
    RESEARCH_ROW_SKIP_LANDED, // fresh resend of an already-applied sid: advance
                              // the guard, do NOT re-run startResearch
    RESEARCH_ROW_APPLY        // new sid row: apply through startResearch
};

// Judges an incoming row against the row's scalar seq guard and applied latch,
// advancing seqSeen on accept (the exact guard applyResearch ran inline).
inline ResearchRowDecision researchRowDecision(unsigned int& seqSeen,
                                               unsigned int seq,
                                               bool applied) {
    if (!sync::gateSeqAccept(seqSeen, seq)) return RESEARCH_ROW_DROP_STALE;
    seqSeen = seq;
    return applied ? RESEARCH_ROW_SKIP_LANDED : RESEARCH_ROW_APPLY;
}

} // namespace coop

#endif // COOP_RESEARCH_UNION_H
