FROM dromni/nerfstudio:1.1.5
USER root
ARG UBUNTU_VERSION=22.04
ARG TORCH_VERSION=2.2.1
ARG CUDA_VERSION=12.1.1
ARG CMAKE_CUDA_ARCHITECTURES=70;75;80
ARG CMAKE_BUILD_TYPE=Release

SHELL ["/bin/bash", "-c"]

# Env variables
ENV DEBIAN_FRONTEND noninteractive

# Install necessary dependencies
RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
    apt-get update && apt-get install -y \
    git \
    build-essential \
    dos2unix \
    ffmpeg \
    libboost-program-options-dev \
    libboost-filesystem-dev \
    libboost-graph-dev \
    libboost-system-dev \
    libboost-test-dev \
    libeigen3-dev \
    libsuitesparse-dev \
    libfreeimage-dev \
    libgoogle-glog-dev \
    libgflags-dev \
    libglew-dev \
    qtbase5-dev \
    libqt5opengl5-dev \
    libcgal-dev \
    libceres-dev \
    bc \
    vim \
    apt-utils \
    ninja-build \
    wget \
    libblas-dev \
    libatlas-base-dev \
    libmetis-dev \
    libflann-dev \
    libfreeimage-dev \
    libsqlite3-dev \
    libopencv-dev \
    software-properties-common \
    unzip && \
    apt-get autoremove -y --purge && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Prepare directories
WORKDIR /opt

RUN ldconfig

# Install CMake 3.20 or higher
RUN wget https://github.com/Kitware/CMake/releases/download/v3.31.2/cmake-3.31.2-linux-x86_64.sh && \
    chmod +x cmake-3.31.2-linux-x86_64.sh && \
    ./cmake-3.31.2-linux-x86_64.sh --skip-license --prefix=/usr && \
    rm cmake-3.31.2-linux-x86_64.sh

# Build and install Ceres Solver with CUDA support
RUN git clone https://github.com/ceres-solver/ceres-solver.git /opt/ceres-solver --recursive && \
    cd /opt/ceres-solver && \
    mkdir build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF -DBUILD_EXAMPLES=OFF -DCXX11=ON -DCERES_USE_CUDA=ON -DCUDA=ON && \
    make -j$(nproc) && make install && ldconfig

# Clone and build COLMAP
RUN cd /opt && \
    git clone https://github.com/colmap/colmap.git && \
    cd colmap && \
    mkdir build && \
    cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release -DCeres_DIR=/usr/local/lib/cmake/Ceres -DBUILD_TESTING=OFF -DBUILD_EXAMPLES=OFF -DCXX11=ON -DCERES_USE_CUDA=ON -DCUDA=ON && \
    make -j$(nproc) && \
    make install

# # Clone the glomap repository
# RUN git clone --recursive https://github.com/colmap/glomap.git /opt/glomap && \
#     cd /opt/glomap && \
#     mkdir build && \
#     cd build && \
#     cmake .. -GNinja && ninja -j$(nproc) && \
#     ninja install

WORKDIR /opt

RUN git clone https://github.com/SharkWipf/nerf_dataset_preprocessing_helper.git

# Download Meshroom and put it in the folder if you work with spherical videos or images
# =======================================================================================
# https://www.fosshub.com/Meshroom.html?dwl=Meshroom-2023.3.0-linux.tar.gz
# ADD Meshroom-2023.3.0-linux.tar.gz /opt/Meshroom-2023.3.0-linux.tar.gz


RUN chown -R 777 /workspace

COPY scripts /workspace/scripts
RUN dos2unix /workspace/scripts/gsplat.sh


USER user
ENTRYPOINT [ "/bin/bash" ]
CMD ["/workspace/scripts/gsplat.sh"]