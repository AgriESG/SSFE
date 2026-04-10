"""
Pareto Optimisation Engine — AgriESG Food Twin Engine
======================================================
Author: Esther Oluwasolayimika Olusola

PURPOSE:
--------
This module implements a two-stage substitution selection process for the
Food Twin optimisation engine:

  Stage 1 — Pareto Dominance Filter
  Eliminates substitution candidates that are objectively inferior — i.e.
  dominated by at least one other candidate across all four objectives
  simultaneously. This step is preference-free and mathematically objective.

  Stage 2 — Preference-Weighted Ranking
  Orders the Pareto-efficient frontier using a personalised scoring function
  derived from user preferences collected during onboarding (budget sensitivity,
  sustainability priority, nutrition goal, supply stability concern).

WHY TWO STAGES MATTER:
----------------------
Single-objective weighted scoring collapses all dimensions into one number
before comparison, permanently discarding tradeoff information. This means
the ranking is entirely determined by the weight vector chosen — not by
the actual tradeoffs available.

Two-stage Pareto optimisation preserves tradeoff information through the
filtering stage and only applies user preferences at the ranking stage,
where preferences legitimately belong. This produces recommendations that
are both objectively non-dominated and individually relevant.

FOUR OPTIMISATION OBJECTIVES:
------------------------------
1. cost_delta        — cost improvement (higher = cheaper substitution)
2. nutrition_delta   — nutrition improvement (higher = healthier)
3. env_delta         — environmental improvement (higher = more sustainable)
4. supply_stability  — supply pressure reduction (higher = more stable supply)
                       Derived from Supply Pressure Index (supply_pressure.py)

The supply_stability dimension is novel — no existing consumer food
optimisation system incorporates agricultural supply chain intelligence
as an optimisation objective.
"""

import numpy as np
from typing import List, Dict, Any, Optional


# ─────────────────────────────────────────────────────────────────
# User preference → objective weight mapping
#
# User preferences from onboarding are ordinal categories.
# These are mapped to numeric weights used in Stage 2 ranking.
#
# Design decision: weights are normalised to sum to 1.0 within
# each preference vector to ensure comparability across users
# with different preference intensities.
# ─────────────────────────────────────────────────────────────────

BUDGET_WEIGHTS = {
    'low':    0.40,   # cost-sensitive user — cost weighted heavily
    'medium': 0.25,
    'high':   0.10,   # cost-insensitive user — cost weighted lightly
}

SUSTAINABILITY_WEIGHTS = {
    'low':    0.10,
    'medium': 0.25,
    'high':   0.40,   # sustainability-priority user
}

NUTRITION_WEIGHTS = {
    'balanced':      0.20,
    'high_protein':  0.30,
    'weight_loss':   0.25,
    'muscle_gain':   0.30,
}

# Supply stability weight is fixed — it is not a user preference
# but an objective agricultural signal applied uniformly
# Design decision: fixed at 0.15 to ensure it influences but does
# not dominate recommendations when user has strong budget or
# sustainability preferences
SUPPLY_STABILITY_WEIGHT = 0.15


# ─────────────────────────────────────────────────────────────────
# STAGE 1: Pareto Dominance Filter
# ─────────────────────────────────────────────────────────────────

def dominates(candidate_a: Dict, candidate_b: Dict, objectives: List[str]) -> bool:
    """
    Returns True if candidate_a Pareto dominates candidate_b.

    A dominates B if and only if:
    - A is at least as good as B on ALL objectives, AND
    - A is strictly better than B on AT LEAST ONE objective

    Design decision: strict dominance only. If two candidates are
    equal on all objectives, neither dominates the other — both
    are retained on the Pareto frontier. This avoids arbitrary
    tie-breaking at the filtering stage.

    Parameters:
    -----------
    candidate_a : substitution candidate dict with objective scores
    candidate_b : substitution candidate dict with objective scores
    objectives  : list of objective keys to compare (all higher = better)
    """
    at_least_as_good = all(
        candidate_a.get(obj, 0) >= candidate_b.get(obj, 0)
        for obj in objectives
    )
    strictly_better = any(
        candidate_a.get(obj, 0) > candidate_b.get(obj, 0)
        for obj in objectives
    )
    return at_least_as_good and strictly_better


def pareto_filter(candidates: List[Dict], objectives: List[str]) -> List[Dict]:
    """
    Filter a list of substitution candidates to the Pareto-efficient frontier.

    Removes any candidate that is dominated by at least one other candidate.
    Returns only non-dominated candidates — the Pareto frontier.

    Time complexity: O(n²) over candidates × objectives.
    Acceptable for typical basket sizes (n < 50 substitutions per food item).

    Design decision: O(n²) chosen over more complex algorithms because
    basket sizes are small and simplicity aids auditability. For larger
    datasets, a divide-and-conquer approach would be appropriate.

    Parameters:
    -----------
    candidates : list of substitution candidate dicts
    objectives : list of objective keys (all assumed higher = better)

    Returns:
    --------
    List of non-dominated candidates (Pareto frontier)
    """
    if not candidates:
        return []

    pareto_front = []

    for i, candidate in enumerate(candidates):
        dominated = False

        for j, other in enumerate(candidates):
            if i == j:
                continue
            if dominates(other, candidate, objectives):
                dominated = True
                break

        if not dominated:
            pareto_front.append(candidate)

    return pareto_front


