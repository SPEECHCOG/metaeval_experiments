"""
    This script contains the functions needed for calculating the attentional preference score per frame for APC and
    CPC models.

    @date 12.11.2021
"""

__docformat__ = ['reStructuredText']
__all__ = ['calculate_mae_per_frame', 'calculate_infonce_per_frame']

import pathlib
from typing import Union, List

import tensorflow as tf
from tensorflow.keras import backend as K
import numpy as np
from tensorflow.python.keras.models import load_model, Model

from cpc_utils import FeatureEncoder, ContrastiveLoss, get_negative_samples
from io_module.read_predictions_and_features import get_trials_list, \
    read_input_features


def _get_overlapped_features(input_features: np.ndarray, overlap: float) -> np.ndarray:
    sample_size = input_features.shape[1]
    features_dim = input_features.shape[-1]
    overlapped_frames = int(sample_size * overlap)
    stride = sample_size - overlapped_frames

    features = input_features.reshape((-1, features_dim))
    total_samples = features.shape[0] // stride

    final_features = np.zeros((total_samples, sample_size, features_dim))
    for idx in range(total_samples):
        segment = features[idx * stride:idx * stride + sample_size, :]
        idx_samples = segment.shape[0]
        final_features[idx, :idx_samples, :] = segment
    return final_features


def _remove_overlap(overlapped_features: np.ndarray, overlap: float, original_total_samples: int) -> np.ndarray:
    sample_size = overlapped_features.shape[1]
    features_dim = overlapped_features.shape[-1]
    overlapped_frames = int(sample_size * overlap)
    stride = sample_size - overlapped_frames

    final_features = np.zeros((original_total_samples * sample_size, features_dim))
    total_final_frames = final_features.shape[0]

    for idx_sample in range(overlapped_features.shape[0]):
        if idx_sample == 0:
            # first sample
            final_features[0:sample_size, :] = overlapped_features[idx_sample, 0:sample_size, :]
        else:
            # everything else
            init_idx = sample_size + (stride * (idx_sample - 1))
            if init_idx + stride > total_final_frames:
                last_frames = total_final_frames - init_idx
                final_features[init_idx:, :] = \
                    overlapped_features[idx_sample, overlapped_frames: overlapped_frames + last_frames, :]
            else:
                final_features[init_idx: init_idx + stride, :] = \
                    overlapped_features[idx_sample, overlapped_frames:, :]

            if init_idx + stride >= total_final_frames:
                break
    final_features = final_features.reshape((original_total_samples, sample_size, features_dim))
    return final_features


def calculate_mae_per_frame(model_path: Union[str, pathlib.Path], input_features_path: Union[str, pathlib.Path],
                            overlap: float, apc_shift: float) -> List[np.ndarray]:
    input_features, _, indices = read_input_features(input_features_path)
    overlapped_feats = _get_overlapped_features(input_features, overlap)

    physical_devices = tf.config.list_physical_devices('GPU')
    for physical_device in physical_devices:
        tf.config.experimental.set_memory_growth(physical_device, enable=True)

    model = load_model(model_path, compile=False)
    overlapped_predictions = model.predict(overlapped_feats)
    predictions = _remove_overlap(overlapped_predictions, overlap, input_features.shape[0])

    # Obtain features for each trial and then calculate MAE per trial and frame
    input_trials = get_trials_list(input_features, indices)
    predicted_trials = get_trials_list(predictions, indices)

    trials_mae = []
    for trial_idx in range(len(input_trials)):
        mae_per_frame = tf.keras.metrics.mean_absolute_error(input_trials[trial_idx][apc_shift:, :],
                                                             predicted_trials[trial_idx][:-apc_shift, :])
        trials_mae.append(mae_per_frame.numpy())

    return trials_mae


