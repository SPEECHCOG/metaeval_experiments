"""
    This script calculates meta-analysis related statistics to compare results from different sources (metaLAB,
    computational models' performance).

    Formulae from Practical Meta-Analysis, Mark W. Lipsey & David B. Wilson, 2001

    @date 01.06.2021
"""

__docformat__ = ['reStructuredText']
__all__ = ['get_standard_error', 'get_inverse_variance_weight', 'get_mean_weighted_effect_size',
           'get_standard_error_mean_es', 'get_confidence_interval', 'get_p_value_significance_test']

from typing import List, Tuple, Optional

import numpy as np
import scipy.stats


def get_standard_error(n1: int, n2: int, effect_size: float) -> float:
    standard_error = np.sqrt(((n1 + n2) / (n1 * n2)) + ((effect_size ** 2) / (2 * (n1 + n2))))  # (eq. 3.23)
    return standard_error


def get_inverse_variance_weight(standard_error: float):
    weight = 1 / (standard_error ** 2)  # (eq. 3.24)
    return weight


def get_mean_weighted_effect_size(effect_sizes: List[float], weights: List[float]) -> float:
    # Ch. 6 Analyzing the Effect Size Mean and Distribution
    mean_es = np.sum(np.dot(effect_sizes, weights)) / np.sum(weights)
    return mean_es


def get_standard_error_mean_es(weights: List[float]) -> float:
    # Ch. 6 Analyzing the Effect Size Mean and Distribution
    standard_error = np.sqrt(1/np.sum(weights))
    return standard_error


def get_confidence_interval(mean_es: float, se_mean_es: float, alpha: float) -> Tuple[float, float]:
    # Ch. 6 Analyzing the Effect Size Mean and Distribution
    z_critical = scipy.stats.norm.ppf(1 - alpha/2)
    es_l = mean_es - z_critical * se_mean_es
    es_u = mean_es + z_critical * se_mean_es
    return es_l, es_u


def get_p_value_significance_test(mean_es: float, se_mean_es: float) -> Tuple[float, str]:
    # Ch. 6 Analyzing the Effect Size Mean and Distribution
    # Test of the significance of the mean effect size
    z = np.abs(mean_es) / se_mean_es
    p_value = scipy.stats.norm.sf(np.abs(z))
    significance_code = ' '

    if p_value < 0.001:
        significance_code = '***'
    elif p_value < 0.01:
        significance_code = '**'
    elif p_value < 0.05:
        significance_code = '*'
    elif p_value < 0.1:
        significance_code = '.'
    return p_value, significance_code
