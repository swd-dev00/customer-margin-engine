from hypothesis import given
from hypothesis import strategies as st

from tests.support.allocation_oracle import allocate_minor_units

positive_weight_sets = st.lists(
    st.integers(min_value=0, max_value=1_000_000),
    min_size=1,
    max_size=25,
).filter(lambda weights: sum(weights) > 0)


@given(
    total_minor_units=st.integers(min_value=0, max_value=10_000_000),
    weights=positive_weight_sets,
)
def test_reference_allocation_conserves_every_minor_unit(
    total_minor_units: int,
    weights: list[int],
) -> None:
    allocations = allocate_minor_units(total_minor_units, weights)

    assert sum(allocations) == total_minor_units
    assert len(allocations) == len(weights)
    assert all(amount >= 0 for amount in allocations)


@given(
    total_minor_units=st.integers(min_value=0, max_value=10_000_000),
    weights=positive_weight_sets,
)
def test_reference_allocation_is_deterministic(
    total_minor_units: int,
    weights: list[int],
) -> None:
    first = allocate_minor_units(total_minor_units, weights)
    second = allocate_minor_units(total_minor_units, weights)

    assert first == second


def test_reference_allocation_breaks_equal_remainders_by_input_order() -> None:
    assert allocate_minor_units(1, (1, 1)) == (1, 0)
