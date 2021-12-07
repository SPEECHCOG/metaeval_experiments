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

Save the stimuli in the following folder structure for further analyses


```
	.
    |
    ├── IDS                      
    │   ├── utterance1.wav      
    │   ├── ...         
    │   └── utterancen.wav      
    └── ADS                      
        ├── utterance1.wav      
        ├── ...         
        └── utterancen.wav
```

## Vowel Discrimination



# Models
link to code used to trained models


# Contact 
report an issue
email
