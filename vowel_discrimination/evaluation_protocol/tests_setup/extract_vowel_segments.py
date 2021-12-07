"""
    This script extract the vowel segments from the predictions, using the time stamps provided in the corpus info
    file.

    @date 26.05.2021
"""

__docformat__ = ['reStructuredText']
__all__ = ['extract_vowel_segments']

import pathlib
from typing import List

import numpy as np


def _get_vowel_segments(predictions_list: List[np.ndarray], time_stamps_list: List[np.ndarray], file_mapping: List[str],
                        corpus_info: dict) -> List[np.ndarray]:
    vowel_segments = []
    for idx, prediction in enumerate(predictions_list):
        trial_name = pathlib.Path(file_mapping[idx]).stem
        onset_time = corpus_info[trial_name]['vowel_onset']
        offset_time = corpus_info[trial_name]['vowel_offset']
        index_maks = (time_stamps_list[idx] >= onset_time) & (time_stamps_list[idx] <= offset_time)
        vowel_segments.append(prediction[index_maks])

    return vowel_segments


def extract_vowel_segments(corpus_info: dict, file_mapping: List[str], predictions_list: List[np.ndarray],
                           time_stamps_list: List[np.ndarray], corpus: str,
                           ) -> List[np.ndarray]:
    if corpus == 'ivc':
        vowel_segments = predictions_list
    else:  # oc and hc (/cvc/ contexts)
        vowel_segments = _get_vowel_segments(predictions_list, time_stamps_list, file_mapping, corpus_info)

    return vowel_segments

