# MetaEval Experiments
This repository contains the code to replicate the experiments for the 
infant-direct speech (IDS) preference and vowel discrimination capabilities 
reported in the manuscript "Evaluation of computational models of infant 
language development against robust empirical data from meta-analyses: 
what, why, and how?"

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

# Corpora
In order to run the experiments, you will need to download the stimuli
for each test.

## IDS Preference
The stimuli employed for this test correspond to the utterances recorded
in the (ManyBabies experiment)[https://manybabies.github.io/]

You can download stimuli from the 
(ManyBabies1 repository)[https://osf.io/re95x/]. List of ADS and IDS 
utterances selected available on 
(https://osf.io/ua3yh/)[https://osf.io/ua3yh/]. 

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

## Vowel Discrimination
The vowel discrimination task utilises three corpora for the vowel 
contrasts: Hillenbrand's corpus, OLLO corpus and isolated vowel corpus 
(IVC). 

In order to run the experiment, you will need to download 
all three. 

### Hillenbrand's Corpus

This corpus consists of /hVd/ contexts for 12 American English vowels. 
In the experiment is used for native vowel contrasts.

The original dataset can be downloaded from 
(http://homepages.wmich.edu/~hillenbr/voweldata.html)
[http://homepages.wmich.edu/~hillenbr/voweldata.html]

For preprocessing you will need meta-data files and wav files.

### OLLO Corpus

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

This corpus was employed for non-native vowel contrasts.

For the experiments you will need to download a subset of this corpus,
(OLLO2.0_NO.ZIP)[http://medi.uni-oldenburg.de/ollo/html/download.html] 
and the meta-data: OLLO2.0_README.ZIP and OLLO2.0_LABELS.ZIP, also 
available in the previous link.

### Isolate Vowel Corpus
This corpus contains isolated vowels synthesised with (MBROLA voices)
[https://github.com/numediart/MBROLA-voices].

It includes vowels from Dutch, French, German and Japanese (non-native
vowel contrasts) and English (native vowel contrasts).

You can download wav files and corpus_info binary file from 
(IVC repository)[]

## Preprocessing

Once you have all the corpora, the input data for models and corpora
information files can be created. The procedures are similar for both
experiments. Activate the conda environment before executing python
scripts.

### IDS Preference

Create input data for models

```
cd ids_preference
python trial_processing/create_input_features.py --trials_path path_wav_files_trials --output_path path_h5py_output_file

```

### Vowel Discrimination

First create corpora information files and then create the input 
features for models. 

Note: IVC corpus_info.pickle is available in the corpus repository.

```
cd vowel_discrimination
```

#### Hillenbrand's corpus

1. Create corpus_info.pickle file 

```
python corpus_processing/preprocess_hillenbrands_corpus.py --corpus_path path_main_folder_corpus --output_path path_corpus_info_file
```

2. Create input features for model

```
python corpus_processing/create_input_features.py --corpus hc --audio_path path_zip_or_folder_with_audio_files --output_path path_h5py_output_file --corpus_info_path path_to_corpus_info 
```

#### OLLO corpus

1. Create corpus_info.pickle file

```
python corpus_processing/preprocess_hillenbrands_corpus.py -corpus_path path_main_folder_corpus --audios_zip_path path_zip_with_trials --output_path path_corpus_info_file
```

2. Create input features for model

```
python corpus_processing/create_input_features.py --corpus oc --audio_path path_zip_or_folder_with_audio_files --output_path path_h5py_output_file --corpus_info_path path_to_corpus_info 
```

#### IVC corpus
1. Create input features for model

```
python corpus_processing/create_input_features.py --corpus ivc --audio_path path_zip_or_folder_with_audio_files --output_path path_h5py_output_file
```

# Models



# Citing this work



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


# Contact 
report an issue
email
