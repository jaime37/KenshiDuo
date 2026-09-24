// ProdTemplateMatch.h - building-template preference lists + localized-name
// matching for the production probe's programmatic placement (pure, zero
// game/Win32 deps).
//
// findProdTemplate (EngineWorld.cpp) picks a deterministic BUILDING template
// per machine kind by walking an ordered preference list (most specific
// first). On a Spanish-locale (es_ES) game the display NAME is translated, so
// the English-only lists never matched and the probe logged "no template".
// Each candidate now matches by display name (English OR Spanish terms) OR by
// stringID - the internal FCS id, stable and language-independent (extracted
// from PR #21, 2026-07-20). The lists are ASCII-only on purpose: ciContains is
// an ASCII case-insensitive substring test, and prefix terms like "herrer" or
// "investigaci" match regardless of a trailing accented vowel.
//
// Tested in src/prototest/main.cpp (testProdTemplateMatch); used by
// findProdTemplate in EngineWorld.cpp.

#ifndef COOP_PROD_TEMPLATE_MATCH_H
#define COOP_PROD_TEMPLATE_MATCH_H

namespace coop {
namespace prodtmpl {

// Case-insensitive ASCII substring test on raw C strings (no temporaries ->
// SEH legal). Same contract as engine::ciContains (EngineEntity.cpp),
// re-implemented here so the pure unit layer links it without the engine TUs.
inline bool ciContains(const char* hay, const char* needle) {
    if (!hay || !needle || !needle[0]) return false;
    for (const char* h = hay; *h; ++h) {
        const char* a = h; const char* b = needle;
        while (*a && *b) {
            char ca = *a, cb = *b;
            if (ca >= 'A' && ca <= 'Z') ca = (char)(ca - 'A' + 'a');
            if (cb >= 'A' && cb <= 'Z') cb = (char)(cb - 'A' + 'a');
            if (ca != cb) break;
            ++a; ++b;
        }
        if (!*b) return true;
    }
    return false;
}

// Ordered preference lists per machine kind (same kinds as findProdTemplate:
// 0 = power generator, 1 = crafting bench, 2 = storage container, 3 =
// research bench). English terms match by stringID on any locale; the Spanish
// terms cover the es_ES display names.
inline const char* const* prefsForKind(int kind, unsigned int* nPrefs) {
    static const char* genPrefs[]   = { "small wind generator", "wind generator",
                                        "small generator", "generator",
                                        "generador" };
    static const char* craftPrefs[] = { "armour crafting bench", "weapon smithing bench",
                                        "weapon smith", "engineering bench",
                                        "herreria", "herrer", "armadura",
                                        "ingenieria", "ingenier", "fabricaci",
                                        "banco de" };
    static const char* storePrefs[] = { "general storage", "storage box", "storage chest",
                                        "chest", "storage",
                                        "almacen", "caja", "cofre" };
    static const char* resPrefs[]   = { "small research bench", "research bench",
                                        "research",
                                        "investigaci" };
    const char* const* prefs;
    unsigned int n;
    if (kind == 0)      { prefs = genPrefs;   n = sizeof(genPrefs) / sizeof(genPrefs[0]); }
    else if (kind == 2) { prefs = storePrefs; n = sizeof(storePrefs) / sizeof(storePrefs[0]); }
    else if (kind == 3) { prefs = resPrefs;   n = sizeof(resPrefs) / sizeof(resPrefs[0]); }
    else                { prefs = craftPrefs; n = sizeof(craftPrefs) / sizeof(craftPrefs[0]); }
    if (nPrefs) *nPrefs = n;
    return prefs;
}

// A candidate matches a preference term by display name (possibly translated)
// OR by the language-independent stringID. Either may be null.
inline bool matches(const char* name, const char* stringID, const char* pref) {
    return ciContains(name, pref) || ciContains(stringID, pref);
}

} // namespace prodtmpl
} // namespace coop

#endif // COOP_PROD_TEMPLATE_MATCH_H
