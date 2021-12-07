"""
    It reads a h5py input features file and outputs datastructures for further processing
"""

__docformat__ = ['reStructuredText']
__all__ = ['read_input_features', 'get_trials_list']

import pathlib
from typing import Union, Tuple, List

import h5py
import numpy as np


def read_input_features(input_features_path: Union[str, pathlib.Path]) -> Tuple[np.ndarray, List[str], np.ndarray]:
    with h5py.File(input_features_path, 'r') as data_file:
        input_data = np.array(data_file['data'])
        file_mapping = list(data_file['file_list'])
        indices = np.array(data_file['indices'])
    return input_data, file_mapping, indices


def get_trials_list(features: np.ndarray, indices: np.ndarray) -> List[np.array]:
    n_feats = features.shape[-1]

    # fast test
    input_trials = []

    indices = indices.reshape(-1, 2)
    features = features.reshape(-1, n_feats)

    prev = indices[0, 0]  # first file id
    init = 0

    file_indices = []
    total_frames = indices.shape[0]

    for i in range(total_frames):
        if indices[i, 0] != prev:
            if prev != -1:
                file_indices.append((init, i))  # Only add it if is not reset frames
            prev = indices[i, 0]
            init = i

        if indices[i, 0] == -1:  # reset or extra frames
            prev = indices[i, 0]
            init = i
            continue

        if i == total_frames - 1:
            file_indices.append((init, total_frames))

    for i in range(len(file_indices)):
        idx_init = file_indices[i][0]
        idx_end = file_indices[i][1]

        input_trials.append(features[idx_init:idx_end, :])

    return input_trials
