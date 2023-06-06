import os

import pandas as pd
import numpy as np
import pathlib
import matplotlib
import matplotlib.pyplot as plt
import seaborn as sns
from scipy import stats
from sklearn.metrics import mean_squared_error

sns.set_theme()


def get_sample_size(csv_file, group_size, upper_limit=900):
    df = pd.read_csv(csv_file)
    age_groups = np.arange(0, int(upper_limit / group_size) + 1) * group_size
    results = []
    for i in range(len(age_groups) - 1):
        tpm_df = df[df['mean_age_1'].between(age_groups[i], age_groups[i + 1], inclusive='left')]
        n_effects = len(tpm_df)
        n_participants = tpm_df.drop_duplicates(subset=['same_infant'])['n_1'].sum()
        results.append({'age_group': f'{age_groups[i]}-{age_groups[i + 1]}',
                        'n_es': n_effects,
                        'n_participants': n_participants})
    return pd.DataFrame(results)


def get_sample_size_matrix(meta_analysis_paths, age_group_size, age_upper_limit=900):
    age_groups = np.arange(0, int(age_upper_limit / age_group_size) + 1) * age_group_size
    matrix = []
    for meta_analysis in meta_analysis_paths:
        df = pd.read_csv(meta_analysis)
        tmp_results = {'capability': meta_analysis.stem}
        for i in range(len(age_groups) - 1):
            tmp_df = df[df['mean_age_1'].between(age_groups[i], age_groups[i + 1], inclusive='left')]
            n_effects = len(tmp_df)
            tmp_results[f'{age_groups[i]}-{age_groups[i + 1]}'] = n_effects
        matrix.append(tmp_results)
    return pd.DataFrame(matrix)


def get_heatmap(csv_path):
    df = pd.read_csv(csv_path, keep_default_na=False)
    df_tmp = df.loc[:, df.columns != 'Capability']

    # Remove batch checkpoints
    batch_cp = ['0.06', '0.12', '0.18', '0.24', '0.3', '0.36', '0.42', '0.48', '0.54']
    df_tmp = df_tmp.loc[:, ~df_tmp.columns.isin(batch_cp)]

    df_np = df_tmp.to_numpy()

    mask = np.where(df_np == 'N/A', True, df_np)
    mask = np.where(mask == 'n.s.', True, mask)
    mask = np.where(mask == True, True, False)

    df_heatmap = np.where(df_np == 'N/A', 20, df_np)
    df_heatmap = np.where(df_heatmap == 'n.s.', 20, df_heatmap)
    df_heatmap = df_heatmap.astype('float64')

    labels = (np.asarray([f"{l}" if l in ['N/A', 'n.s.'] else f"{float(l):.2f}" for l in df_np.flatten()])).reshape(
        df_np.shape)

    # Formatting
    fig, ax = plt.subplots(figsize=(20, 13))
    title = "Infants' data\n"

    ax.set_title(title, fontsize=24, fontweight='bold')

    heatmap = sns.heatmap(df_heatmap, linewidths=0.5, annot=labels, fmt='', vmax=0.4, ax=ax,
                cbar_kws={'label': 'Effect size', 'fraction': 0.05, 'pad': 0.01},
                annot_kws={"fontsize": 20})
    heatmap.figure.axes[-1].yaxis.label.set_size(20)

    ax.set_xticks(ax.get_xticks())
    ax.set_xticklabels(df_tmp.columns.to_list(), rotation=45, ha='right', size=20)
    ax.set_yticks(ax.get_yticks())
    caps = df.loc[:, 'Capability'].to_list()
    ax.set_yticklabels(caps)
    ax.set_yticklabels(caps, size=20, rotation=90)

    plt.xlabel("\nInfants' Age (Months)", fontsize=20, fontweight='bold')

    fig.tight_layout()
    plt.savefig('summary_table.pdf')


