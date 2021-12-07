"""
    It reads the predictions of tests (h5py or text files) and creates output files of the tests.

    The format for predictions in text file is the time stamp in seconds of frame centre followed by the
    representation vector of that frame, separated by space:
    time-stamp val-dim1 val-dim2 .... val-dimN

    For example:
    --------------------------------------
    0.005 0.23 0.41 -0.20 ... 0.94
    0.010 1.20 0.24 -0.58 ... 1.34
    .
    .
    .
    1.005 0.26 1.24 -0.81 ... 0.04
    --------------------------------------

    @date 24.05.2021
"""

__docformat__ = ['reStructuredText']
__all__ = ['read_input_features', 'get_predictions_and_time_stamps', 'read_prediction_file']

import pathlib
from typing import Union, Tuple, List, Optional

import h5py
import numpy as np


def _read_pc_predictions(predictions_path: Union[str, pathlib.Path]) -> np.ndarray:
    with h5py.File(predictions_path, 'r') as predictions_file:
        predictions = np.array(predictions_file['latents'])

    return predictions


def read_input_features(input_features_path: Union[str, pathlib.Path]) -> Tuple[np.ndarray, List[str], np.ndarray]:
    with h5py.File(input_features_path, 'r') as data_file:
        input_data = np.array(data_file['data'])
        file_mapping = list(data_file['file_list'])
        indices = np.array(data_file['indices'])
    return input_data, file_mapping, indices


def read_prediction_file(file_path: Union[str, pathlib.Path]) -> Tuple[np.ndarray, np.ndarray]:
    with open(file_path, 'r') as prediction_file:
        lines = prediction_file.readlines()

    data = np.array([[float(item) for item in line.split()] for line in lines])
    time_stamps = data[:,0]
    prediction = data[:,1:]
    return time_stamps, prediction


def _get_predictions_list(predictions: np.ndarray, indices: np.ndarray) -> List[np.array]:
    n_feats = predictions.shape[-1]

    # fast test
    input_utt = []

    indices = indices.reshape(-1, 2)
    predictions = predictions.reshape(-1, n_feats)

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

        input_utt.append(predictions[idx_init:idx_end, :])

    return input_utt


def get_predictions_and_time_stamps(predictions_file: Union[str, pathlib.Path], indices: np.ndarray,
                                    predictions: Optional[np.ndarray] = None,
                                    window_shift: Optional[int] = 10) -> Tuple[List[np.ndarray], List[np.ndarray]]:
    if predictions is not None:
        predictions_list = _get_predictions_list(predictions, indices)
    else:
        predictions = _read_pc_predictions(predictions_file)
        predictions_list = _get_predictions_list(predictions, indices)
    time_stamps_list = []

    for prediction in predictions_list:
        n_frames = prediction.shape[0]
        # Time in msec (window_shift)
        timestamps_trial = np.arange(window_shift / 2, n_frames * window_shift, window_shift)
        time_stamps_list.append(timestamps_trial)

    return predictions_list, time_stamps_list


def read_predictions_from_folder(prediction_folder_path: Union[str, pathlib.Path]) -> \
        Tuple[List[np.ndarray], List[np.ndarray], List[pathlib.Path]]:
    predictions_file_paths = sorted(list(pathlib.Path(prediction_folder_path)    .glob('**/*.txt')))
    predictions_list = []
    time_stamps_list = []
    for path in predictions_file_paths:
        time_stamps, prediction = read_prediction_file(path)
        predictions_list.append(prediction)
        time_stamps_list.append(time_stamps)

    return predictions_list, time_stamps_list, predictions_file_paths
