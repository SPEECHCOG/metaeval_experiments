"""
    This script runs the test for vowel discrimination task, calculating meta-analysis statistics.

    @date 28.05.2021
"""

__docformat__ = ['reStructuredText']
__all__ = ['run_full_basic_test']

import argparse
import csv
import json
import pathlib
import pickle
from typing import Union, List, Optional, Tuple

from evaluation_protocol.io_module.preprocess_distances_files import read_distances_csv_file
from evaluation_protocol.io_module.read_predictions_and_features import read_input_features, \
    get_predictions_and_time_stamps
from evaluation_protocol.tests_setup.calculate_dtw_distances import calculate_dtw_distances
from evaluation_protocol.tests_setup.calculate_meta_analysis_statistics import get_meta_analysis_statistics

BASIC_OC_CONTRASTS = [('a', 'a:')]
BASIC_HC_CONTRASTS = [('A', 'i'), ('i', 'I'), ('A', 'E'), ('e', 'E'), ('A', '{')]
BASIC_IVC_CONTRASTS = [('A', 'i'), ('i', 'I'), ('A', 'E'), ('A', '{')]
BASIC_IVC_NON_NATIVE_CONTRASTS = [('a', 'a~'), ('a:', 'a'), ('u:', 'y:')]
BASIC_OC_CONTRASTS_LANGUAGES = [('de', 'de')]
BASIC_HC_CONTRASTS_LANGUAGES = [('en', 'en')] * 5
BASIC_IVC_CONTRASTS_LANGUAGES = [('en', 'en')] * 4
BASIC_IVC_NON_NATIVE_CONTRASTS_LANGUAGES = [('fr', 'fr'), ('jp', 'jp'), ('de', 'de')]
BASIC_FILTERS = {'repetitions': ['N1'], 'failed_listeners_test': False}


def _run_basic_vowel_discrimination_test(corpus_info_path: Union[str, pathlib.Path],
                                         input_features_path: Union[str, pathlib.Path],
                                         predictions_path: Union[str, pathlib.Path],
                                         corpus: str, feature_type: str,
                                         dtw_distances_csv_file: Union[str, pathlib.Path],
                                         window_shift: Optional[int] = 10,
                                         contrasts: Optional[List[Tuple[str, str]]] = None,
                                         contrasts_languages: Optional[List[Tuple[str, str]]] = None) -> \
        List[List[Union[str, int, float]]]:
    # load corpus info
    with open(corpus_info_path, 'rb') as corpus_info_file:
        corpus_info = pickle.load(corpus_info_file)
    # load file_mapping & indices
    input_feats, file_mapping, indices = read_input_features(input_features_path)
    if feature_type == 'mfcc':
        predictions_list, time_stamps_list = get_predictions_and_time_stamps('', indices, predictions=input_feats,
                                                                             window_shift=window_shift)
    else:  # apc and cpc
        predictions_list, time_stamps_list = get_predictions_and_time_stamps(predictions_path, indices,
                                                                             window_shift=window_shift)

    if contrasts is None and contrasts_languages is None:
        if corpus == 'ivc':
            contrasts = BASIC_IVC_CONTRASTS
            contrasts_languages = BASIC_IVC_CONTRASTS_LANGUAGES
        elif corpus == 'hc':
            contrasts = BASIC_HC_CONTRASTS
            contrasts_languages = BASIC_HC_CONTRASTS_LANGUAGES
        else:  # oc
            contrasts = BASIC_OC_CONTRASTS
            contrasts_languages = BASIC_OC_CONTRASTS_LANGUAGES

    if pathlib.Path(dtw_distances_csv_file).is_file():  # DTW distances are calculated
        same_distances, different_distances, contrasts, contrasts_languages = read_distances_csv_file(
            dtw_distances_csv_file)
    else:
        same_distances, different_distances = calculate_dtw_distances(corpus_info, file_mapping, predictions_list,
                                                                      time_stamps_list, contrasts, BASIC_FILTERS,
                                                                      corpus, contrasts_languages=contrasts_languages,
                                                                      output_file_path=dtw_distances_csv_file)

    # Calculate statistics and output lists of statistics per contrast
    statistics = get_meta_analysis_statistics(same_distances, different_distances)

    output_lists = []
    for idx, contrast in enumerate(contrasts):
        entry = [corpus, feature_type, contrast, contrasts_languages[idx]]
        entry += statistics[idx]
        output_lists.append(entry)
        # corpus, feature_type, contrast, languages, n1, n2, mean1, mean2, std1, std2, es, se, w
    return output_lists


