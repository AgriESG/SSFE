import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/food_item.dart';
import '../models/user_preferences.dart';

// ---------------------------------------------------------------------------
// Configuration
// Change baseUrl to your deployed backend URL for production.
// ---------------------------------------------------------------------------

class ApiConfig {
  static const String baseUrl = 'https://agriesg-api.onrender.com';

  // For Android emulator talking to host machine:
  // static const String baseUrl = 'http://10.0.2.2:8000';

  // For physical device on same Wi-Fi:
  // static const String baseUrl = 'http://192.168.x.x:8000';

  // -------------------------------------------------------------------------
  // Timeouts
  //
  // The API is hosted on a tier that spins down after a period of inactivity
  // and takes roughly 30-50 seconds to wake. A 10-second timeout gives up
  // before the server can possibly answer, so the first request after an idle
  // period always failed and the user saw an error for something that was
  // about to work.
  //
  // coldStart is used for the two calls that are likely to be first in a
  // session. The rest use standard, since by the time they run the service is
  // already awake.
  // -------------------------------------------------------------------------
  static const Duration coldStart = Duration(seconds: 60);
  static const Duration standard = Duration(seconds: 30);
  static const Duration probe = Duration(seconds: 5);
  static const Duration telemetry = Duration(seconds: 5);
}

// ---------------------------------------------------------------------------
// Exceptions
// ---------------------------------------------------------------------------

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}

// ---------------------------------------------------------------------------
// API Response Models
// ---------------------------------------------------------------------------

class ApiOptimisationResult {
  final List<FoodItem> optimisedBasket;
  final List<ApiSubstitution> substitutions;
  final ApiBasketComparison comparison;
  final List<String> insights;
  final ApiSupplyPressure? supplyPressure;

  /// How many of the returned swaps carry a supply clause in their rationale.
  /// Served by the API rather than inferred, so the influence of the Supply
  /// Pressure Index on this basket is directly countable.
  final int supplyInfluencedCount;

  /// Feed cost pressure by category. Only categories with a completed
  /// backtest appear; everything else is absent rather than defaulted.
  final Map<String, ApiFeedCostPressure> feedCostPressure;

  /// Which UK crops the basket rests on. Null when the API did not return it.
  final ApiCropProvenance? cropProvenance;

  ApiOptimisationResult({
    required this.optimisedBasket,
    required this.substitutions,
    required this.comparison,
    required this.insights,
    this.supplyPressure,
    this.supplyInfluencedCount = 0,
    this.feedCostPressure = const {},
    this.cropProvenance,
  });
}

/// Feed cost pressure for one category. Validated for pork only — see
/// data/validation/feed_lead_lag.md. The API omits untested categories, so
/// the absence of a key here means "not measured", not "no pressure".
class ApiFeedCostPressure {
  final String category;
  final double pressure;
  final double stability;
  final double pctChange13w;
  final List<int> leadHorizonWeeks;
  final String asOf;

  ApiFeedCostPressure({
    required this.category,
    required this.pressure,
    required this.stability,
    required this.pctChange13w,
    required this.leadHorizonWeeks,
    required this.asOf,
  });

  factory ApiFeedCostPressure.fromJson(Map<String, dynamic> j) =>
      ApiFeedCostPressure(
        category: (j['category'] ?? '').toString(),
        pressure: (j['pressure'] ?? 0).toDouble(),
        stability: (j['stability'] ?? 0).toDouble(),
        pctChange13w: (j['pct_change_13w'] ?? 0).toDouble(),
        leadHorizonWeeks: (j['lead_horizon_weeks'] as List? ?? [])
            .map((v) => (v ?? 0) as int)
            .toList(),
        asOf: (j['as_of'] ?? '').toString(),
      );
}

/// Which UK crops the basket rests on, direct and through animal feed.
///
/// Replaces an earlier "exposure" model that ranked the user's categories by
/// pressure. That produced circular statements — "bread is the tightest
/// category, and your bread depends on it" — and manufactured significance out
/// of readings that were all comfortable.
///
/// Provenance runs the other way and is interesting on an ordinary season:
/// poultry rations are roughly 60% wheat, beef roughly 30% barley, so a
/// chicken is in supply terms largely a wheat product. Almost no shopper
/// knows that.
///
/// Contains no forecast. Nothing links cereal stock levels to shelf prices.
class ApiCropGrain {
  final String grain;
  final double? pressure;
  final String state;
  final int? seasons;
  final String? vintage;
  final List<String> directFoods;
  final List<String> feedFoods;

