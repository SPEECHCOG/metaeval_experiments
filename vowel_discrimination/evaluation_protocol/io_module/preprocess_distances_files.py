"""
    It creates a csv files for the distances calculated for each condition, and it reads a csv file with the distances
    calculated for each condition and contrast.

    @date 28.05.2021
"""

__docformat__ = ['reStructuredText']
__all__ = ['write_distances_csv_file', 'read_distances_csv_file']

import csv
import pathlib
from collections import defaultdict
from typing import Union, List, Tuple


def write_distances_csv_file(csv_file_path: Union[str, pathlib.Path],
                             same_conditions: List[List[Tuple[str, str]]],
                             different_conditions: List[List[Tuple[str, str]]],
                             same_distances: List[List[float]], different_distances: List[List[float]],
                             contrasts: List[Tuple[str, str]], contrasts_languages: List[Tuple[str, str]]) -> None:
    lines = [['contrast', 'language', 'condition', 'file1', 'file2', 'distance']]
    for idx, contrast in enumerate(contrasts):
        for jdx, condition in enumerate(same_conditions[idx]):
            lines.append([str(contrast), str(contrasts_languages[idx]), 'same', condition[0], condition[1],
                          same_distances[idx][jdx]])
        for jdx, condition in enumerate(different_conditions[idx]):
            lines.append([str(contrast), str(contrasts_languages[idx]), 'different', condition[0], condition[1],
                          different_distances[idx][jdx]])

    pathlib.Path(csv_file_path).parent.mkdir(parents=True, exist_ok=True)

    with open(csv_file_path, 'w', newline='') as csv_file:
        writer = csv.writer(csv_file, delimiter=';')
        writer.writerows(lines)


def read_distances_csv_file(csv_file_path: Union[str, pathlib.Path]) -> \
        Tuple[List[List[float]], List[List[float]], List[Tuple[str, str]], List[Tuple[str, str]]]:
    with open(csv_file_path, 'r', newline='') as csv_file:
        reader = csv.DictReader(csv_file, delimiter=';')
        contrasts_tmp = set()
        same_distances_dict = defaultdict(list)
        different_distances_dict = defaultdict(list)
        same_distances = []
        different_distances = []
        for row in reader:
            contrasts_tmp.add((row['contrast'], row['language']))
            if row['condition'] == 'same':
                same_distances_dict[(row['contrast'], row['language'])].append(float(row['distance']))
            else:  # different condition
                different_distances_dict[(row['contrast'], row['language'])].append(float(row['distance']))
        contrasts_tmp = list(contrasts_tmp)
        contrasts = []
        contrasts_languages = []
        for contrast, language in contrasts_tmp:
            contrasts.append(eval(contrast))
            contrasts_languages.append(eval(language))
            same_distances.append(same_distances_dict[(contrast, language)])
            different_distances.append(different_distances_dict[(contrast, language)])

    return same_distances, different_distances, contrasts, contrasts_languages
