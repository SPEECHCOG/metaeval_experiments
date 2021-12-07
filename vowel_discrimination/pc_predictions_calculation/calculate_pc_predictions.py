"""
    @date 18.05.2021
"""

__docformat__ = ['reStructuredText']
__all__ = ['create_pc_predictions_file']

import argparse
import pathlib
from typing import Union, Optional, Tuple, List

import h5py
import numpy as np
from tensorflow.keras.models import load_model, Model

from evaluation_protocol.io_module.read_predictions_and_features import read_input_features
from pc_predictions_calculation.cpc_utils import FeatureEncoder, ContrastiveLoss


def create_pc_predictions_file(model_path: Union[str, pathlib.Path], input_feats: np.ndarray,
                               output_path: Union[str, pathlib.Path], model_type: Optional[str] = 'cpc') -> None:
    import tensorflow as tf
    physical_devices = tf.config.list_physical_devices('GPU')
    for physical_device in physical_devices:
        tf.config.experimental.set_memory_growth(physical_device, enable=True)

    if model_type == 'cpc':
        model = load_model(model_path, compile=False, custom_objects={'FeatureEncoder': FeatureEncoder,
                                                                      'ContrastiveLoss': ContrastiveLoss})
        latent_layer = model.get_layer('Feature_Encoder').output
    else:
        model = load_model(model_path, compile=False)
        latent_layer = model.get_layer('latent_layer').output

    input_layer = model.get_layer('input_layer').output

    predictor = Model(input_layer, latent_layer)

    latents = predictor.predict(input_feats)

    pathlib.Path(output_path).parent.mkdir(parents=True, exist_ok=True)

    with h5py.File(output_path, 'w') as data_file:
        data_file.create_dataset('latents', data=latents)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Script to create h5py file with the pc predictions. '
                                                 '\nUsage: python calculate_pc_predictions.py '
                                                 '--input_features_path path_input_features_file '
                                                 '--output_path path_h5py_predictions_file '
                                                 '--model_path path_pc_model_file '
                                                 '--pc_model apc|cpc')

    parser.add_argument('--input_features_path', type=str, required=True)
    parser.add_argument('--output_path', type=str, required=True)
    parser.add_argument('--model_path', type=str, required=True)
    parser.add_argument('--pc_model', type=str, choices=['apc', 'cpc'], required=True)

    args = parser.parse_args()

    input_features, _, _ = read_input_features(args.input_features_path)
    create_pc_predictions_file(args.model_path, input_features, args.output_path, args.pc_model)
