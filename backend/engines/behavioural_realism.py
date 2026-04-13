"""
Behavioural Realism Filter — AgriESG Food Twin Engine
======================================================
Author: Esther Oluwasolayimika Olusola

PURPOSE:
--------
This module filters and scores food substitution candidates based on
behavioural realism — the likelihood that a consumer would actually
accept and adopt a recommended swap in their real grocery routine.

Technical optimisation alone is insufficient for food recommendations.
A substitution may be optimal on cost, nutrition, and environment but
still be rejected by users because it disrupts their established routine,
requires unfamiliar preparation, or fails to satisfy the same craving.

This filter addresses the gap between technically optimal and
behaviourally adoptable substitutions.

THREE REALISM DIMENSIONS:
--------------------------
1. Role Match (weight: 0.40)
   Does the substitute serve the same functional role in the meal?
   Protein → protein, carb → carb, dairy → dairy.
   Sub-role matching adds granularity beyond broad category.

2. Taste Similarity (weight: 0.35)
   Does the substitute satisfy the same craving?
   Computed from taste_profile, texture_profile, flavour_intensity,
   and meal_context alignment between original and substitute.

3. Effort Similarity (weight: 0.25)
   Does the substitute fit the same cooking routine?
   Computed from prep_type, prep_time_minutes, and prep_complexity
   alignment between original and substitute.

MISSING DATA PHILOSOPHY:
------------------------
Consistent with AgriESG system-wide principle:
- Missing fields → neutral score (0.5), not penalised
- System never falsely eliminates a realistic swap due to data gaps
- Filters only when there is positive evidence of mismatch
- All seven behavioural fields optional until dataset is updated

REALISM THRESHOLD:
------------------
Swaps scoring below 0.45 are filtered out before reaching the
Pareto optimisation engine. This threshold was chosen to:
- Eliminate clearly unrealistic swaps (score < 0.45)
- Preserve borderline swaps for Pareto evaluation (0.45–0.65)
- Pass clearly realistic swaps without friction (> 0.65)
"""

from typing import Dict, Optional


# ─────────────────────────────────────────────────────────────────
# Realism dimension weights
#
# Design decision: role match weighted highest (0.40) because a swap
# that changes the functional role of a food in a meal is the most
# disruptive regardless of taste or effort similarity.
# e.g. replacing a protein with a carb fails regardless of how
# similar they are in preparation.
# ─────────────────────────────────────────────────────────────────
ROLE_WEIGHT = 0.40
TASTE_WEIGHT = 0.35
EFFORT_WEIGHT = 0.25

# Minimum realism score to pass filter
# Design decision: 0.45 rather than 0.50 because we want to err on
# the side of inclusion — better to let the Pareto engine evaluate
# a borderline swap than to eliminate a realistic one prematurely
REALISM_THRESHOLD = 0.45

# Penalty for large flavour intensity divergence
# Swaps across more than 2 intensity points feel wrong to most users
# e.g. lamb (5) → chicken breast (2) fails craving satisfaction
MAX_INTENSITY_GAP = 2

# Maximum prep time ratio before effort mismatch is flagged
# e.g. if substitute takes 3x longer to prepare, routine is disrupted
MAX_PREP_TIME_RATIO = 3.0


# ─────────────────────────────────────────────────────────────────
# DIMENSION 1: Role Match
# ─────────────────────────────────────────────────────────────────

def score_role_match(original: Dict, substitute: Dict) -> float:
    """
    Score functional role similarity between original and substitute.

    Returns:
    --------
    1.0  — same role and same meal context
    0.75 — same role, different meal context
    0.25 — different role
    0.5  — missing data, neutral

    Design decision: role mismatch returns 0.25 rather than 0.0
    because some cross-role swaps are realistic (e.g. eggs can serve
    as both protein and breakfast staple). Hard zero would be too
    aggressive given the current role taxonomy limitations.
    """
    orig_role = original.get('role')
    sub_role = substitute.get('role')
    orig_context = original.get('meal_context')
    sub_context = substitute.get('meal_context')

    # Missing role data — return neutral
    if not orig_role or not sub_role:
        return 0.5

    orig_role = orig_role.lower().strip()
    sub_role = sub_role.lower().strip()

    if orig_role != sub_role:
        # Different functional role — significant realism penalty
        return 0.25

    # Same role — check meal context if available
    if orig_context and sub_context:
        orig_context = orig_context.lower().strip()
        sub_context = sub_context.lower().strip()
        if orig_context == sub_context:
            return 1.0
        else:
            # Same role, different context — partial match
            # e.g. rice (side dish) vs barley (soup base)
            # Both are carbs but different meal contexts
            return 0.75

    # Same role, no context data — good but not confirmed
    return 0.80


