"""
    Preprocess OLLO corpus Meyer et al., J. Acoust. Soc. Am.128 (5), 3126-3141.

    This corpus consists of simple non-sense CVC and VCV contexts spoken by:
     *  40 German
     *  10 French
    Where each logatome is spoken in six different styles:
     *  Load speaking effort
     *  Soft speaking effort
     *  Fast speaking rate
     *  Slow speaking rate
     *  Rising pitch (question)
     *  Normal

    There are phonetic transcriptions available for all files (HTK format). Transcription in SAMPA standard.

    Phones for VCV context:

    IPA: /b/, /d/, /f/, /g/, /k/, /l/, /m/, /n/, /p/, /s/, /ʃ/, /t/, /v/, /ts/, /a/, /ɛ/, /I/, /ɔ/, /ʊ/
    SAMPA: /b/, /d/, /f/, /g/, /k/, /l/, /m/, /n/, /p/, /s/, /S/, /t/, /v/, /ts/, /a/, /E/, /I/, /O/, /U/

    Phones for CVC context:
    IPA: /a/, /a:/, /ɛ/, /e/, /I/, /i/, /ɔ/, /o/, /ʊ/, /u/, /b/, /d/, /f/, /g/, /k/, /p/, /ʃ/, /s/, /t/
    SAMPA: /a/, /a:/, /E/, /e/, /I/, /i/, /O/, /o/, /U/, /u/, /b/, /d/, /f/, /g/, /k/, /p/, /S/, /s/, /t/

    @date 31.03.2021
"""

__docformat__ = ['reStructuredText']
__all__ = ['create_corpus_info_dict', 'obtain_audio_paths']

import argparse
import json
import pathlib
import pickle
import re
import zipfile
from typing import Union, Optional, List


def _read_logatomes_info(corpus_path: Union[str, pathlib.Path]) -> dict:
    logatomes_info = {}
    # Basic corpus info
    corpus_info_zip_path = pathlib.Path(corpus_path).joinpath('OLLO2.0_README.ZIP')
    with zipfile.ZipFile(corpus_info_zip_path) as zf:
        lines = zf.open('OLLO2.0_README/OLLO2.0_ORT.TXT').readlines()
        logatomes_tokens = lines[4:154]  # The description of context is the same for German and French

        for line in logatomes_tokens:
            line = line.decode('ISO-8859-1')
            (name, ctxt, _) = line.split()
            logatomes_info[name] = {'context': ctxt}
    # SAMPA info of logatomes
    labels_info_zip_path = pathlib.Path(corpus_path).joinpath('OLLO2.0_LABELS.ZIP')
    with zipfile.ZipFile(labels_info_zip_path) as zf:
        lines = zf.open('OLLO2.0_LABELS_FORCED_ALIGNMENT/SAMPA_TRANSCRIPT.TXT').readlines()
        pho_info = ' '.join([line.decode('ISO-8859-1') for line in lines[41:58]])
        pho_info = pho_info.replace('\r\n', '').replace('    dictPho = ', '').replace('\'', '"')
        pho_info = re.sub(r'(\d+)', r'"\1"', pho_info)  # keys in quotes
        pho_dict = json.loads(pho_info)

        for id_log in pho_dict:
            logatome_name = f'L{int(id_log):03d}'
            phones = pho_dict[id_log].split()
            logatomes_info[logatome_name]['phones'] = phones

    return logatomes_info


def _filter_logatomes(logatomes_info: dict, context: Optional[str] = None) -> list:
    filtered_logatomes = []

    if context is not None:
        assert context in ['cvc', 'vcv']

    contexts = ['cvc', 'vcv'] if context is None else [context]

    for context in contexts:
        filtered_logatomes = [id_log for id_log in sorted(logatomes_info.keys())
                              if logatomes_info[id_log]['context'] == context]

    return filtered_logatomes


def obtain_audio_paths(zip_list: List[Union[pathlib.Path, str]], filtered_logatomes: List[str]) -> List[List[str]]:
    final_paths = []
    for zip_file in zip_list:
        with zipfile.ZipFile(zip_file) as zf:
            audio_files = zf.namelist()
            zip_paths = []
            for audio_files in audio_files:
                log_search = re.search(r'(L\d+)', audio_files)
                if log_search:
                    logatome = log_search.group(1)
                    if logatome in filtered_logatomes:
                        zip_paths.append(audio_files)
            final_paths.append(zip_paths)

    return final_paths


def _get_corpus_info_dict(corpus_path: Union[pathlib.Path, str], dialect_audio_paths: List[List[str]],
                          logatomes_info: dict) -> dict:
    labels_zip_path = pathlib.Path(corpus_path).joinpath('OLLO2.0_LABELS.ZIP')
    timestamps = {}

    with zipfile.ZipFile(labels_zip_path) as zf:
        parent_prefix = zf.namelist()[0]
        for dialect in dialect_audio_paths:
            for audio_path in dialect:
                full_path = f'{parent_prefix}{audio_path}'
                full_path = full_path.replace('.wav', '.label')
                label_lines = zf.open(full_path).readlines()
                file_name = pathlib.Path(full_path).stem
                log_search = re.search(r'(L\d+)', file_name)
                logatome_name = log_search.group(1)
                speaker_search = re.search(r'(S\d+[F,M])', file_name)
                speaker_id = speaker_search.group(1)
                for line in label_lines:
                    init, end, phone, conf_score = line.decode('ISO-8859-1').split()
                    if phone == logatomes_info[logatome_name]['phones'][1]:  # central phone
                        onset = int(init) / 10000  # ns
                        offset = int(end) / 10000
                        timestamps[file_name] = {'vowel_onset': onset, 'vowel_offset': offset, 'vowel': phone,
                                                 'speaker': speaker_id,
                                                 'details': {'phones': logatomes_info[logatome_name]['phones'],
                                                             'language': 'de', 'logatome': logatome_name}}

    return timestamps


def create_corpus_info_dict(corpus_path: Union[str, pathlib.Path], zip_paths: Union[List[str], List[pathlib.Path]],
                                 corpus_info_out_path: Union[str, pathlib.Path],
                                 context: Optional[str] = 'cvc') -> None:

    logatomes_dict = _read_logatomes_info(corpus_path)
    filtered_logatomes = _filter_logatomes(logatomes_dict, context=context)
    audio_paths = obtain_audio_paths(zip_paths, filtered_logatomes)
    corpus_info = _get_corpus_info_dict(corpus_path, audio_paths, logatomes_dict)

    folder_path = pathlib.Path(corpus_info_out_path).parent
    folder_path.mkdir(parents=True, exist_ok=True)

    with open(corpus_info_out_path, 'wb') as data_file:
        pickle.dump(corpus_info, data_file)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Script to create corpus info file (dictionary) for the '
                                                 'OLLO corpus. '
                                                 '\nUsage: python preprocess_hillenbrands_corpus.py '
                                                 '--corpus_path path_OLLO_corpus '
                                                 '--audios_zip_path path_zip_with_trials '
                                                 '--output_path path_corpus_info_file ')

    parser.add_argument('--corpus_path', type=str, required=True)
    parser.add_argument('--audios_zip_path', type=str, required=True)
    parser.add_argument('--output_path', type=str, required=True)

    args = parser.parse_args()

    create_corpus_info_dict(args.corpus_path, [args.audios_zip_path], args.output_path)  # TODO accept several zip files