  ApiCropGrain({
    required this.grain,
    this.pressure,
    this.state = '',
    this.seasons,
    this.vintage,
    this.directFoods = const [],
    this.feedFoods = const [],
  });

  bool get hasData => pressure != null;

  factory ApiCropGrain.fromJson(Map<String, dynamic> j) => ApiCropGrain(
        grain: (j['grain'] ?? '').toString(),
        pressure: (j['pressure'] as num?)?.toDouble(),
        state: (j['state'] ?? '').toString(),
        seasons: (j['seasons'] as num?)?.toInt(),
        vintage: j['vintage'] as String?,
        directFoods: (j['direct_foods'] as List? ?? [])
            .map((e) => e.toString())
            .toList(),
        feedFoods: (j['feed_foods'] as List? ?? [])
            .map((e) => e.toString())
            .toList(),
      );
}

class ApiCropProvenance {
  final List<ApiCropGrain> grains;
  final bool anyTight;
  final int basketItemsTraced;
  final int basketItemsTotal;

  ApiCropProvenance({
    this.grains = const [],
    this.anyTight = false,
    this.basketItemsTraced = 0,
    this.basketItemsTotal = 0,
  });

  bool get hasAnything => grains.isNotEmpty;

  factory ApiCropProvenance.fromJson(Map<String, dynamic> j) =>
      ApiCropProvenance(
        grains: (j['grains'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ApiCropGrain.fromJson)
            .toList(),
        anyTight: j['any_tight'] ?? false,
        basketItemsTraced: (j['basket_items_traced'] ?? 0) as int,
        basketItemsTotal: (j['basket_items_total'] ?? 0) as int,
      );
}

class ApiSupplyPressure {
  final Map<String, double> grainPressure;
  final Map<String, double> foodCategoryPressure;
  final String dataVintage;

  ApiSupplyPressure({
    required this.grainPressure,
    required this.foodCategoryPressure,
    this.dataVintage = '',
  });

  factory ApiSupplyPressure.fromJson(Map<String, dynamic> j) => ApiSupplyPressure(
        grainPressure: (j['grain_pressure'] as Map? ?? {}).map(
          (k, v) => MapEntry(k.toString(), (v ?? 0).toDouble()),
        ),
        foodCategoryPressure: (j['food_category_pressure'] as Map? ?? {}).map(
          (k, v) => MapEntry(k.toString(), (v ?? 0).toDouble()),
        ),
        dataVintage: (j['data_vintage'] ?? '').toString(),
      );
}

class ApiSubstitution {
  final String originalId;
  final String originalName;
  final String substituteId;
  final String substituteName;
  final String role;
  final double improvementScore;
  final double envDelta;
  final double costDelta;
  final double nutritionDelta;
  final String rationale;
  final double supplyStability;
  final double realismScore;
  final int paretoRank;
  final int paretoFrontSize;
  final Map<String, double> weightsApplied;
  final bool humanFlaggedLowRealism;

  /// True when supply pressure actually contributed a clause to the rationale.
  /// Lets the UI badge only the swaps where supply genuinely mattered, rather
  /// than implying it influenced every recommendation.
  final bool supplyInfluencedRationale;

  /// Supply categories on each side, so a reader can trace the rationale's
  /// supply clause back to the /supply-pressure endpoint.
  final String originalSupplyCategory;
  final String substituteSupplyCategory;

  /// Real physical deltas, per kilogram of product.
  ///
  /// envDelta and costDelta above are 0-100 normalised scores — the currency
  /// the optimiser ranks on, not quantities. Rendering them with "kg CO2" and
  /// "£" labels was stating a unit the number did not have. These two are the
  /// figures a person can act on, and are null where the source data is
  /// missing so the UI shows nothing rather than a fabricated zero.
  final double? carbonDeltaKgPerKg;
  final double? costDeltaGbpPerKg;

  ApiSubstitution({
    required this.originalId,
    required this.originalName,
    required this.substituteId,
    required this.substituteName,
    required this.role,
    required this.improvementScore,
    required this.envDelta,
    required this.costDelta,
    required this.nutritionDelta,
    required this.rationale,
    required this.supplyStability,
    required this.realismScore,
    required this.paretoRank,
    required this.paretoFrontSize,
    required this.weightsApplied,
    required this.humanFlaggedLowRealism,
    this.supplyInfluencedRationale = false,
    this.originalSupplyCategory = '',
    this.substituteSupplyCategory = '',
    this.carbonDeltaKgPerKg,
    this.costDeltaGbpPerKg,
  });