# ─────────────────────────────────────────────────────────────────
# DIMENSION 2: Taste Similarity
# ─────────────────────────────────────────────────────────────────

def score_taste_similarity(original: Dict, substitute: Dict) -> float:
    """
    Score taste and craving similarity between original and substitute.

    Computed from three sub-signals:
    - taste_profile match (string equality)
    - texture_profile match (string equality)
    - flavour_intensity proximity (numeric distance)

    Design decision: equal weighting across three sub-signals because
    each independently contributes to craving satisfaction.
    A swap can fail on any one — wrong texture, wrong intensity, or
    wrong taste profile — and feel unrealistic to the user.

    Returns float 0.0–1.0, or 0.5 if all fields missing.
    """
    scores = []

    # Taste profile match
    orig_taste = original.get('taste_profile')
    sub_taste = substitute.get('taste_profile')
    if orig_taste and sub_taste:
        scores.append(
            1.0 if orig_taste.lower().strip() == sub_taste.lower().strip()
            else 0.2
        )

    # Texture profile match
    orig_texture = original.get('texture_profile')
    sub_texture = substitute.get('texture_profile')
    if orig_texture and sub_texture:
        scores.append(
            1.0 if orig_texture.lower().strip() == sub_texture.lower().strip()
            else 0.3
        )

    # Flavour intensity proximity
    orig_intensity = original.get('flavour_intensity')
    sub_intensity = substitute.get('flavour_intensity')
    if orig_intensity is not None and sub_intensity is not None:
        try:
            gap = abs(int(orig_intensity) - int(sub_intensity))
            if gap == 0:
                intensity_score = 1.0
            elif gap <= MAX_INTENSITY_GAP:
                # Linear decay within acceptable range
                intensity_score = 1.0 - (gap / MAX_INTENSITY_GAP) * 0.5
            else:
                # Gap too large — craving satisfaction will fail
                # e.g. lamb (5) → chicken breast (2): gap of 3
                intensity_score = 0.1
            scores.append(intensity_score)
        except (ValueError, TypeError):
            pass

    # Missing data — return neutral
    if not scores:
        return 0.5

    return round(sum(scores) / len(scores), 4)


# ─────────────────────────────────────────────────────────────────
# DIMENSION 3: Effort Similarity
# ─────────────────────────────────────────────────────────────────

def score_effort_similarity(original: Dict, substitute: Dict) -> float:
    """
    Score preparation effort similarity between original and substitute.

    Computed from three sub-signals:
    - prep_type match (string equality — most important effort signal)
    - prep_time_minutes ratio (numeric proximity)
    - prep_complexity proximity (numeric distance)

    Design decision: prep_type weighted most heavily (0.50) because
    it captures the routine disruption most directly.
    A user who buys ready-to-cook chicken will not accept dried
    chickpeas regardless of how similar the time or complexity scores.

    Returns float 0.0–1.0, or 0.5 if all fields missing.
    """
    scores = []
    weights = []

    # Prep type match — highest weight
    orig_prep = original.get('prep_type')
    sub_prep = substitute.get('prep_type')
    if orig_prep and sub_prep:
        match = orig_prep.lower().strip() == sub_prep.lower().strip()
        scores.append(1.0 if match else 0.2)
        weights.append(0.50)

    # Prep time ratio
    orig_time = original.get('prep_time_minutes')
    sub_time = substitute.get('prep_time_minutes')
    if orig_time is not None and sub_time is not None:
        try:
            orig_time = float(orig_time)
            sub_time = float(sub_time)
            if orig_time > 0:
                ratio = sub_time / orig_time
                if ratio <= 1.5:
                    time_score = 1.0
                elif ratio <= MAX_PREP_TIME_RATIO:
                    # Linear decay up to 3x time
                    time_score = 1.0 - ((ratio - 1.5) / (MAX_PREP_TIME_RATIO - 1.5)) * 0.6
                else:
                    # More than 3x longer — routine is disrupted
                    time_score = 0.1
                scores.append(time_score)
                weights.append(0.30)
        except (ValueError, TypeError):
            pass

    # Prep complexity proximity
    orig_complexity = original.get('prep_complexity')
    sub_complexity = substitute.get('prep_complexity')
    if orig_complexity is not None and sub_complexity is not None:
        try:
            gap = abs(int(orig_complexity) - int(sub_complexity))
            complexity_score = max(0.0, 1.0 - (gap * 0.25))
            scores.append(complexity_score)
            weights.append(0.20)
        except (ValueError, TypeError):
            pass

    # Missing data — return neutral
    if not scores:
        return 0.5

    # Weighted average of available sub-signals
    total_weight = sum(weights)
    if total_weight > 0:
        weighted_score = sum(s * w for s, w in zip(scores, weights))
        return round(weighted_score / total_weight, 4)

    return round(sum(scores) / len(scores), 4)


