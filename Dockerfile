# Base image with Ubuntu 18.04
FROM ubuntu:18.04

# Set environment variables for CUDA
ENV CUDA_VERSION=10.2

# Avoid interactive prompts during package installations
ARG DEBIAN_FRONTEND=noninteractive

# Set environment variable for installing sklearn
ENV SKLEARN_ALLOW_DEPRECATED_SKLEARN_PACKAGE_INSTALL=True

# Install essential packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
    wget \
    curl \
    ca-certificates \
    gnupg2 \
    libjpeg-dev \
    libpng-dev \
    python3 \
    python3-pip \
    python3-dev \
    libopenblas-dev \
    libomp-dev \
    libusb-1.0-0 \
    g++-7 \
    && rm -rf /var/lib/apt/lists/*

# Add CUDA GPG keys
RUN apt-key del 7fa2af80 && \
    apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/3bf863cc.pub && \
    echo "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64 /" > /etc/apt/sources.list.d/cuda.list

# Install CUDA 10.2
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    cuda-toolkit-10-2

# Set environment variables for CUDA
ENV PATH=/usr/local/cuda-10.2/bin${PATH:+:${PATH}}
ENV LD_LIBRARY_PATH=/usr/local/cuda-10.2/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
ENV CUDA_HOME=/usr/local/cuda-10.2


# INSERT NEW CODE HERE 
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    cuda-samples-10-2 && \
    mkdir -p /usr/local/cuda-10.2/include && \
    ln -s /usr/local/cuda-10.2/samples/common/inc/helper_math.h /usr/local/cuda-10.2/include/helper_math.cuh && \
    ln -s /usr/local/cuda-10.2/samples/common/inc/helper_math.h /usr/local/cuda-10.2/include/helper_math.h

    
# Install Conda
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O Miniconda3-latest-Linux-x86_64.sh \
    && bash Miniconda3-latest-Linux-x86_64.sh -b -p /opt/conda \
    && rm Miniconda3-latest-Linux-x86_64.sh \
    && /opt/conda/bin/conda init bash

# Set environment variables for Conda
ENV PATH /opt/conda/bin:$PATH

# Create and activate the Conda environment
RUN conda create -n cppf python=3.8 -y \
    && echo "source activate cppf" > ~/.bashrc

# Install PyTorch and other dependencies
RUN /opt/conda/bin/conda run -n cppf conda install pytorch=1.8.1 torchvision cudatoolkit=10.2 -c pytorch-lts -y \
    && /opt/conda/bin/conda run -n cppf pip install tqdm opencv-python scipy matplotlib open3d==0.12.0 hydra-core pyrender cupy-cuda102 PyOpenGL-accelerate OpenEXR scikit-learn plotly \
    && /opt/conda/bin/conda run -n cppf pip install "setuptools<60.0"

# Install MinkowskiEngine with CUDA support
ENV MAX_JOBS=2

RUN /opt/conda/bin/conda run -n cppf conda install -c anaconda openblas-devel \
    && git clone https://github.com/NVIDIA/MinkowskiEngine.git /opt/MinkowskiEngine \
    && cd /opt/MinkowskiEngine \
    && /opt/conda/bin/conda run -n cppf bash -c "export CXX=g++-7 CC=gcc-7 TORCH_CUDA_ARCH_LIST='6.1' && pip install . -v --no-cache-dir --global-option='--blas=openblas' --global-option='--force_cuda'"

# Install OSMesa from a .deb package with dependencies
RUN wget https://github.com/mmatl/travis_debs/raw/master/xenial/mesa_18.3.3-0.deb && \
    apt-get update && \
    apt-get install -y libffi-dev  libosmesa6-dev libllvm6.0 llvm-6.0 llvm-6.0-dev llvm-6.0-runtime llvm-6.0-tools && \
    dpkg -i ./mesa_18.3.3-0.deb || true && \
    apt-get install -f -y

# Clone and install the compatible fork of PyOpenGL
RUN git clone https://github.com/mmatl/pyopengl.git && \
    /opt/conda/bin/conda run -n cppf pip install ./pyopengl

# Set the Python path environment variable
ENV PYTHONPATH="/workspaces/CPPF-main:$PYTHONPATH"

# Set the working directory
WORKDIR /workspaces/CPPF-main

# Copy the source code into the image
COPY . .

# Default command
CMD ["bash"]