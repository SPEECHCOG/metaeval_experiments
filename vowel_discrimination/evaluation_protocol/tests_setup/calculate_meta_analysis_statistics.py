"""
    This script calculates meta-analysis statistics, as they are effect sizes, standard error, mean, standard deviation,
    and variance. It also creates a csv file with this calculations for further processes.

    Formulae from Practical Meta-Analysis, Mark W. Lipsey and David B. Wilson, SAGE Publications, 2001

    @date 28.05.2021
"""

__docformat__ = ['reStructuredText']
__all__ = ['get_meta_analysis_statistics']

from typing import List, Tuple, Union

import numpy as np

from evaluation_protocol.metalab_comparison.calculate_statistics import get_standard_error, get_inverse_variance_weight


def _get_basic_statistics(same_condition: List[float], different_condition: List[float]) -> \
        Tuple[int, int, float, float, float, float]:
    n1, n2 = len(different_condition), len(same_condition)
    std1, std2 = float(np.std(different_condition)), float(np.std(same_condition))
    mean1, mean2 = float(np.mean(different_condition)), float(np.mean(same_condition))  # experimental vs control groups
    return n1, n2, mean1, mean2, std1, std2


def _get_advanced_statistics(n1: int, n2: int, mean1: float, mean2: float, std1: float, std2: float) -> \
        Tuple[float, float, float]:
    s_pooled = np.sqrt((std1*std1 + std2*std2)/2)
    effect_size = (mean1 - mean2)/s_pooled  # Standardised Mean Gain

    # Hedges' correction
    effect_size = (1 - (3/(4*(n1 + n2) - 9))) * effect_size  # (eq. 3.22)

    standard_error = get_standard_error(n1, n2, effect_size)
    weight = get_inverse_variance_weight(standard_error)

    return effect_size, standard_error, weight


def get_meta_analysis_statistics(same_cond_distances: List[List[float]], different_cond_distances: List[List[float]]) \
        -> List[List[Union[int, float]]]:
    statistics = []
    for idx, same_condition in enumerate(same_cond_distances):
        n1, n2, mean1, mean2, std1, std2 = _get_basic_statistics(same_condition,
                                                                 different_cond_distances[idx])
        es, se, w = _get_advanced_statistics(n1, n2, mean1, mean2, std1, std2)
        statistics.append([n1, n2, mean1, mean2, std1, std2, es, se, w])

    return statistics



