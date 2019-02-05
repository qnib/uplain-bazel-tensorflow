ARG DOCKER_REGISTRY=docker.io
ARG FROM_IMG_REPO=qnib
ARG FROM_IMG_NAME=uplain-bazel
ARG FROM_IMG_TAG=2018-12-23.1
ARG FROM_IMG_HASH=""
ARG TF_CUDA_COMPUTE_CAPABILITIES="3.7,5.2.7.0"
ARG NCCL_INSTALL_PATH=/usr/include
ARG TF_VER=1.12.0
ARG TF_CHECKOUT=v
ARG TF_EXTRA
ARG BAZEL_OPT_MARCH="native"
ARG BAZEL_OPT_MTUNE="native"
ARG BAZEL_OPTIMIZE="0"
ARG D_GLIBCXX_USE_CXX11_ABI="0"

## git clone within external image
FROM alpine AS tfdown
ARG TF_VER
ARG TF_CHECKOUT
RUN apk --update add git
RUN git clone https://github.com/tensorflow/tensorflow /opt/tensorflow
WORKDIR /opt/tensorflow
RUN git checkout ${TF_CHECKOUT}${TF_VER}
##END git clone within external image

FROM ${DOCKER_REGISTRY}/${FROM_IMG_REPO}/${FROM_IMG_NAME}:${FROM_IMG_TAG}${DOCKER_IMG_HASH}

ENV DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NONINTERACTIVE_SEEN=true
ARG TF_VER
ARG TF_CHECKOUT
ARG TF_EXTRA
ARG BAZEL_OPT_MARCH
ARG BAZEL_OPT_MTUNE
ARG BAZEL_OPTIMIZE
ARG D_GLIBCXX_USE_CXX11_ABI
ARG NCCL_INSTALL_PATH
ARG TF_CUDA_COMPUTE_CAPABILITIES

WORKDIR /opt/tensorflow
RUN apt-get update \
 && apt-get install --no-install-recommends -y vim python-numpy \
 && rm -rf /var/lib/apt/lists/*
RUN pip3 install wheel==0.32.3 keras_applications==1.0.4 keras_preprocessing==1.0.2
COPY --from=tfdown /opt/tensorflow /opt/tensorflow
COPY bazelrc/${TF_CHECKOUT}${TF_VER}${TF_EXTRA} /opt/tensorflow/.tf_configure.bazelrc
RUN echo """bazel build --cxxopt=-D_GLIBCXX_USE_CXX11_ABI='${D_GLIBCXX_USE_CXX11_ABI}' \\"""  \
 && echo """            --copt='-march=${BAZEL_OPT_MARCH}' --copt='-mtune=${BAZEL_OPT_MTUNE}' --copt='-O${BAZEL_OPTIMIZE}' \\""" \
 && echo """            --force_python=PY3 //tensorflow/tools/pip_package:build_pip_package""" \
 && bazel build --cxxopt=-D_GLIBCXX_USE_CXX11_ABI="${D_GLIBCXX_USE_CXX11_ABI}"  \
                --copt="-march=${BAZEL_OPT_MARCH}" --copt="-mtune=${BAZEL_OPT_MTUNE}" --copt="-O${BAZEL_OPTIMIZE}" \
                --force_python=PY3 //tensorflow/tools/pip_package:build_pip_package
RUN mkdir -p /opt/wheel \
 && ./bazel-bin/tensorflow/tools/pip_package/build_pip_package /opt/wheel/
RUN pip3 install $(find /opt/wheel -name "*.whl")
WORKDIR /
RUN python -c 'import tensorflow as tf;hello = tf.constant("Hello, TensorFlow!");sess = tf.Session();print(sess.run(hello))'
RUN echo "python -c 'from tensorflow.python.client import device_lib;device_lib.list_local_devices()'" >> /root/.bash_history
RUN echo "python -c 'from keras import backend as K;print(K.tensorflow_backend._get_available_gpus())'" >> /root/.bash_history