  /// The pipeline returns exactly 0.5 for foods with no published supply
  /// series. That is absent data, not a mid-range reading, so the UI must not
  /// render it as a measurement.
  bool get hasSupplyData => (supplyStability - 0.5).abs() > 0.001;

  factory ApiSubstitution.fromJson(Map<String, dynamic> j) => ApiSubstitution(
        originalId: j['original_id'] ?? '',
        originalName: j['original_name'] ?? '',
        substituteId: j['substitute_id'] ?? '',
        substituteName: j['substitute_name'] ?? '',
        role: j['role'] ?? '',
        improvementScore: (j['improvement_score'] ?? 0).toDouble(),
        envDelta: (j['env_delta'] ?? 0).toDouble(),
        costDelta: (j['cost_delta'] ?? 0).toDouble(),
        nutritionDelta: (j['nutrition_delta'] ?? 0).toDouble(),
        rationale: j['rationale'] ?? '',
        supplyStability: (j['supply_stability'] ?? 0).toDouble(),
        realismScore: (j['realism_score'] ?? 0).toDouble(),
        paretoRank: j['pareto_rank'] ?? 0,
        paretoFrontSize: j['pareto_front_size'] ?? 0,
        weightsApplied: (j['weights_applied'] as Map? ?? {}).map(
          (k, v) => MapEntry(k.toString(), (v ?? 0).toDouble()),
        ),
        humanFlaggedLowRealism: j['human_flagged_low_realism'] ?? false,
        supplyInfluencedRationale: j['supply_influenced_rationale'] ?? false,
        originalSupplyCategory: (j['original_supply_category'] ?? '').toString(),
        substituteSupplyCategory:
            (j['substitute_supply_category'] ?? '').toString(),
        carbonDeltaKgPerKg: (j['carbon_delta_kg_per_kg'] as num?)?.toDouble(),
        costDeltaGbpPerKg: (j['cost_delta_gbp_per_kg'] as num?)?.toDouble(),
      );
}

class ApiBasketSummary {
  final double basketScore;
  final double avgEnvScore;
  final double avgNutritionScore;
  final double avgCostScore;

  ApiBasketSummary({
    required this.basketScore,
    required this.avgEnvScore,
    required this.avgNutritionScore,
    required this.avgCostScore,
  });

  factory ApiBasketSummary.fromJson(Map<String, dynamic> j) => ApiBasketSummary(
        basketScore: (j['basket_score'] ?? 0).toDouble(),
        avgEnvScore: (j['avg_env_score'] ?? 0).toDouble(),
        avgNutritionScore: (j['avg_nutrition_score'] ?? 0).toDouble(),
        avgCostScore: (j['avg_cost_score'] ?? 0).toDouble(),
      );
}

class ApiBasketComparison {
  final ApiBasketSummary before;
  final ApiBasketSummary after;
  final double basketScoreGain;
  final double envReduction;
  final double nutritionGain;
  final double costReduction;

  ApiBasketComparison({
    required this.before,
    required this.after,
    required this.basketScoreGain,
    required this.envReduction,
    required this.nutritionGain,
    required this.costReduction,
  });

  // Convenience getters to match existing UI usage
  double get carbonChange => before.avgEnvScore > 0
      ? ((before.avgEnvScore - after.avgEnvScore) / before.avgEnvScore * 100)
      : 0;
  double get costSaved => costReduction;
  double get nutritionImprovement => nutritionGain;
}

// ---------------------------------------------------------------------------
// API Service
// ---------------------------------------------------------------------------

class ApiService {
  static final _client = http.Client();

  /// Score movements smaller than this are rounding, not movement. Used to
  /// stop insights being generated for changes that round to zero, which
  /// previously produced lines like "Nutrition score up 0 pts".
  static const double _noiseBand = 0.5;

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  // -------------------------------------------------------------------------
  // Health check — use at startup to verify backend is reachable
  // -------------------------------------------------------------------------