def run_full_basic_test(corpus_info_path: Union[str, pathlib.Path],
                        input_features_path: Union[str, pathlib.Path],
                        predictions_path: Union[str, pathlib.Path],
                        corpus: str, dtw_distances_csv_files: dict,
                        output_csv_file: Union[str, pathlib.Path],
                        window_shift: Optional[int] = 10,
                        contrasts: Optional[List[Tuple[str, str]]] = None,
                        contrasts_languages: Optional[List[Tuple[str, str]]] = None,
                        feature_types: Optional[List[str]] = None) -> None:
    if feature_types is None:
        feature_types = ['mfcc', 'apc', 'cpc']

    assert set(dtw_distances_csv_files.keys()).issubset(set(feature_types)) or \
           set(feature_types).issubset(set(dtw_distances_csv_files.keys()))

    headers = ['corpus', 'feature type', 'contrast', 'languages', 'n1', 'n2', 'mean1', 'mean2', 'std1', 'std2',
               'es', 'se', 'w']
    rows = [headers]
    for feature_type in feature_types:
        predictions_path = predictions_path.replace('apc_', f'{feature_type}_')
        predictions_path = predictions_path.replace('cpc_', f'{feature_type}_')
        predictions_path = predictions_path.replace('mfcc_', f'{feature_type}_')
        rows += _run_basic_vowel_discrimination_test(corpus_info_path, input_features_path, predictions_path, corpus,
                                                     feature_type, dtw_distances_csv_files[feature_type],
                                                     window_shift=window_shift, contrasts=contrasts,
                                                     contrasts_languages=contrasts_languages)

    # write csv file
    pathlib.Path(output_csv_file).parent.mkdir(parents=True, exist_ok=True)

    with open(output_csv_file, 'w', newline='') as csv_file:
        writer = csv.writer(csv_file, delimiter=';')
        writer.writerows(rows)


def read_config_file(file_path: Union[str, pathlib.Path]):
    with open(file_path) as config_file:
        config = json.load(config_file)
    corpora = {'ivc', 'hc', 'oc'}
    test_types = {'basic', 'basic_non_native'}
    required_fields = {'input_features_path', 'corpus_info_path', 'predictions_path', 'corpus', 'output_csv_path',
                       'type', 'dtw_distances_csv_files'}
    entries = set(config.keys())

    assert required_fields.issubset(entries)

    assert config['corpus'] in corpora

    assert config['type'] in test_types

    assert isinstance(config['dtw_distances_csv_files'], dict)

    if 'window_shift' in entries:
        assert isinstance(config['window_shift'], int)
    else:
        config['window_shift'] = None

    return config


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Script to run vowel discrimination test (calculation of effect size, '
                                                 'and standard error). '
                                                 '\nUsage: python test_vowel_discrimination.py '
                                                 '--config path_configuration_file ')

    parser.add_argument('--config', type=str, required=True)
    args = parser.parse_args()

    config = read_config_file(args.config)

    contrasts = None
    contrasts_languages = None
    feature_types = None
    if config['type'] == 'basic_non_native':
        contrasts = BASIC_IVC_NON_NATIVE_CONTRASTS
        contrasts_languages = BASIC_IVC_NON_NATIVE_CONTRASTS_LANGUAGES
    if 'feature_types' in config and config['feature_types'] is not None:
        feature_types = config['feature_types']

    if config['type'] in ['basic', 'basic_non_native']:
        if config['window_shift']:
            run_full_basic_test(config['corpus_info_path'], config['input_features_path'], config['predictions_path'],
                                config['corpus'], config['dtw_distances_csv_files'], config['output_csv_path'],
                                window_shift=config['window_shift'], contrasts=contrasts,
                                contrasts_languages=contrasts_languages, feature_types=feature_types)
        else:
            run_full_basic_test(config['corpus_info_path'], config['input_features_path'], config['predictions_path'],
                                config['corpus'], config['dtw_distances_csv_files'], config['output_csv_path'],
                                contrasts=contrasts, contrasts_languages=contrasts_languages,
                                feature_types=feature_types)




