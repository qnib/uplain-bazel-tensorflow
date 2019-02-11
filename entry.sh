#!/usr/bin/env bash

python -c 'from keras import backend as K;print(K.tensorflow_backend._get_available_gpus())'
