ARG DOCKER_REGISTRY=docker.io
ARG FROM_IMG_REPO=qnib
ARG FROM_IMG_NAME=uplain-bazel
ARG FROM_IMG_TAG=2018-12-23.1
ARG FROM_IMG_HASH=""

## git clone within external image
FROM alpine AS tfdown
ARG TF_VER=v1.12.0
RUN apk --update add git
RUN git clone https://github.com/tensorflow/tensorflow /opt/tensorflow
WORKDIR /opt/tensorflow
RUN git checkout -b ${TF_VER} ${TF_VER}
##END git clone within external image

FROM ${DOCKER_REGISTRY}/${FROM_IMG_REPO}/${FROM_IMG_NAME}:${FROM_IMG_TAG}${DOCKER_IMG_HASH}

ENV DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NONINTERACTIVE_SEEN=true
ARG TF_VER=1.12.0

WORKDIR /opt/tensorflow
RUN apt-get update \
 && apt-get install --no-install-recommends -y vim \
 && rm -rf /var/lib/apt/lists/*
RUN apt-get update \
 && apt-get install --no-install-recommends -y python-setuptools python3-setuptools python3-pip libceres-dev  libc-ares-dev python3-pycares \
 && rm -rf /var/lib/apt/lists/* \
 && pip3 install wheel=0.32.3 keras_applications==1.0.4 keras_preprocessing==1.0.2
RUN apt-get update \
 && apt-get install  -y python3-numpy python3-dev libpython3-dev \
 && rm -rf /var/lib/apt/lists/*
COPY --from=tfdown /opt/tensorflow /opt/tensorflow
RUN apt-get update \
 && apt-get install  -y python-numpy python-dev libpython-dev \
 && rm -rf /var/lib/apt/lists/*
COPY bazelrc/v${TF_VER} /opt/tensorflow/.bazelrc
RUN bazel build --config=opt --copt="-mtune=generic" --force_python=PY3 //tensorflow/tools/pip_package:build_pip_package
RUN ./bazel-bin/tensorflow/tools/pip_package/build_pip_package /opt/
RUN pip3 install /opt/tensorflow-${TF_VER}-cp36-cp36m-linux_x86_64.whl
#RUN bazel fetch \
#            --incompatible_remove_native_http_archive=false \
#            --incompatible_package_name_is_a_function=false \
#            //tensorflow/tools/pip_package:build_pip_package
#RUN bazel test -c opt -- //tensorflow/... -//tensorflow/compiler/... -//tensorflow/lite/...
#-c opt --copt=-march="broadwell" --copt=-O3
