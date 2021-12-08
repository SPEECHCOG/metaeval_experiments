"""
    It extracts acoustic features from a corpus and create the input features h5py file for PC models
    @date 18.05.2021
"""
__docformat__ = ['reStructuredText']
__all__ = ['obtain_features_hillenbrands_corpus', 'obtain_features_ollo_corpus',
           'obtain_features_isolated_vowel_corpus']

import argparse
import pathlib
import pickle
from typing import List, Union, Optional

from corpus_processing.extract_acoustic_features import extract_acoustic_features, create_h5py_file
from corpus_processing.preprocess_ollo_corpus import obtain_audio_paths


def _get_audio_files_paths(corpus_info_path: Union[str, pathlib.Path],
                           zip_files_paths: Union[List[str], List[pathlib.Path]]) -> List[List[str]]:
    with open(corpus_info_path, 'rb') as data_file:
        corpus_info = pickle.load(data_file)

    filtered_logatomes = list(set(corpus_info[trial_file]['details']['logatome'] for trial_file in corpus_info.keys()))

    return obtain_audio_paths(zip_files_paths, filtered_logatomes)


def obtain_features_ollo_corpus(corpus_info_path: Union[str, pathlib.Path],
                                zip_files_paths: Union[List[str], List[pathlib.Path]],
                                output_path: str, cmvn: Optional[bool] = True) -> None:
    audio_files_paths = _get_audio_files_paths(corpus_info_path, zip_files_paths)
    audio_files_paths = [sorted(paths) for paths in audio_files_paths]
    features = []

    for idx, zip_file in enumerate(zip_files_paths):
        features += extract_acoustic_features(audio_files_paths[idx], zip_path=zip_file, cmvn=cmvn)

    files = [audio_path for zip_file in audio_files_paths for audio_path in zip_file]
    create_h5py_file(output_path, files, features, 200, 100, True)


def _get_hillenbrands_corpus_trials_paths(corpus_path: Union[str, pathlib.Path],
                                          corpus_info_path: Union[str, pathlib.Path],
                                          include_listeners_test_failed: Optional[bool] = False) -> List[pathlib.Path]:
    trials_files = list(pathlib.Path(corpus_path).glob('**/*.wav'))

    with open(corpus_info_path, 'rb') as data_file:
        corpus_info = pickle.load(data_file)

    if not include_listeners_test_failed:
        trials_files = [file_path for file_path in trials_files
                        if not corpus_info[file_path.resolve().stem]['details']['failed_listeners_test']]

    return trials_files


def obtain_features_hillenbrands_corpus(corpus_path: Union[str, pathlib.Path],
                                        corpus_info_path: Union[str, pathlib.Path],
                                        output_path: Union[str, pathlib.Path], cmvn: Optional[bool] = True,
                                        listeners_failed: Optional[bool] = False) -> None:
    trials_paths = _get_hillenbrands_corpus_trials_paths(corpus_path, corpus_info_path,
                                                         include_listeners_test_failed=listeners_failed)
    files = sorted(trials_paths)
    features = extract_acoustic_features(files, cmvn=cmvn)
    create_h5py_file(output_path, files, features, 200, 100, True)


def obtain_features_isolated_vowel_corpus(wav_files_path: Union[str, pathlib.Path],
                                          output_path: Union[str, pathlib.Path], cmvn: Optional[bool] = True) -> None:
    files = list(pathlib.Path(wav_files_path).iterdir())
    files = sorted(files)
    features = extract_acoustic_features(files, cmvn=cmvn)
    create_h5py_file(output_path, files, features, 200, 50, True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Script to create h5py file with acoustic features from a corpus. '
                                                 '\nUsage: python create_input_features.py '
                                                 '--corpus ivc<isolated vowels corpus>|hc<Hillenbrand\'s corpus>'
                                                 '|oc<OLLO corpus> '
                                                 '--audio_path path_zip_or_folder_with_audio_files '
                                                 '--output_path path_h5py_output_file '
                                                 '[--cmvn | --no-cmvn] '
                                                 '[--corpus_info_path] '
                                                 '[--listeners_failed | --no-listeners_failed]')

    parser.add_argument('--corpus', type=str, choices=['ivc', 'hc', 'oc'], required=True)
    parser.add_argument('--audio_path', type=str, required=True)
    parser.add_argument('--output_path', type=str, required=True)

    parser.add_argument('--corpus_info_path', type=str)

    parser.add_argument('--cmvn', dest='cmvn', action='store_true')
    parser.add_argument('--no-cmvn', dest='cmvn', action='store_false')

    parser.add_argument('--listeners_failed', dest='listeners_failed', action='store_true')
    parser.add_argument('--no-listeners_failed', dest='listeners_failed', action='store_false')

    parser.set_defaults(cmvn=False, listeners_failed=False)

    args = parser.parse_args()

    if args.corpus == 'ivc':
        obtain_features_isolated_vowel_corpus(args.audio_path, args.output_path, args.cmvn)
    elif args.corpus == 'hc':
        if args.corpus_info_path is None:
            raise argparse.ArgumentError(args.corpus_info_path, '--corpus_info_path is required for processing the '
                                                                'Hillenbrand\'s corpus.')
        else:
            obtain_features_hillenbrands_corpus(args.audio_path, args.corpus_info_path, args.output_path, args.cmvn,
                                                args.listeners_failed)
    else:  # oc
        if args.corpus_info_path is None:
            raise argparse.ArgumentError(args.corpus_info_path, '--corpus_info_path is required for processing the '
                                                                'OLLO corpus.')
        else:
            obtain_features_ollo_corpus(args.corpus_info_path, [args.audio_path], args.output_path, args.cmvn)
