"""
    @date 03.03.2021
    It extracts the acoustic features from audio files and it creates h5py files for training the PC models.
"""

import io
import pathlib
import zipfile
from typing import Optional, List, Union

import h5py
import librosa
import numpy as np
import numpy.matlib as mb

__docformat__ = ['reStructuredText']
__all__ = ['extract_acoustic_features', 'create_h5py_file']


def extract_acoustic_features(file_paths: Union[List[pathlib.Path], List[str]],
                              zip_path: Optional[Union[pathlib.Path, str]] = None,
                              window_length: Optional[float] = 0.025, window_shift: Optional[float] = 0.01,
                              num_features: Optional[int] = 13, deltas: Optional[bool] = True,
                              deltas_deltas: Optional[bool] = True, cmvn: Optional[bool] = True,
                              name: Optional[str] = 'mfcc',
                              target_sampling_freq: Optional[int] = 16000) -> List[np.ndarray]:
    features = []

    window_length_sample = int(target_sampling_freq * window_length)
    window_shift_sample = int(target_sampling_freq * window_shift)

    zf = zipfile.ZipFile(zip_path) if zip_path else None

    for idx, file in enumerate(file_paths):
        if zip_path:
            with zf.open(file) as audio_file:
                file = io.BytesIO(audio_file.read())

        signal, sampling_freq = librosa.load(file, sr=target_sampling_freq)

        if name == 'mfcc':
            tmp_feats = librosa.feature.mfcc(signal, target_sampling_freq, n_mfcc=num_features,
                                             n_fft=window_length_sample, hop_length=window_shift_sample)
        else:
            tmp_feats = librosa.feature.melspectrogram(signal, target_sampling_freq, n_fft=window_length_sample,
                                                       hop_length=window_shift_sample, n_mels=num_features)

        if name == 'mfcc' and deltas:
            mfcc_tmp = tmp_feats
            mfcc_deltas = librosa.feature.delta(mfcc_tmp)
            tmp_feats = np.concatenate([tmp_feats, mfcc_deltas])
            if deltas_deltas:
                mfcc_deltas_deltas = librosa.feature.delta(mfcc_tmp, order=2)
                tmp_feats = np.concatenate([tmp_feats, mfcc_deltas_deltas])

        tmp_feats = np.transpose(tmp_feats)
        # Replace zeros
        min_feats = np.min(np.abs(tmp_feats[np.nonzero(tmp_feats)]))
        tmp_feats = np.where(tmp_feats == 0, min_feats, tmp_feats)

        if name == 'logmel':
            tmp_feats = 10 * np.log10(tmp_feats)

        # Normalisation
        if cmvn:
            # mean = np.expand_dims(np.mean(mfcc, axis=0), 0)
            # std = np.expand_dims(np.std(mfcc, axis=0), 0)
            mean = mb.repmat(np.mean(tmp_feats, axis=0), tmp_feats.shape[0], 1)
            std = mb.repmat(np.std(tmp_feats, axis=0), tmp_feats.shape[0], 1)
            tmp_feats = np.divide((tmp_feats - mean), std)

            # mfcc = (mfcc - mean) / std

        features.append(tmp_feats)
        print('{}/{} file processed'.format(idx, len(file_paths)))
        print(tmp_feats.shape)

    if zip_path:
        zf.close()

    return features


def create_h5py_file(output_path: str, file_paths: Union[List[pathlib.Path], List[str]], features: List[np.ndarray],
                     sample_length: int, reset_dur: Optional[int] = 0, include_indices: Optional[bool] = False) -> None:
    file_id = 0
    file_mapping = {}
    frame_indices = []

    for file, feature in zip(file_paths, features):
        file_mapping[file_id] = file
        frames = feature.shape[0]
        idx = np.zeros((frames, 2))
        idx[:, 0] = file_id
        idx[:, 1] = np.arange(0, frames, 1)
        frame_indices.append(idx)

        if reset_dur > 0:
            reset = np.zeros((reset_dur, 2))
            reset[:, 0] = -1
            frame_indices.append(reset)
        file_id += 1

    indices = np.concatenate(frame_indices)

    if reset_dur == 0:
        data = np.concatenate(features)
    else:
        reset = np.zeros((reset_dur, features[0].shape[-1]))
        total_files = len(features)
        [features.insert(i * 2 + 1, reset) for i in range(0, total_files)]
        data = np.concatenate(features)

    total_frames = data.shape[0]
    n_feats = data.shape[1]
    extra_frames = sample_length - (total_frames % sample_length)

    if extra_frames:
        data = np.concatenate((data, np.zeros((extra_frames, n_feats))))
        idx = np.zeros((extra_frames, 2))
        idx[:, 0] = -1
        indices = np.concatenate((indices, idx))

    total_samples = int(data.shape[0] / sample_length)
    data = data.reshape((total_samples, sample_length, -1))
    indices = indices.reshape((total_samples, sample_length, -1))

    with h5py.File(pathlib.Path(output_path), 'w') as out_file:
        out_file.create_dataset('data', data=data)
        if include_indices:
            file_mapping = np.array(list([file_mapping[i] for i in sorted(file_mapping.keys())]),
                                    dtype=h5py.special_dtype(vlen=str))
            out_file.create_dataset('file_list', data=file_mapping)
            out_file.create_dataset('indices', data=indices)
