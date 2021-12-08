"""
    It creates the input features for PC models. Overlapped samples of trials
    @date 11.11.2021
"""

__docformat__ = ['reStructuredText']
__all__ = []

import argparse
import pathlib
from typing import Union, Optional

from trial_processing.extract_acoustic_features import extract_acoustic_features, create_h5py_file


def obtain_features_ids_preference_trials(trials_paths: Union[str, pathlib.Path],
                                          output_h5py_path: Union[str, pathlib.Path], cmvn: Optional[bool] = True):
    files = list(pathlib.Path(trials_paths).rglob('*.wav'))
    files = sorted(files)
    features = extract_acoustic_features(files, cmvn=cmvn)
    create_h5py_file(output_h5py_path, files, features, 200, 50, True)  # 200 sample size, 50 reset between samples


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Script to generate the input features of IDS/ADS trials for'
                                                 ' APC and CPC models.\nUsage: python create_input_features.py '
                                                 '--trials_path path_wav_files_trials '
                                                 '--output_path path_h5py_output_file  '
                                                 '[--cmvn| --no-cmvn] ')
    parser.add_argument('--trials_path', type=str, required=True)
    parser.add_argument('--output_path', type=str, required=True)
    parser.add_argument('--cmvn', dest='cmvn', action='store_true')
    parser.add_argument('--no-cmvn', dest='cmvn', action='store_false')
    parser.set_defaults(cmvn=False)

    args = parser.parse_args()

    obtain_features_ids_preference_trials(args.trials_path, args.output_path, args.cmvn)

