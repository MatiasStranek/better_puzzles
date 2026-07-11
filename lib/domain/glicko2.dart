import 'dart:math' as math;

class Glicko2Rating {
  const Glicko2Rating({
    required this.rating,
    required this.deviation,
    required this.volatility,
    this.numberOfResults = 0,
    this.lastRatingAtMs = 0,
  });

  static const Glicko2Rating initial = Glicko2Rating(
    rating: 1500,
    deviation: 500,
    volatility: 0.09,
  );

  final double rating;
  final double deviation;
  final double volatility;
  final int numberOfResults;
  final int lastRatingAtMs;

  int get displayRating => rating.round().clamp(400, 4000).toInt();
  int get displayDeviation => deviation.round();
  bool get provisional => deviation >= 110;

  Glicko2Rating copyWith({
    double? rating,
    double? deviation,
    double? volatility,
    int? numberOfResults,
    int? lastRatingAtMs,
  }) {
    return Glicko2Rating(
      rating: rating ?? this.rating,
      deviation: deviation ?? this.deviation,
      volatility: volatility ?? this.volatility,
      numberOfResults: numberOfResults ?? this.numberOfResults,
      lastRatingAtMs: lastRatingAtMs ?? this.lastRatingAtMs,
    );
  }
}

class Glicko2Update {
  const Glicko2Update({required this.before, required this.after});

  final Glicko2Rating before;
  final Glicko2Rating after;

  int get ratingChange => after.displayRating - before.displayRating;
}

/// Glicko-2 single-result update using Lichess' current public defaults:
/// tau 0.75, min/max rating 400/4000, max RD 500 and 0.21436 periods/day.
class Glicko2Calculator {
  const Glicko2Calculator({
    this.tau = 0.75,
    this.ratingPeriodsPerDay = 0.21436,
  });

  static const double _scale = 173.7178;
  static const double _epsilon = 0.000001;

  final double tau;
  final double ratingPeriodsPerDay;

  Glicko2Update updateSingle({
    required Glicko2Rating player,
    required double opponentRating,
    required double opponentDeviation,
    required bool win,
    DateTime? now,
  }) {
    final timestamp = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch;
    final inflated = _inflateDeviation(player, timestamp);

    final mu = (inflated.rating - 1500) / _scale;
    final phi = inflated.deviation / _scale;
    final muJ = (opponentRating - 1500) / _scale;
    final phiJ = opponentDeviation.clamp(30.0, 500.0).toDouble() / _scale;

    final g = 1 / math.sqrt(1 + 3 * phiJ * phiJ / (math.pi * math.pi));
    final expected = 1 / (1 + math.exp(-g * (mu - muJ)));
    final variance = 1 / (g * g * expected * (1 - expected));
    final score = win ? 1.0 : 0.0;
    final delta = variance * g * (score - expected);
    final sigmaPrime = _newVolatility(
      phi: phi,
      sigma: inflated.volatility,
      variance: variance,
      delta: delta,
    );

    final phiStar = math.sqrt(phi * phi + sigmaPrime * sigmaPrime);
    final phiPrime = 1 / math.sqrt((1 / (phiStar * phiStar)) + (1 / variance));
    final muPrime = mu + phiPrime * phiPrime * g * (score - expected);

    final after = Glicko2Rating(
      rating: (1500 + _scale * muPrime).clamp(400.0, 4000.0).toDouble(),
      deviation: (_scale * phiPrime).clamp(45.0, 500.0).toDouble(),
      volatility: sigmaPrime.clamp(0.000001, 0.1).toDouble(),
      numberOfResults: player.numberOfResults + 1,
      lastRatingAtMs: timestamp,
    );

    return Glicko2Update(before: player, after: after);
  }

  Glicko2Rating _inflateDeviation(Glicko2Rating player, int nowMs) {
    if (player.lastRatingAtMs <= 0 || nowMs <= player.lastRatingAtMs) {
      return player;
    }

    final elapsedDays =
        (nowMs - player.lastRatingAtMs) / Duration.millisecondsPerDay;
    final periods = elapsedDays * ratingPeriodsPerDay;
    if (periods <= 0) {
      return player;
    }

    final phi = player.deviation / _scale;
    final inflatedPhi = math.sqrt(
      phi * phi + player.volatility * player.volatility * periods,
    );

    return player.copyWith(
      deviation: (_scale * inflatedPhi).clamp(45.0, 500.0).toDouble(),
    );
  }

  double _newVolatility({
    required double phi,
    required double sigma,
    required double variance,
    required double delta,
  }) {
    final a = math.log(sigma * sigma);

    double f(double x) {
      final expX = math.exp(x);
      final numerator = expX * (delta * delta - phi * phi - variance - expX);
      final denominator =
          2 * math.pow(phi * phi + variance + expX, 2).toDouble();
      return (numerator / denominator) - ((x - a) / (tau * tau));
    }

    var pointA = a;
    late double pointB;

    if (delta * delta > phi * phi + variance) {
      pointB = math.log(delta * delta - phi * phi - variance);
    } else {
      var k = 1;
      pointB = a - k * tau;
      while (f(pointB) < 0) {
        k++;
        pointB = a - k * tau;
      }
    }

    var valueA = f(pointA);
    var valueB = f(pointB);

    while ((pointB - pointA).abs() > _epsilon) {
      final pointC = pointA + (pointA - pointB) * valueA / (valueB - valueA);
      final valueC = f(pointC);

      if (valueC * valueB <= 0) {
        pointA = pointB;
        valueA = valueB;
      } else {
        valueA /= 2;
      }

      pointB = pointC;
      valueB = valueC;
    }

    return math.exp(pointA / 2);
  }
}