  static Future<bool> isReachable() async {
    try {
      final res = await _client
          .get(Uri.parse('${ApiConfig.baseUrl}/health'))
          .timeout(ApiConfig.probe);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // List all foods
  // -------------------------------------------------------------------------

  static Future<List<FoodItem>> getAllFoods() async {
    final res = await _client
        .get(Uri.parse('${ApiConfig.baseUrl}/foods'), headers: _headers)
        .timeout(ApiConfig.coldStart);

    _checkStatus(res);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final List foods = data['foods'] ?? [];
    return foods.map((f) => FoodItem.fromApiJson(f as Map<String, dynamic>)).toList();
  }

  // -------------------------------------------------------------------------
  // Search foods by name
  // -------------------------------------------------------------------------

  static Future<List<FoodItem>> searchFoods(String query) async {
    final res = await _client
        .post(
          Uri.parse('${ApiConfig.baseUrl}/search-foods'),
          headers: _headers,
          body: jsonEncode({'query': query}),
        )
        .timeout(ApiConfig.standard);

    _checkStatus(res);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final List results = data['results'] ?? [];
    return results.map((f) => FoodItem.fromApiJson(f as Map<String, dynamic>)).toList();
  }

  // -------------------------------------------------------------------------
  // Get single food details + scores
  // -------------------------------------------------------------------------

  static Future<FoodItem> getFood(String foodId) async {
    final res = await _client
        .get(
          Uri.parse('${ApiConfig.baseUrl}/foods/$foodId'),
          headers: _headers,
        )
        .timeout(ApiConfig.standard);

    _checkStatus(res);
    return FoodItem.fromApiDetailJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  // -------------------------------------------------------------------------
  // Optimise basket — core endpoint
  // -------------------------------------------------------------------------

  static Future<ApiOptimisationResult> optimiseBasket(
    List<FoodItem> basket,
    UserPreferences preferences,
  ) async {
    final foodIds = basket.map((f) => f.id).toList();

    final res = await _client
        .post(
          Uri.parse('${ApiConfig.baseUrl}/optimise-basket'),
          headers: _headers,
          body: jsonEncode({
            'basket': foodIds,
            'user_preferences': _preferencesToJson(preferences),
          }),
        )
        .timeout(ApiConfig.coldStart);

    _checkStatus(res);
    final data = jsonDecode(res.body) as Map<String, dynamic>;

    final substitutions = (data['substitutions'] as List? ?? [])
        .map((s) => ApiSubstitution.fromJson(s as Map<String, dynamic>))
        .toList();

    final before = ApiBasketSummary.fromJson(
      data['before'] as Map<String, dynamic>? ?? {},
    );
    final after = ApiBasketSummary.fromJson(
      data['after'] as Map<String, dynamic>? ?? {},
    );
    final improvement = data['improvement'] as Map<String, dynamic>? ?? {};

    final comparison = ApiBasketComparison(
      before: before,
      after: after,
      basketScoreGain: (improvement['basket_score_gain'] ?? 0).toDouble(),
      envReduction: (improvement['env_reduction'] ?? 0).toDouble(),
      nutritionGain: (improvement['nutrition_gain'] ?? 0).toDouble(),
      costReduction: (improvement['cost_reduction'] ?? 0).toDouble(),
    );

    // Build optimised basket: apply substitutions, keep originals otherwise
    final Map<String, String> subMap = {
      for (final s in substitutions) s.originalId: s.substituteId,
    };

    final optimisedBasket = await Future.wait(
      basket.map((item) async {
        final subId = subMap[item.id];
        if (subId != null) {
          try {
            final sub = await getFood(subId);
            return sub.copyWith(quantity: item.quantity);
          } catch (_) {
            return item;
          }
        }
        return item;
      }),
    );

    final insights = _generateInsights(comparison, substitutions);

    final supplyPressure = data['supply_pressure_index'] != null
        ? ApiSupplyPressure.fromJson(data['supply_pressure_index'] as Map<String, dynamic>)
        : null;

    // Null entries are expected: the API returns null for any category
    // without a completed backtest rather than inventing a default.
    final feedRaw = data['feed_cost_pressure'] as Map<String, dynamic>? ?? {};
    final feedCostPressure = <String, ApiFeedCostPressure>{};
    feedRaw.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        feedCostPressure[key] = ApiFeedCostPressure.fromJson(value);
      }
    });

    return ApiOptimisationResult(
      optimisedBasket: optimisedBasket,
      substitutions: substitutions,
      comparison: comparison,
      insights: insights,
      supplyPressure: supplyPressure,
      supplyInfluencedCount: (data['supply_influenced_count'] ?? 0) as int,
      feedCostPressure: feedCostPressure,
      cropProvenance: data['crop_provenance'] is Map<String, dynamic>
          ? ApiCropProvenance.fromJson(
              data['crop_provenance'] as Map<String, dynamic>)
          : null,
    );
  }

  // -------------------------------------------------------------------------
  // Calculate basket impact (no substitutions)
  // -------------------------------------------------------------------------