# ─────────────────────────────────────────────────────────────────
# STAGE 2: Preference-Weighted Ranking
# ─────────────────────────────────────────────────────────────────

def build_preference_weights(user_preferences: Dict) -> Dict[str, float]:
    """
    Convert user onboarding preferences into objective weight vector.

    Combines budget, sustainability, and nutrition preference weights
    with fixed supply stability weight. Normalises result to sum to 1.0.

    Design decision: normalisation ensures that users with strong
    preferences in one dimension do not produce weight vectors that
    dwarf the supply stability signal entirely. The supply stability
    weight is preserved as a meaningful contributor after normalisation.

    Parameters:
    -----------
    user_preferences : dict from onboarding with keys:
        - budget_preference: 'low' | 'medium' | 'high'
        - sustainability_priority: 'low' | 'medium' | 'high'
        - nutrition_goal: 'balanced' | 'high_protein' | 'weight_loss' | 'muscle_gain'

    Returns:
    --------
    Dict mapping objective name → normalised weight (sums to 1.0)
    """
    budget_pref = user_preferences.get('budget_preference', 'medium')
    sustain_pref = user_preferences.get('sustainability_priority', 'medium')
    nutrition_pref = user_preferences.get('nutrition_goal', 'balanced')

    raw_weights = {
        'cost_delta':       BUDGET_WEIGHTS.get(budget_pref, 0.25),
        'env_delta':        SUSTAINABILITY_WEIGHTS.get(sustain_pref, 0.25),
        'nutrition_delta':  NUTRITION_WEIGHTS.get(nutrition_pref, 0.20),
        'supply_stability': SUPPLY_STABILITY_WEIGHT,
    }

    # Normalise to sum to 1.0
    total = sum(raw_weights.values())
    if total > 0:
        return {k: round(v / total, 4) for k, v in raw_weights.items()}

    # Fallback: equal weights
    return {k: 0.25 for k in raw_weights}


def score_candidate(candidate: Dict, weights: Dict[str, float]) -> float:
    """
    Score a single Pareto-efficient candidate using preference weights.

    This is a standard weighted sum applied ONLY to non-dominated candidates.
    The key distinction from naive weighted scoring is that this function
    is only called after Pareto filtering — ensuring we never recommend
    an objectively dominated option regardless of user preferences.

    Parameters:
    -----------
    candidate : substitution candidate dict with objective scores
    weights   : normalised preference weight dict from build_preference_weights

    Returns:
    --------
    Float preference score (higher = better match to user preferences)
    """
    return sum(
        candidate.get(objective, 0) * weight
        for objective, weight in weights.items()
    )


def rank_pareto_front(
    pareto_front: List[Dict],
    user_preferences: Dict
) -> List[Dict]:
    """
    Rank Pareto-efficient candidates by user preference alignment.

    Adds 'preference_score' and 'rank' fields to each candidate.
    Returns candidates sorted by preference score descending.

    Parameters:
    -----------
    pareto_front      : non-dominated candidates from pareto_filter()
    user_preferences  : user onboarding preference dict

    Returns:
    --------
    Ranked list of candidates with preference_score and rank added
    """
    weights = build_preference_weights(user_preferences)

    scored = []
    for candidate in pareto_front:
        candidate = candidate.copy()
        candidate['preference_score'] = round(
            score_candidate(candidate, weights), 4
        )
        candidate['weights_applied'] = weights
        scored.append(candidate)

    # Sort by preference score descending
    scored.sort(key=lambda x: x['preference_score'], reverse=True)

    # Add rank
    for i, candidate in enumerate(scored):
        candidate['rank'] = i + 1

    return scored


# ─────────────────────────────────────────────────────────────────
# MAIN INTERFACE
# ─────────────────────────────────────────────────────────────────

