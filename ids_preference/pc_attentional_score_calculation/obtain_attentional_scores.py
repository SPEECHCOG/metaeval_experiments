"""
    This is the main script to obtain the attentional preference score per frame for each IDS preference trial and
    to create csv files with the measurements.

    @date 12.11.2021
"""

__docformat__ = ['reStructuredText']
__all__ = ['']

import argparse
import pathlib
from typing import Union, Optional

from calculate_pc_attentional_score import calculate_mae_per_frame, \
    calculate_infonce_per_frame
from io_module.preprocess_score_files import create_csv_attentional_scores


def obtain_scores_for_trials(model_path: Union[str, pathlib.Path], input_features_path: Union[str, pathlib.Path],
                             output_csv_path: Union[str, pathlib.Path], model_type: str,
                             overlap: Optional[float] = 0.5, apc_shift: Optional[int] = 5,
                             cpc_neg: Optional[int] = 10, cpc_steps: Optional[int] = 12) -> None:
    assert 1 >= overlap >= 0
    if model_type == 'apc':
        trials_loss = calculate_mae_per_frame(model_path, input_features_path, overlap, apc_shift)
    else:  # cpc
        trials_loss = calculate_infonce_per_frame(model_path, input_features_path, overlap, cpc_neg, cpc_steps)

    create_csv_attentional_scores(trials_loss, input_features_path, output_csv_path)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Script to obtain attentional score per frame and trial and '
                                                 'create csv files with measurements.\nUsage: '
                                                 'obtain_attentional_scores.py --model_path h5py_path '
                                                 '--input_path path_to_h5py_input_features '
                                                 '--output_csv_path path_output_csv_file '
                                                 '--model_type [apc|cpc] --overlap percentage --apc_shift shift '
                                                 '--cpc_neg negative_samples --cpc_steps steps')
    parser.add_argument('--model_path', type=str, required=True)
    parser.add_argument('--input_path', type=str, required=True)
    parser.add_argument('--output_csv_path', type=str, required=True)
    parser.add_argument('--model_type', type=str, choices=['apc', 'cpc'], required=True)
    parser.add_argument('--overlap', type=float, default=0.5)
    parser.add_argument('--apc_shift', type=int, default=5)
    parser.add_argument('--cpc_neg', type=int, default=10)
    parser.add_argument('--cpc_steps', type=int, default=12)

    args = parser.parse_args()

    obtain_scores_for_trials(args.model_path, args.input_path, args.output_csv_path, args.model_type, args.overlap,
                             args.apc_shift, args.cpc_neg, args.cpc_steps)
