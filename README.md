# MetaEval Experiments
This repository contains the code to replicate the experiments for the 
infant-direct speech (IDS) preference and vowel discrimination capabilities 
reported in the manuscript "Introducing meta-analysis in the evaluation of 
computational models of infant language development". Replication can be
either from scratch or from the precomputed results. 

For replication from scratch, you will need to download the data as explain 
in [Corpora](#corpora) section, train the models from scratch following the 
instructions on [Models](https://github.com/SPEECHCOG/metaeval_dev_trajectories) 
and generate the predictions as explained in [Predictions](#predictions), and 
then run the experiments as explained in [Run test](#run-tests) and [Obtain 
effect sizes](#obtain-effect-sizes) sections.

For replication from the precomputed results, you can directly follow the 
instructions in [Obtain effect sizes](#obtain-effect-sizes). This will 
reproduce figures 5.a, 5.b and 5.c in the manuscript.

# Requirements

The code was developed using Python 3.8, TensorFlow 2.1.0 and R version
4.1.1

To execute the python code  the dependencies are specified in 
`requirements.yml` for conda the environment. To create the environment 
run:

```
conda env create -f requirements.yml
```

use `requirements_across_platforms.yml` if you find problems with 
`requirements.yml`

Then you can activate the conda environment for excuting the code

```
conda activate metaeval_env
```

Then you will to clone this repository, for example:

```
git clone git@github.com:SPEECHCOG/metaeval_experiments.git
```

# Corpora
In order to run the experiments, you will need to download the stimuli
for each test.

## IDS Preference data
The stimuli employed for this test correspond to the utterances recorded
in the [ManyBabies experiment](https://manybabies.github.io/)

You can download stimuli from the 
[ManyBabies1 repository](https://osf.io/re95x/) in ''ManyBabies 1: Stimuli 
Creation and Norming'' under `OSF Storage`. We selected the 120 utterances
per speech style based on the list available on 
[https://osf.io/ua3yh/](https://osf.io/ua3yh/) tabs `AD selected` and
`ID selected`. The final 240 recordings are available upon request if necessary.

Save the stimuli using a folder structure like the example below.


```
.
|
├── IDS                      
│   ├── utterance1.wav      
│   ├── ...         
│   └── utteranceN.wav      
└── ADS                      
	├── utterance1.wav      
	├── ...         
	└── utteranceN.wav
```

## Vowel Discrimination data
The vowel discrimination task utilises three corpora for the vowel 
contrasts: Hillenbrand's corpus, OLLO corpus and isolated vowel corpus 
(IVC). 

In order to run the experiment, you will need to download 
all three. 

### Hillenbrand's Corpus

This corpus consists of /hVd/ contexts for 12 American English vowels. 
In the experiment is used for native vowel contrasts.

The original dataset can be downloaded from 
[http://homepages.wmich.edu/~hillenbr/voweldata.html](http://homepages.wmich.edu/~hillenbr/voweldata.html)

For preprocessing you will need meta-data files and wav files. That is:
- [`iddata.dat.txt`](https://homepages.wmich.edu/~hillenbr/voweldata/iddata.dat)
- [`timedata.dat.txt`](https://homepages.wmich.edu/~hillenbr/voweldata/timedata.dat)
- [`men.zip`](https://homepages.wmich.edu/~hillenbr/voweldata/men.zip)
- [`women.zip`](https://homepages.wmich.edu/~hillenbr/voweldata/women.zip)
- [`kids.zip`](https://homepages.wmich.edu/~hillenbr/voweldata/kids.zip)

Unzip the files in the same folder.

### OLLO Corpus

This corpus consists of simple non-sense CVC and VCV contexts spoken by:
- 40 German
- 10 French

Where each logatome is spoken in six different styles:
- Load speaking effort
- Soft speaking effort
- Fast speaking rate
- Slow speaking rate
- Rising pitch (question)
- Normal

This corpus was employed for non-native vowel contrasts.

For the experiments you will need to download a subset of this corpus,
[OLLO2.0_NO.ZIP](http://medi.uni-oldenburg.de/ollo/html/download.html) 
and the meta-data: OLLO2.0_README.ZIP and OLLO2.0_LABELS.ZIP, also 
available in the previous link.

### Isolate Vowel Corpus
This corpus contains isolated vowels synthesised with 
[MBROLA voices](https://github.com/numediart/MBROLA-voices).

It includes vowels from Dutch, French, German and Japanese (non-native
vowel contrasts) and English (native vowel contrasts).

You can download wav files and corpus_info binary file from 
[IVC repository](https://github.com/SPEECHCOG/isolated_vowels_corpus)

## Preprocessing

Once you have all the corpora, the input data for models and corpora
information files can be created. The procedures are similar for both
experiments. Activate the conda environment before executing python
scripts.

### IDS Preference data processing

Create input data for models. Place yourself in the main folder of the repository before executing the 
following commands. 

```
cd ids_preference
python trial_processing/create_input_features.py --trials_path path_wav_files_trials --output_path path_h5py_output_file

```

Where `path_wav_files_trials` is the path to the folder containing the  IDS/ADS folders with
the wav files. Use the same folder structure as described in 
[IDS Preference data](#ids-preference-data) section.

### Vowel Discrimination data processing

First create corpora information files and then create the input 
features for models. 

Note: IVC corpus_info.pickle is available in the corpus repository.
Place yourself in the main folder of the repository before executing the 
following commands.

```
cd vowel_discrimination
```

#### Hillenbrand's corpus

1. Create corpus_info.pickle file. 

```
python corpus_processing/preprocess_hillenbrands_corpus.py --corpus_path path_main_folder_corpus --output_path path_corpus_info_file
```

Where `path_main_folder_corpus` is the path to the main folder of the corpus. 
This folder should contain the meta-data files and the wav files. The structure
of the folder should be similar to:

```
Hillenbrand_vowel_corpus/
├── iddata.dat.txt
├── kids
├── kids.zip
├── men
├── men.zip
├── timedata.dat.txt
├── women
└── women.zip

```

2. Create input features for model

```
python corpus_processing/create_input_features.py --corpus hc --audio_path path_zip_or_folder_with_audio_files --output_path path_h5py_output_file --corpus_info_path path_to_corpus_info 
```
Where `path_zip_or_folder_with_audio_files` is the path to the zip file or folder with the wav files.

#### OLLO corpus

1. Create corpus_info.pickle file

```
python corpus_processing/preprocess_ollo_corpus.py -corpus_path path_main_folder_corpus --audios_zip_path path_zip_with_trials --output_path path_corpus_info_file
```
Where `path_main_folder_corpus` is the path to the main folder of the corpus, and
`audios_zip_path` is the path to the zip file with the audio files. The structure of
the main folder should be similar to:

```
OLLO/
├── OLLO2.0_LABELS.ZIP
├── OLLO2.0_NO.ZIP
└── OLLO2.0_README.ZIP
```

2. Create input features for model

```
python corpus_processing/create_input_features.py --corpus oc --audio_path path_zip_or_folder_with_audio_files --output_path path_h5py_output_file --corpus_info_path path_to_corpus_info 
```

Where `audio_path` is the path to the zip file `OLLO2.0_NO.ZIP` with the wav files.

#### IVC corpus
1. Create input features for model

```
python corpus_processing/create_input_features.py --corpus ivc --audio_path path_zip_or_folder_with_audio_files --output_path path_h5py_output_file
```

Where `path_main_folder_corpus` is the path to the folder with wav files of the Isolated Vowels Corpus.

# Models
We trained Autoregressive Predictive Coding (APC) and Contrastive
Predictive Coding (CPC) models with 
[LibriSpeech](https://www.openslr.org/12/) 960 hours and [SpokenCOCO](https://groups.csail.mit.edu/sls/downloads/placesaudio/index.cgi)
742 hours. Example of untrained, and 18th epoch trained APC models 
can be found in `models` folder.

Code to train models can be found on 
[PC models](https://github.com/SPEECHCOG/metaeval_dev_trajectories).

## Predictions for Vowel Discrimination
For the vowel discrimination test, you will need to calculate the 
encoded stimulus representations before calculating the distance between
any pair of trials.

To obtain the prediction files execute. Place yourself in the main folder of the repository before executing the 
following commands:

```
cd vowel_discrimination
python pc_predictions_calculation/calculate_pc_predictions.py --input_features_path path_input_features_file --output_path path_h5py_predictions_file --model_path path_pc_model_file --pc_model [apc|cpc]
```

# Run tests
Once you have input features, models and predictions 
(for vowel discrimination), you can calculate the dependent variables
according to each test. 

## Obtain dependent variables
### IDS Preference
By executing the next command you will get the csv files with the 
attentional preference score per frame and trials that will later be
used to calculate the effect size. Place yourself in the main folder 
of the repository before executing the following commands.

```
cd ids_preference
python pc_attentional_score_calculation/obtain_attentional_scores.py --model_path h5py_path --input_path path_to_h5py_input_features --output_csv_path path_output_csv_file --model_type [apc|cpc]
```

### Vowel Discrimination
Similarly, for the vowel discrimination you will need to create the 
csv files with the DTW distances per contrast.

For that you need to provide the details of input features, predictions,
corpus information file and details of output file paths, and type 
of test (basic or basic_non_native). Please follow the example file 
`vowel_discrimination/evaluation_protocol/tests_setups/default_configuration.json`.

Place yourself in the main folder of the repository before executing the 
following commands.

```
cd vowel_discrimination
python evaluation_protocol/tests_setups/test_vowel_discrimination.py --config path_json_config_file

```

## Obtain effect sizes
To obtain the effect sizes, you will need to run the R scripts. We 
recommend the use of [RStudio](https://www.rstudio.com/) for this section. 

You can replicate the results of the manuscript by employing the csv 
files already available in the folder `test_results_large_apc`
in `r_scripts/<test>/test_results_large_apc`. Alternatively you can copy the 
csv files previously generate in that folder. 

You are ready to run the scripts to obtain the effect sizes and plots
as in the manuscript. For the IDS preference test: 
`r_scripts/ids_preference/obtain_dev_trajectories.R`and for the vowel
discrimination test: `r_scripts/vowel_discrimination/obtain_dev_trajectories.R`

# References

The ManyBabies Consortium. (2020). Quantifying sources of variability 
in infancy research using the infant-directed speech preference. 
Advances in Methods and Practices in Psychological Science (AMPPS), 
3(1), 24-52. DOI: 10.1177/2515245919900809

James Hillenbrand, Laura A. Getty, Michael J. Clark, and Kimberlee 
Wheeler , "Acoustic characteristics of American English vowels", The 
Journal of the Acoustical Society of America 97, 3099-3111 (1995) 
https://doi.org/10.1121/1.411872

Meyer BT, Jürgens T, Wesker T, Brand T, Kollmeier B. 
Human phoneme recognition depending on speech-intrinsic variability. 
J Acoust Soc Am. 2010 Nov;128(5):3126-41. doi: 10.1121/1.3493450. 
PMID: 21110608.

# Citing this work

María Andrea Cruz Blandón, Alejandrina Cristia, Okko Räsänen. (2023). 
Introducing meta-analysis in the evaluation of computational models of infant 
language development. Accepted for publication in Cognitive Science Journal

# Contact 
If you find any issue please report it on the 
[issues section](https://github.com/SPEECHCOG/metaeval_experiments/issues) 
in this repository. Further comments can be sent to 
`maria <dot> cruzblandon <at> tuni <dot> fi`