  static Future<Map<String, dynamic>> calculateImpact(
    List<FoodItem> basket,
  ) async {
    final res = await _client
        .post(
          Uri.parse('${ApiConfig.baseUrl}/calculate-impact'),
          headers: _headers,
          body: jsonEncode({'basket': basket.map((f) => f.id).toList()}),
        )
        .timeout(ApiConfig.coldStart);

    _checkStatus(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // -------------------------------------------------------------------------
  // Swap feedback telemetry
  //
  // Records whether a suggested substitution was accepted or dismissed.
  // Deliberately fire and forget: returns void so it can never be awaited
  // by mistake, skips _checkStatus so a telemetry failure never surfaces
  // to the user, and swallows network errors so an offline device does
  // not throw an unhandled async error mid-swap.
  //
  // Note the field names: the model is camelCase, the API expects
  // snake_case, so the mapping happens here.
  // -------------------------------------------------------------------------

  static void sendSwapFeedback(
    ApiSubstitution substitution, {
    required bool accepted,
  }) {
    _client
        .post(
          Uri.parse('${ApiConfig.baseUrl}/swap-feedback'),
          headers: _headers,
          body: jsonEncode({
            'original_id': substitution.originalId,
            'substitute_id': substitution.substituteId,
            'accepted': accepted,
          }),
        )
        .timeout(ApiConfig.telemetry)
        .catchError((_) => http.Response('', 599));
  }

  // -------------------------------------------------------------------------
  // Internal helpers
  // -------------------------------------------------------------------------

  static void _checkStatus(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String message = 'Request failed';
      try {
        final body = jsonDecode(res.body);
        message = body['detail'] ?? message;
      } catch (_) {}
      throw ApiException(message, statusCode: res.statusCode);
    }
  }

  static Map<String, dynamic> _preferencesToJson(UserPreferences prefs) => {
        'diet_type': prefs.dietType.name,
        'sustainability_priority': prefs.sustainabilityPriority.name,
        'budget_preference': prefs.budgetPreference.name,
        'nutrition_goal': prefs.nutritionGoal.name,
        'allergies': prefs.allergies,
        'dislikes': prefs.dislikes,
      };

  // -------------------------------------------------------------------------
  // Insights
  //
  // Each line requires the underlying score to have actually moved past
  // _noiseBand. The previous version fired on any value above zero, so a
  // change of 0.1 produced "Nutrition score up 0 pts", which asserts a benefit
  // the number does not support.
  //
  // Regressions get a line too. A basket that came out pricier should say so
  // rather than staying silent and letting the reader assume everything
  // improved.
  // -------------------------------------------------------------------------

  static List<String> _generateInsights(
    ApiBasketComparison comparison,
    List<ApiSubstitution> substitutions,
  ) {
    final insights = <String>[];

    if (comparison.envReduction >= _noiseBand) {
      insights.add(
        '🌱 Environmental impact reduced by '
        '${comparison.envReduction.toStringAsFixed(0)} pts',
      );
    } else if (comparison.envReduction <= -_noiseBand) {
      insights.add(
        '🌍 Environmental impact rose by '
        '${comparison.envReduction.abs().toStringAsFixed(0)} pts with these swaps',
      );
    }

    if (comparison.costReduction >= _noiseBand) {
      insights.add(
        '💰 Cost score improved by '
        '${comparison.costReduction.toStringAsFixed(0)} pts',
      );
    } else if (comparison.costReduction <= -_noiseBand) {
      insights.add(
        '💷 Cost score rose by '
        '${comparison.costReduction.abs().toStringAsFixed(0)} pts — '
        'this basket is pricier',
      );
    }

    if (comparison.nutritionGain >= _noiseBand) {
      insights.add(
        '💪 Nutrition score up '
        '${comparison.nutritionGain.toStringAsFixed(0)} pts — '
        'better protein and fibre balance',
      );
    } else if (comparison.nutritionGain <= -_noiseBand) {
      insights.add(
        '🥄 Nutrition score down '
        '${comparison.nutritionGain.abs().toStringAsFixed(0)} pts',
      );
    }

    // Supply is the distinguishing dimension, so say when it actually shaped
    // a recommendation — and stay quiet when it did not.
    final supplyDriven =
        substitutions.where((s) => s.supplyInfluencedRationale).length;
    if (supplyDriven > 0) {
      insights.add(
        '🌾 UK supply conditions shaped $supplyDriven of your '
        '${substitutions.length} ${substitutions.length == 1 ? "swap" : "swaps"}',
      );
    }

    if (substitutions.isEmpty) {
      insights.add(
        '✅ No swaps improved on your basket across all four objectives.',
      );
    }

    return insights;
  }
}
