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

  ApiOptimisationResult({
    required this.optimisedBasket,
    required this.substitutions,
    required this.comparison,
    required this.insights,
    this.supplyPressure,
  });
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
  });

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
          .timeout(const Duration(seconds: 5));
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
        .timeout(const Duration(seconds: 10));

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
        .timeout(const Duration(seconds: 10));

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
        .timeout(const Duration(seconds: 10));

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
        .timeout(const Duration(seconds: 15));

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

    return ApiOptimisationResult(
      optimisedBasket: optimisedBasket,
      substitutions: substitutions,
      comparison: comparison,
      insights: insights,
      supplyPressure: supplyPressure,
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
        .timeout(const Duration(seconds: 10));

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
        .timeout(const Duration(seconds: 5))
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

  static List<String> _generateInsights(
    ApiBasketComparison comparison,
    List<ApiSubstitution> substitutions,
  ) {
    final insights = <String>[];

    if (comparison.envReduction > 0) {
      insights.add(
        '🌱 Environmental impact reduced by ${comparison.envReduction.toStringAsFixed(0)} pts — '
        'equivalent to meaningful CO₂ savings over a year',
      );
    }
    if (comparison.costReduction > 0) {
      insights.add(
        '💰 Cost score improved by ${comparison.costReduction.toStringAsFixed(0)} pts — '
        'your basket is now cheaper across Tesco, ASDA and Aldi',
      );
    }
    if (comparison.nutritionGain > 0) {
      insights.add(
        '💪 Nutrition score up ${comparison.nutritionGain.toStringAsFixed(0)} pts — '
        'better protein and fibre balance',
      );
    }
    if (substitutions.isEmpty) {
      insights.add(
        '✅ Your basket is already well-optimised! Consider adding more seasonal produce.',
      );
    }

    return insights;
  }
}