def get_heatmap_model(model_results_csv_path, infants_csv_path, infants_es_csv_path):
    df_inf = pd.read_csv(infants_csv_path, keep_default_na=False)
    df_model = pd.read_csv(model_results_csv_path, keep_default_na=False)
    df_inf_es = pd.read_csv(infants_es_csv_path, keep_default_na=False)

    df_inf_tmp = df_inf.loc[:, df_inf.columns != 'Capability']
    df_inf_es_tmp = df_inf_es.loc[:, df_inf_es.columns != 'Capability']

    # Remove batch checkpoints
    batch_cp = ['0.06', '0.12', '0.18', '0.24', '0.3', '0.36', '0.42', '0.48', '0.54']
    df_inf_tmp = df_inf_tmp.loc[:, ~df_inf_tmp.columns.isin(batch_cp)]
    df_inf_es_tmp = df_inf_es_tmp.loc[:, ~df_inf_es_tmp.columns.isin(batch_cp)]
    age = [float(x) for x in df_inf_tmp.columns.to_list()]

    df_inf_np = df_inf_tmp.to_numpy()
    df_inf_es_np = df_inf_es_tmp.to_numpy()

    df_model = df_model.loc[df_model.checkpoint == 'epoch']

    # Formatting & data
    # Basic format
    result_type = np.zeros((df_inf_np.shape[0], df_inf_np.shape[1]))
    annotations = np.copy(df_inf_np)
    annotations_inf = np.copy(df_inf_np)

    n_cap, n_checkpoints = df_inf_np.shape

    for i in range(n_cap):
        age_checkpoint = []
        cap_model = []
        cap_inf = []
        for j in range(n_checkpoints):
            es_inf_lb = df_inf_np[i, j]
            es_inf = df_inf_es_np[i, j]

            if i == 0:
                cap = 'IDS Preference'
            elif i == 1:
                cap = 'Vowel discr. (native)'
            else:
                cap = 'Vowel discr. (non-native)'
            es_model = df_model.loc[df_model.capability == cap].iat[j, 1]
            es_model_sig = df_model.loc[df_model.capability == cap].iat[j, 2]
            significance = '*' if es_model_sig else ''
            if not es_model_sig:
                es_model = 0

            annotations[i, j] = f'{es_model:.2f}{significance}' if es_model_sig else f'{es_model}'
            annotations_inf[i, j] = f'\n\n({es_inf_lb})' if es_inf_lb in ['N/A', 'n.s.'] else f'\n\n({float(es_inf_lb):.2f})'

            if es_inf_lb in ['N/A', 'N/C']:
                result_type[i, j] = 0
            elif es_inf_lb == 'n.s.':
                if es_model == 0:
                    result_type[i, j] = 1  # Compatible effect
                else:
                    result_type[i, j] = 2  # Non compatible effect
            else:
                es_inf = float(es_inf)
                es_inf_lb = float(es_inf_lb)

                # round to 2 decimals
                es_inf = round(es_inf, 2)
                es_inf_lb = round(es_inf_lb, 2)
                es_model = round(es_model, 2)

                age_checkpoint.append(age[j])
                cap_model.append(es_model)
                cap_inf.append(es_inf_lb)

                if es_inf > 0:
                    if es_model >= es_inf_lb:
                        result_type[i, j] = 1  # Compatible effect
                    else:
                        result_type[i, j] = 2  # Non compatible effect
                elif float(es_inf) < 0:
                    if es_model <= es_inf_lb:
                        result_type[i, j] = 1  # Compatible effect
                    else:
                        result_type[i, j] = 2  # Non compatible effect
                else:
                    if es_model == es_inf:
                        result_type[i, j] = 1  # Compatible effect
                    else:
                        result_type[i, j] = 2  # Non compatible effect

    # Plot
    fig, (ax, ax2) = plt.subplots(1, 2, figsize=(20, 13), gridspec_kw={'width_ratios': [1, 0.05]})
    title = "APC model's data\n"

    ax.set_title(title, fontsize=24, fontweight='bold')

    colours = ['#fdebde', '#9EC3D8', '#edc1bb', '#f7f5f4']
    sns.heatmap(result_type, linewidths=0.5, annot=annotations, fmt='',
                cmap=sns.color_palette(colours, as_cmap=True),
                vmax=3,
                vmin=0,
                ax=ax,
                cbar=False,
                annot_kws={"fontsize":20})

    sns.heatmap(result_type, linewidths=0.5, annot=annotations_inf, fmt='',
                cmap=sns.color_palette(colours, as_cmap=True),
                vmax=3,
                vmin=0,
                ax=ax,
                cbar=False,
                annot_kws={"fontsize": 20, 'fontstyle': 'italic'})

    sns.heatmap(np.array([0, 1, 2]).reshape(3,1),
                annot=np.column_stack(['Prediction\n(Missing reference data)', 'Compatible', 'Non compatible']).reshape(3,1),
                fmt='', cmap=sns.color_palette(colours[0:3], as_cmap=True),
                vmax=2, vmin=0, ax=ax2, cbar=False, annot_kws={"fontsize":20, "rotation": 90, 'fontstyle': 'italic'},
                xticklabels=False, yticklabels=False)

    ax.set_xticks(ax.get_xticks())
    ax.set_xticklabels(df_inf_tmp.columns.to_list(), rotation=45, ha='right', size=20)
    ax.set_yticks(ax.get_yticks())
    caps = df_inf.loc[:, 'Capability'].to_list()
    ax.set_yticklabels(caps, size=20, rotation=90)

    ax.set_xlabel("\nSimulated Age (Months)", fontsize=20, fontweight='bold')

    fig.tight_layout()
    plt.savefig('summary_table_model.pdf')


get_heatmap('./summary_table_lb.csv')
get_heatmap_model('./apc_results.csv', './summary_table_lb.csv', './summary_table_es.csv')

