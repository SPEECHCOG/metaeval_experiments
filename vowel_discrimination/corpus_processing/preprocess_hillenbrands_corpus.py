"""
    Script to preprocess Hillenbrand's corpus for vowel discrimination task.
    "Hillenbrand, Getty, Clark & Wheeler (1995). Acoustic characteristics of American English vowels. Journal of the
    Acoustical Society of America, 97, 3099-3111"

    This corpus consists of /hVd/ contexts for 12 American English vowels.
    IPA: /i/ /I/ /ɛ/ /æ/ /ɑ/ /ɔ/ /ʊ/ /u/ /ʌ/ /ɛr/ /e/ /o/
    SAMPA: /i/ /I/ /E/ /{/ /A/ /O/ /U/ /u/ /V/ /Er/ /e/ /o/
    File nomenclature: /iy/ /ih/ /eh/ /ae/ /ah/ /aw/ /oo/ /uw/ /uh/ /er/ /ei/ /oa/

    Speakers:
    45 Men
    48 Women
    46 Children:
        27 Boys
        19 Girls

    There is information about the onset and offset of vowels as well as human judgement of what vowel is perceived in
    each trial.

    @date 22.03.2021
"""

__docformat__ = ['reStructuredText']
__all__ = ['create_corpus_info_dict']

import argparse
import pathlib
import pickle
from typing import Union

SAMPA_MAPPING ={
    'iy': 'i',
    'ih': 'I',
    'eh': 'E',
    'ae': '{',
    'ah': 'A',
    'aw': 'O',
    'oo': 'U',
    'uw': 'u',
    'uh': 'V',
    'er': 'Er',
    'ei': 'e',
    'oa': 'o'
}


def _read_id_data(corpus_path: Union[str, pathlib.Path]) -> dict:
    id_data_path = pathlib.Path(corpus_path).joinpath('iddata.dat.txt')
    corpus_info = {}
    with open(id_data_path, 'r') as data_file:
        lines = data_file.readlines()
        vowel_names = lines[19].split()[2:13]
        trials_data = lines[20:]  # Trials' data from line 20

        for trial in trials_data:
            cols = trial.split()
            filename = cols[0].replace('.w', '')
            corpus_info[filename] = {'details': {}}
            corpus_info[filename]['details']['perceived'] = [(SAMPA_MAPPING[vowel], int(cols[idx + 2]))
                                                             for idx, vowel in  enumerate(vowel_names)
                                                             if int(cols[idx + 2]) > 0]
            # Majority perceived vowels different from intended
            corpus_info[filename]['details']['failed_listeners_test'] = cols[-1] == '*'
            corpus_info[filename]['details']['language'] = 'en'
            corpus_info[filename]['vowel'] = SAMPA_MAPPING[filename[-2:]]
            corpus_info[filename]['speaker'] = filename[0:3]

    return corpus_info


def _read_time_data(corpus_path: Union[str, pathlib.Path]) -> dict:
    corpus_info = _read_id_data(corpus_path)

    time_data_path = pathlib.Path(corpus_path).joinpath('timedata.dat.txt')
    with open(time_data_path, 'r') as data_file:
        lines = data_file.readlines()[6:]
        for line in lines:
            cols = line.split()
            corpus_info[cols[0]]['vowel_onset'] = float(cols[1])
            corpus_info[cols[0]]['vowel_offset'] = float(cols[2])

    return corpus_info


def create_corpus_info_dict(output_path: Union[str, pathlib.Path], corpus_path: Union[str, pathlib.Path]) -> None:
    corpus_info = _read_time_data(corpus_path)

    folder_path = pathlib.Path(output_path).parent
    folder_path.mkdir(parents=True, exist_ok=True)

    with open(output_path, 'wb') as data_file:
        pickle.dump(corpus_info, data_file)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Script to create corpus info file (dictionary) for the '
                                                 'Hillenbrand\'s corpus. '
                                                 '\nUsage: python preprocess_hillenbrands_corpus.py '
                                                 '--corpus_path path_Hillenbrands_corpus '
                                                 '--output_path path_corpus_info_file ')

    parser.add_argument('--corpus_path', type=str, required=True)
    parser.add_argument('--output_path', type=str, required=True)

    args = parser.parse_args()

    create_corpus_info_dict(args.output_path, args.corpus_path)