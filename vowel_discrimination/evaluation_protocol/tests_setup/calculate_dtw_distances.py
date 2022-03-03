"""
    This script calculates DTW distances for the different vowel segments (those specified in the test conditions
    lists). It also creates a csv file with the distances calculated for each contrast.

    @date 27.05.2021
"""

__docformat__ = ['reStructuredText']
__all__ = ['calculate_dtw_distances']

import pathlib
import pickle
from typing import Optional, Union, List, Tuple

import numpy as np
from dtw import dtw

from evaluation_protocol.io_module.preprocess_distances_files import write_distances_csv_file
from evaluation_protocol.tests_setup.create_tests_conditions import generate_tests_conditions
from evaluation_protocol.tests_setup.extract_vowel_segments import extract_vowel_segments


def _calculate_dtw(matrix1: np.ndarray, matrix2: np.ndarray, dist_method: Optional[str] = 'cosine') -> float:
    # Avoid non-definition of distance for zero vectors, replace those vectors with random representation
    zero_frames = np.where(np.sum(matrix1, axis=1) == 0)[0]
    matrix1[zero_frames, :] = np.random.rand(len(zero_frames), matrix1.shape[-1])

    zero_frames2 = np.where(np.sum(matrix2, axis=1) == 0)[0]
    matrix2[zero_frames2, :] = np.random.rand(len(zero_frames2), matrix2.shape[-1])

    alignment = dtw(matrix1, matrix2, keep_internals=True, distance_only=True, dist_method=dist_method)
    return alignment.normalizedDistance


def _calculate_dtw_distances_per_condition(vowel_segments: List[np.ndarray], file_mapping: List[str],
                                           same_list: List[List[Tuple[str, str]]],
                                           different_list: List[List[Tuple[str, str]]]) -> \
        Tuple[List[List[float]], List[List[float]]]:
    indices = {pathlib.Path(file_path).stem: idx for idx, file_path in enumerate(file_mapping)}
    same_distances = []
    different_distances = []
    calculated_distances = {}

    for condition_list, distances_list in zip([same_list, different_list], [same_distances, different_distances]):
        for contrast in condition_list:
            distances = []
            for trial1, trial2 in contrast:
                if (trial1, trial2) in calculated_distances:
                    distances.append(calculated_distances[(trial1, trial2)])
                elif (trial2, trial1) in calculated_distances:
                    distances.append(calculated_distances[(trial1, trial2)])
                else:  # first time
                    dtw_distance = _calculate_dtw(vowel_segments[indices[trial1]], vowel_segments[indices[trial2]])
                    distances.append(dtw_distance)
                    calculated_distances[(trial1, trial2)] = dtw_distance
            distances_list.append(distances)

    return same_distances, different_distances


def calculate_dtw_distances(corpus_info: dict, file_mapping: List[str],
                            predictions_list: List[np.ndarray], time_stamps_list: List[np.ndarray],
                            contrasts: List[Tuple[str, str]],
                            filters: dict, corpus: str, contrasts_languages: List[Tuple[str, str]],
                            output_file_path: Optional[Union[str, pathlib.Path]] = None,
                            vowels_segments: Optional[bool] = False) -> \
        Tuple[List[List[float]], List[List[float]]]:
    if vowels_segments:
        segments = extract_vowel_segments(corpus_info, file_mapping, predictions_list, time_stamps_list, corpus)
    else:  # Use whole CVC context for calculating the distance
        segments = predictions_list
    same_conditions, different_conditions = generate_tests_conditions(corpus_info, contrasts, filters, corpus,
                                                                      contrasts_languages=contrasts_languages)
    same_distances, different_distances = _calculate_dtw_distances_per_condition(segments, file_mapping,
                                                                                 same_conditions, different_conditions)

    if output_file_path:
        write_distances_csv_file(output_file_path, same_conditions, different_conditions, same_distances,
                                 different_distances, contrasts, contrasts_languages)

    return same_distances, different_distances
