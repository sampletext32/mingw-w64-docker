FROM ubuntu:22.04

LABEL org.opencontainers.image.source="https://github.com/sampletext32/mingw-w64-docker"
LABEL org.opencontainers.image.title="mingw-w64-docker"

WORKDIR /mnt

ENV MINGW=/mingw

ARG PKG_CONFIG_VERSION=0.29.2
ARG CMAKE_VERSION=3.30.2
ARG BINUTILS_VERSION=2.43.1
ARG MINGW_VERSION=12.0.0
ARG GCC_VERSION=14.2.0
ARG NASM_VERSION=2.16.03
ARG NVCC_VERSION=12.2.1

SHELL [ "/bin/bash", "-c" ]

RUN set -ex
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get upgrade --no-install-recommends -y \
    && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
        apt-transport-https \
        ca-certificates \
        gcc \
        g++ \
        zlib1g-dev \
        libssl-dev \
        libgmp-dev \
        libmpfr-dev \
        libmpc-dev \
        libisl-dev \
        libssl3 \
        libgmp10 \
        libmpfr6 \
        libmpc3 \
        libisl23 \
        xz-utils \
        ninja-build \
        texinfo \
        meson \
        gnupg \
        bzip2 \
        patch \
        gperf \
        bison \
        file \
        flex \
        make \
        yasm \
        curl \
        wget \
        zip \
        git

RUN wget -q https://pkg-config.freedesktop.org/releases/pkg-config-${PKG_CONFIG_VERSION}.tar.gz -O - | tar -xz
RUN wget -q https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz -O - | tar -xz
RUN wget -q https://ftp.gnu.org/gnu/binutils/binutils-${BINUTILS_VERSION}.tar.xz -O - | tar -xJ
RUN wget -q https://sourceforge.net/projects/mingw-w64/files/mingw-w64/mingw-w64-release/mingw-w64-v${MINGW_VERSION}.tar.bz2 -O - | tar -xj
RUN wget -q https://ftp.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.xz -O - | tar -xJ
RUN wget -q https://www.nasm.us/pub/nasm/releasebuilds/${NASM_VERSION}/nasm-${NASM_VERSION}.tar.xz -O - | tar -xJ

RUN mkdir -p ${MINGW}/include ${MINGW}/lib/pkgconfig
RUN chmod 0777 -R ${MINGW}

WORKDIR pkg-config-${PKG_CONFIG_VERSION}
RUN ./configure \
        --prefix=/usr/local \
        --with-pc-path=${MINGW}/lib/pkgconfig \
        --with-internal-glib \
        --disable-shared \
        --disable-nls

RUN make -j`nproc`
RUN make install
WORKDIR ..

WORKDIR cmake-${CMAKE_VERSION}
RUN ./configure \
        --prefix=/usr/local \
        --parallel=`nproc`

RUN make -j`nproc`
RUN make install
WORKDIR ..
    
WORKDIR binutils-${BINUTILS_VERSION}
RUN ./configure \
        --prefix=/usr/local \
        --target=x86_64-w64-mingw32 \
        --disable-shared \
        --enable-static \
        --disable-lto \
        --disable-plugins \
        --disable-multilib \
        --disable-nls \
        --disable-werror \
        --with-system-zlib

RUN make -j`nproc`
RUN make install
WORKDIR ..
    
RUN mkdir mingw-w64
WORKDIR mingw-w64
RUN ../mingw-w64-v${MINGW_VERSION}/mingw-w64-headers/configure \
        --prefix=/usr/local/x86_64-w64-mingw32 \
        --host=x86_64-w64-mingw32 \
        --enable-sdk=all

RUN make install
WORKDIR ..

RUN mkdir gcc
WORKDIR gcc
RUN ../gcc-${GCC_VERSION}/configure \
        --prefix=/usr/local \
        --target=x86_64-w64-mingw32 \
        --enable-languages=c,c++ \
        --disable-shared \
        --enable-static \
        --enable-threads=posix \
        --with-system-zlib \
        --enable-libgomp \
        --enable-libatomic \
        --enable-graphite \
        --disable-libstdcxx-pch \
        --disable-libstdcxx-debug \
        --disable-multilib \
        --disable-lto \
        --disable-nls \
        --disable-werror

RUN make -j`nproc` all-gcc
RUN make install-gcc
WORKDIR ..

WORKDIR mingw-w64
RUN ../mingw-w64-v${MINGW_VERSION}/mingw-w64-crt/configure \
        --prefix=/usr/local/x86_64-w64-mingw32 \
        --host=x86_64-w64-mingw32 \
        --enable-wildcard \
        --disable-lib32 \
        --enable-lib64
RUN (make || make || make || make)
RUN make install
WORKDIR ..

WORKDIR mingw-w64
RUN ../mingw-w64-v${MINGW_VERSION}/mingw-w64-libraries/winpthreads/configure \
        --prefix=/usr/local/x86_64-w64-mingw32 \
        --host=x86_64-w64-mingw32 \
        --enable-static \
        --disable-shared

RUN make -j`nproc`
RUN make install
WORKDIR ..

WORKDIR gcc 
RUN make -j`nproc` 
RUN make install 
WORKDIR .. 

WORKDIR nasm-${NASM_VERSION}
RUN ./configure --prefix=/usr/local
RUN make -j`nproc`
RUN make install
WORKDIR ..

RUN rm -r pkg-config-${PKG_CONFIG_VERSION}
RUN rm -r cmake-${CMAKE_VERSION}
RUN rm -r binutils-${BINUTILS_VERSION}
RUN rm -r mingw-w64 mingw-w64-v${MINGW_VERSION}
RUN rm -r gcc gcc-${GCC_VERSION}
RUN rm -r nasm-${NASM_VERSION}

RUN apt-get remove --purge -y file gcc g++ zlib1g-dev libssl-dev libgmp-dev libmpfr-dev libmpc-dev libisl-dev
RUN apt-get remove --purge -y gnupg
RUN apt-get autoremove --purge -y
RUN apt-get clean