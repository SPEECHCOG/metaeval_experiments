"""
    This script reads and write csv files with the attentional preference score per frame for each IDS preference trial.

    @date 12.11.2021
"""

__docformat__ = ['reStructuredText']
__all__ = ['create_csv_attentional_scores', 'read_csv_attentional_scores']

import csv
import pathlib
from typing import Union, List, Tuple

import numpy as np
import pandas as pd
from pc_attentional_score_calculation.io_module.read_predictions_and_features import read_input_features


def create_csv_attentional_scores(trials_loss: List[np.ndarray], input_features_path: Union[str, pathlib.Path],
                                  output_csv_path: Union[str, pathlib.Path]) -> None:
    _, mapping, _ = read_input_features(input_features_path)
    csv_lines = [['file_name', 'trial_type', 'frame', 'attentional_preference_score']]
    for trial_idx in range(len(trials_loss)):
        trial_file_name = pathlib.Path(mapping[trial_idx]).stem
        # e.g. names path_to_wav/<IDS|ADS>/filename.wav
        trial_type = pathlib.Path(mapping[trial_idx]).parent.stem  # IDS or ADS
        loss_per_frame = trials_loss[trial_idx]
        for frame_idx in range(len(loss_per_frame)):
            csv_lines.append([trial_file_name, trial_type, frame_idx, loss_per_frame[frame_idx]])

    pathlib.Path(output_csv_path).parent.mkdir(parents=True, exist_ok=True)

    with open(output_csv_path, 'w', newline='') as csv_file:
        writer = csv.writer(csv_file, delimiter=';')
        writer.writerows(csv_lines)


def read_csv_attentional_scores(csv_path: Union[str, pathlib.Path]) -> Tuple[List[np.ndarray], List[str]]:
    all_attentional_scores = pd.read_csv(csv_path, sep=';')
    trials = []
    trials_name = []
    unique_files = all_attentional_scores.file_name.unique()
    for file_name in unique_files:
        trials_name.append(file_name)
        scores = all_attentional_scores[all_attentional_scores.file_name == file_name][
            'attentional_preference_score'].to_numpy()
        trials.append(scores)
    return trials, trials_name
