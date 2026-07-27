from collections.abc import Iterable
from fractions import Fraction


def allocate_minor_units(
    total_minor_units: int, weights: Iterable[int]
) -> tuple[int, ...]:
    """Allocate whole minor units with deterministic largest remainders."""
    normalized_weights = tuple(weights)
    if total_minor_units < 0:
        raise ValueError("total_minor_units must be non-negative")
    if not normalized_weights:
        raise ValueError("at least one weight is required")
    if any(weight < 0 for weight in normalized_weights):
        raise ValueError("weights must be non-negative")

    denominator = sum(normalized_weights)
    if denominator == 0:
        raise ValueError("at least one weight must be positive")

    quotas = tuple(
        Fraction(total_minor_units * weight, denominator)
        for weight in normalized_weights
    )
    allocations = [quota.numerator // quota.denominator for quota in quotas]
    residual = total_minor_units - sum(allocations)
    residual_order = sorted(
        range(len(quotas)),
        key=lambda index: (-(quotas[index] - allocations[index]), index),
    )

    for index in residual_order[:residual]:
        allocations[index] += 1

    return tuple(allocations)