def _get_infonce_per_frame(true_latents: tf.Tensor, pred_latents: tf.Tensor, neg: int, steps: int) -> tf.Tensor:
    timesteps = true_latents.shape[1]
    total_samples = true_latents.shape[0]
    negative_samples = get_negative_samples(true_latents, neg)
    true_latents = K.expand_dims(true_latents, 0)
    targets = K.concatenate([true_latents, negative_samples], 0)
    copies = neg + 1
    logits = None
    for i in range(steps):
        if i == 0:
            # The time-steps are corresponding as is the first step.
            logits = tf.reshape(tf.einsum("stf,cstf->tsc", pred_latents[:, :, :, i], targets[:, :, :, :]), [-1])
        else:
            # We need to match the time-step taking into account the step for which is being predicted
            logits = tf.concat([logits, tf.reshape(tf.einsum("stf,cstf->tsc", pred_latents[:, :-i, :, i],
                                                             targets[:, :, i:, :]), [-1])], 0)

    # shape steps x timesteps x samples x copies (e.g., 12x(200,199,198, .., 189)xNx11)
    # the timesteps are decreasing because for each step calculation the predictions and target are shifted so we have
    # all the information needed (controlling for unknown future) to calculate the dot product between prediction and
    # target vectors
    logits = tf.reshape(logits, (-1, copies))  # shape (steps*decreasing timesteps*samples) x copies
    total_points = tf.shape(logits)[0]

    # Labels, this should be the true value, that is 1.0 for the first copy (positive sample) and 0.0 for the rest.
    label_idx = [True] + [False] * neg
    labels = tf.where(label_idx, tf.ones((total_points, copies)), tf.zeros((total_points, copies)))

    # Entropy per frame
    # shape: total_points
    entropy_per_frame_n_step = tf.nn.softmax_cross_entropy_with_logits(labels, logits)

    # Reduction (sum) across steps
    # InfoNCE is the sum across steps for each frame, since the timesteps are decreasing as steps go forward. First
    # we add zeros for the missing timesteps so the summation can be done at once.
    corrected_entropy_per_frame_n_step = None
    frames_idx = 0
    for step in range(steps):
        current_elements = total_samples * (timesteps - step)
        if step == 0:
            corrected_entropy_per_frame_n_step = entropy_per_frame_n_step[frames_idx:frames_idx+current_elements]
        else:
            missing_timesteps = total_samples * step
            frames_step = tf.concat([entropy_per_frame_n_step[frames_idx:frames_idx+current_elements],
                                     tf.zeros((missing_timesteps,))], 0)
            corrected_entropy_per_frame_n_step = tf.concat([corrected_entropy_per_frame_n_step, frames_step], 0)
        frames_idx += current_elements
    # shape: steps x timesteps x samples
    corrected_entropy_per_frame_n_step = tf.reshape(corrected_entropy_per_frame_n_step, (steps, timesteps, -1))
    infonce_per_frame = tf.math.reduce_sum(corrected_entropy_per_frame_n_step, axis=0)
    # shape: samples x timesteps x 1 (infoNCE value)
    infonce_per_frame = tf.reshape(tf.transpose(infonce_per_frame), (-1, timesteps, 1))

    return infonce_per_frame


def calculate_infonce_per_frame(model_path: Union[str, pathlib.Path], input_features_path: Union[str, pathlib.Path],
                                overlap: float, cpc_neg: int, cpc_steps: int) -> List[np.ndarray]:
    input_features, _, indices = read_input_features(input_features_path)
    overlapped_feats = _get_overlapped_features(input_features, overlap)

    physical_devices = tf.config.list_physical_devices('GPU')
    for physical_device in physical_devices:
        tf.config.experimental.set_memory_growth(physical_device, enable=True)

    model = load_model(model_path, compile=False, custom_objects={'FeatureEncoder': FeatureEncoder,
                                                                  'ContrastiveLoss': ContrastiveLoss})
    input_layer = model.get_layer('input_layer').output
    # This code fails with tf v 2.4.1 but works with v 2.1.0
    # related discussion on internet:
    # https://pretagteam.com/question/attributeerror-layer-has-no-inbound-nodes-occurred-in-tf-24-but-works-in-tf-24
    projection_layer = model.get_layer('Contrastive_Loss').get_layer('project_latent').output
    steps_projection_layer = model.get_layer('Contrastive_Loss').get_layer('project_steps').output

    predictor = Model(input_layer, [projection_layer, steps_projection_layer])

    true_latents, pred_latents = predictor.predict(overlapped_feats)
    # shape: samples x timesteps x 1
    infonce_per_frame = _get_infonce_per_frame(true_latents, pred_latents, cpc_neg, cpc_steps)
    final_infonce_per_frame = _remove_overlap(infonce_per_frame.numpy(), overlap, input_features.shape[0])

    # Arrange InfoNCE for each frame and trial
    trials_infonce = get_trials_list(final_infonce_per_frame, indices)
    for idx in range(len(trials_infonce)):
        trials_infonce[idx] = trials_infonce[idx].reshape(-1)
    return trials_infonce