# ─────────────────────────────────────────────────────────────────
# MAIN REALISM SCORER
# ─────────────────────────────────────────────────────────────────

def score_realism(original: Dict, substitute: Dict) -> Dict:
    """
    Compute overall behavioural realism score for a substitution pair.

    Combines role match, taste similarity, and effort similarity into
    a single realism score. Returns full breakdown for transparency.

    Parameters:
    -----------
    original   : food item dict for the food being replaced
    substitute : food item dict for the proposed replacement

    Returns:
    --------
    {
        'realism_score': float,        # overall score 0.0–1.0
        'role_score': float,           # role match component
        'taste_score': float,          # taste similarity component
        'effort_score': float,         # effort similarity component
        'passes_threshold': bool,      # True if realism_score >= REALISM_THRESHOLD
        'data_completeness': str,      # 'full' | 'partial' | 'none'
    }
    """

    role_score = score_role_match(original, substitute)
    taste_score = score_taste_similarity(original, substitute)
    effort_score = score_effort_similarity(original, substitute)

    # Combined realism score
    realism_score = round(
        (role_score * ROLE_WEIGHT) +
        (taste_score * TASTE_WEIGHT) +
        (effort_score * EFFORT_WEIGHT),
        4
    )

    # Assess data completeness for transparency
    behavioural_fields = [
        'taste_profile', 'texture_profile', 'flavour_intensity',
        'prep_type', 'prep_time_minutes', 'prep_complexity', 'meal_context'
    ]
    orig_fields = sum(1 for f in behavioural_fields if original.get(f) is not None)
    sub_fields = sum(1 for f in behavioural_fields if substitute.get(f) is not None)
    avg_completeness = (orig_fields + sub_fields) / (2 * len(behavioural_fields))

    if avg_completeness >= 0.85:
        completeness = 'full'
    elif avg_completeness >= 0.40:
        completeness = 'partial'
    else:
        completeness = 'none'

    return {
        'realism_score': realism_score,
        'role_score': role_score,
        'taste_score': taste_score,
        'effort_score': effort_score,
        'passes_threshold': realism_score >= REALISM_THRESHOLD,
        'data_completeness': completeness,
    }


# ─────────────────────────────────────────────────────────────────
# FILTER INTERFACE
# ─────────────────────────────────────────────────────────────────

def filter_by_realism(
    candidates: list,
    food_lookup: Dict,
    threshold: Optional[float] = None
) -> list:
    """
    Filter substitution candidates by behavioural realism.

    Sits between raw substitution candidates and the Pareto engine.
    Adds realism scores to each candidate and removes those below
    the threshold.

    Parameters:
    -----------
    candidates  : list of substitution candidate dicts
                  Each must contain original_id and substitute_id
    food_lookup : dict mapping food_id → full food item dict
                  Used to retrieve behavioural fields for scoring
    threshold   : override default REALISM_THRESHOLD if needed

    Returns:
    --------
    List of candidates that passed the realism filter,
    each with realism breakdown fields added.
    """
    active_threshold = threshold if threshold is not None else REALISM_THRESHOLD

    passed = []
    filtered = []

    for candidate in candidates:
        orig_id = candidate.get('original_id')
        sub_id = candidate.get('substitute_id')

        original = food_lookup.get(orig_id, {})
        substitute = food_lookup.get(sub_id, {})

        realism = score_realism(original, substitute)

        enriched = candidate.copy()
        enriched['realism_score'] = realism['realism_score']
        enriched['realism_role_score'] = realism['role_score']
        enriched['realism_taste_score'] = realism['taste_score']
        enriched['realism_effort_score'] = realism['effort_score']
        enriched['realism_data_completeness'] = realism['data_completeness']

        if realism['passes_threshold']:
            passed.append(enriched)
        else:
            filtered.append(enriched)

    return passed