def optimise_substitutions(
    candidates: List[Dict],
    user_preferences: Dict,
    supply_pressure: Optional[Dict] = None,
    top_n: int = 3
) -> Dict:
    """
    Main entry point for the Pareto optimisation engine.

    Takes raw substitution candidates, applies supply pressure scores,
    filters to Pareto frontier, ranks by user preferences, returns top N.

    Parameters:
    -----------
    candidates       : list of substitution candidates from food knowledge graph
                       Each must contain: cost_delta, nutrition_delta, env_delta,
                       original_id, substitute_id, substitute_name, role
    user_preferences : user onboarding preference dict
    supply_pressure  : output from get_supply_pressure_index() or None
                       If None, supply_stability defaults to 0.5 for all candidates
    top_n            : number of top recommendations to return (default 3)
                       Design decision: default 3 based on behaviour change research
                       showing users act on 1-3 clear recommendations, not 20

    Returns:
    --------
    {
        'pareto_front_size': int,        # how many non-dominated options existed
        'total_candidates': int,         # how many candidates were evaluated
        'recommendations': [...],        # top N ranked substitutions
        'objectives_used': [...],        # objective dimensions applied
        'weights_applied': {...}         # preference weights used for transparency
    }
    """

    OBJECTIVES = ['cost_delta', 'nutrition_delta', 'env_delta', 'supply_stability']

    if not candidates:
        return {
            'pareto_front_size': 0,
            'total_candidates': 0,
            'recommendations': [],
            'objectives_used': OBJECTIVES,
            'weights_applied': {}
        }

    # Attach supply stability scores to each candidate
    # Maps food category pressure to individual substitution candidates
    enriched = []
    for candidate in candidates:
        c = candidate.copy()

        if supply_pressure:
            # Use food category pressure as supply stability signal
            # Lower category pressure = more stable = higher stability score
            # Invert: high pressure = low stability
            food_cat = c.get('food_category', 'unknown')
            category_pressure = supply_pressure.get(
                'food_category_pressure', {}
            ).get(food_cat, 0.5)

            # Supply stability = 1 - pressure
            # Design decision: stability of the SUBSTITUTE food, not the original
            # We want to favour substitutes that are supply-stable
            c['supply_stability'] = round(1.0 - category_pressure, 4)
        else:
            # No supply data — neutral stability
            c['supply_stability'] = 0.5

        enriched.append(c)

    # Stage 1: Pareto filter
    pareto_front = pareto_filter(enriched, OBJECTIVES)

    # Stage 2: Rank by user preferences
    ranked = rank_pareto_front(pareto_front, user_preferences)

    # Return top N
    top_recommendations = ranked[:top_n]

    # Extract weights for transparency (same for all candidates)
    weights_applied = ranked[0]['weights_applied'] if ranked else {}

    return {
        'pareto_front_size': len(pareto_front),
        'total_candidates': len(candidates),
        'recommendations': top_recommendations,
        'objectives_used': OBJECTIVES,
        'weights_applied': weights_applied
    }


# ─────────────────────────────────────────────────────────────────
# Quick test when run directly
# ─────────────────────────────────────────────────────────────────

if __name__ == "__main__":

    # Simulated substitution candidates for chicken breast
    test_candidates = [
        {
            'original_id': 'P01',
            'original_name': 'Chicken breast',
            'substitute_id': 'P02',
            'substitute_name': 'Chicken thigh',
            'food_category': 'poultry',
            'role': 'protein',
            'cost_delta': 15.0,
            'nutrition_delta': 5.0,
            'env_delta': 8.0,
        },
        {
            'original_id': 'P01',
            'original_name': 'Chicken breast',
            'substitute_id': 'P15',
            'substitute_name': 'Turkey breast',
            'food_category': 'poultry',
            'role': 'protein',
            'cost_delta': 15.0,
            'nutrition_delta': 3.0,
            'env_delta': 8.0,
        },
        {
            'original_id': 'P01',
            'original_name': 'Chicken breast',
            'substitute_id': 'P22',
            'substitute_name': 'Tinned sardines',
            'food_category': 'pork',
            'role': 'protein',
            'cost_delta': 20.0,
            'nutrition_delta': 18.0,
            'env_delta': 25.0,
        },
        {
            'original_id': 'P01',
            'original_name': 'Chicken breast',
            'substitute_id': 'P08',
            'substitute_name': 'Pork loin',
            'food_category': 'pork',
            'role': 'protein',
            'cost_delta': 10.0,
            'nutrition_delta': 2.0,
            'env_delta': 4.0,
        },
    ]

    # Simulated user preferences
    test_preferences = {
        'budget_preference': 'low',
        'sustainability_priority': 'high',
        'nutrition_goal': 'balanced',
    }

    # Simulated supply pressure
    test_supply_pressure = {
        'food_category_pressure': {
            'poultry': 0.30,
            'pork': 0.25,
        }
    }

    print("Running Pareto Optimisation Engine...\n")
    result = optimise_substitutions(
        candidates=test_candidates,
        user_preferences=test_preferences,
        supply_pressure=test_supply_pressure,
        top_n=3
    )

    print(f"Total candidates evaluated: {result['total_candidates']}")
    print(f"Pareto-efficient options:   {result['pareto_front_size']}")
    print(f"Weights applied:            {result['weights_applied']}")
    print(f"\nTop {len(result['recommendations'])} recommendations:\n")

    for rec in result['recommendations']:
        print(f"  Rank {rec['rank']}: {rec['substitute_name']}")
        print(f"    Cost improvement:      {rec['cost_delta']}")
        print(f"    Nutrition improvement: {rec['nutrition_delta']}")
        print(f"    Env improvement:       {rec['env_delta']}")
        print(f"    Supply stability:      {rec['supply_stability']}")
        print(f"    Preference score:      {rec['preference_score']}")
        print()