# ─────────────────────────────────────────────────────────────────
# Quick test when run directly
# ─────────────────────────────────────────────────────────────────

if __name__ == "__main__":

    # Simulated food lookup with full behavioural fields
    food_lookup = {
        'P01': {
            'food_id': 'P01',
            'name': 'Chicken breast',
            'role': 'protein',
            'taste_profile': 'savoury',
            'texture_profile': 'firm',
            'flavour_intensity': 2,
            'prep_type': 'raw',
            'prep_time_minutes': 20,
            'prep_complexity': 2,
            'meal_context': 'main protein',
        },
        'P02': {
            'food_id': 'P02',
            'name': 'Chicken thigh',
            'role': 'protein',
            'taste_profile': 'savoury',
            'texture_profile': 'firm',
            'flavour_intensity': 3,
            'prep_type': 'raw',
            'prep_time_minutes': 25,
            'prep_complexity': 2,
            'meal_context': 'main protein',
        },
        'P22': {
            'food_id': 'P22',
            'name': 'Tinned sardines',
            'role': 'protein',
            'taste_profile': 'fishy',
            'texture_profile': 'flaky',
            'flavour_intensity': 4,
            'prep_type': 'tinned',
            'prep_time_minutes': 2,
            'prep_complexity': 1,
            'meal_context': 'main protein',
        },
        'S01': {
            'food_id': 'S01',
            'name': 'White rice',
            'role': 'carb',
            'taste_profile': 'mild',
            'texture_profile': 'soft',
            'flavour_intensity': 1,
            'prep_type': 'dried',
            'prep_time_minutes': 20,
            'prep_complexity': 1,
            'meal_context': 'side dish',
        },
        'S05': {
            'food_id': 'S05',
            'name': 'Barley',
            'role': 'carb',
            'taste_profile': 'earthy',
            'texture_profile': 'chewy',
            'flavour_intensity': 2,
            'prep_type': 'dried',
            'prep_time_minutes': 45,
            'prep_complexity': 2,
            'meal_context': 'soup base',
        },
    }

    # Test candidates
    candidates = [
        {
            'original_id': 'P01',
            'substitute_id': 'P02',
            'substitute_name': 'Chicken thigh',
            'cost_delta': 15.0,
            'nutrition_delta': 5.0,
            'env_delta': 8.0,
        },
        {
            'original_id': 'P01',
            'substitute_id': 'P22',
            'substitute_name': 'Tinned sardines',
            'cost_delta': 20.0,
            'nutrition_delta': 18.0,
            'env_delta': 25.0,
        },
        {
            'original_id': 'S01',
            'substitute_id': 'S05',
            'substitute_name': 'Barley',
            'cost_delta': 5.0,
            'nutrition_delta': 8.0,
            'env_delta': 6.0,
        },
    ]

    print("Running Behavioural Realism Filter...\n")
    print(f"Threshold: {REALISM_THRESHOLD}\n")

    passed = filter_by_realism(candidates, food_lookup)

    print(f"Candidates evaluated: {len(candidates)}")
    print(f"Passed filter:        {len(passed)}")
    print(f"Filtered out:         {len(candidates) - len(passed)}\n")

    # Show all scores including filtered
    for candidate in candidates:
        orig = food_lookup.get(candidate['original_id'], {})
        sub = food_lookup.get(candidate['substitute_id'], {})
        result = score_realism(orig, sub)

        status = "✅ PASS" if result['passes_threshold'] else "❌ FAIL"
        print(f"{status}  {orig.get('name', '?')} → {sub.get('name', '?')}")
        print(f"       Realism:  {result['realism_score']:.3f}")
        print(f"       Role:     {result['role_score']:.3f}")
        print(f"       Taste:    {result['taste_score']:.3f}")
        print(f"       Effort:   {result['effort_score']:.3f}")
        print(f"       Data:     {result['data_completeness']}")
        print()
        