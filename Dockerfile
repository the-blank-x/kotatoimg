FROM ubuntu:bionic
# https://github.com/kotatogram/kotatogram-desktop/blob/bbb62d743acf1f36313317ca10d53907988a544a/.github/workflows/linux-kotato.yml

ARG GIT=https://github.com
ARG QT=6_2_3
ARG CMAKE_VER=3.21.3
ARG DEBIAN_FRONTEND=noninteractive
ENV CXX g++ -static-libstdc++
WORKDIR /

# Disable man for further package installs
RUN echo "path-exclude=/usr/share/man/*" >> /etc/dpkg/dpkg.cfg.d/no_man
RUN echo "path-exclude=/usr/share/locale/*" >> /etc/dpkg/dpkg.cfg.d/no_man
RUN echo "path-exclude=/usr/share/doc/*" >> /etc/dpkg/dpkg.cfg.d/no_man

# Apt install
RUN apt-get update
RUN apt-get install software-properties-common -y
RUN add-apt-repository ppa:git-core/ppa -y
RUN apt-get install clang libglibmm-2.4-dev libicu-dev libssl-dev liblzma-dev zlib1g-dev \
    git wget autoconf automake build-essential libtool pkg-config bison yasm unzip python3-pip \
    libasound2-dev libpulse-dev libfuse2 libgtk-3-dev libgtk2.0-dev libatspi2.0-dev \
    libgl1-mesa-dev libegl1-mesa-dev libdrm-dev libgbm-dev libxkbcommon-dev libxkbcommon-x11-dev \
    libxcb1-dev libxcb-glx0-dev libxcb-icccm4-dev libxcb-image0-dev libxcb-keysyms1-dev \
    libxcb-randr0-dev libxcb-record0-dev libxcb-render0-dev libxcb-render-util0-dev \
    libxcb-res0-dev libxcb-screensaver0-dev libxcb-shape0-dev libxcb-shm0-dev \
    libxcb-sync-dev libxcb-xfixes0-dev libxcb-xinerama0-dev libxcb-xkb-dev \
    libxcb-util0-dev libx11-dev libx11-xcb-dev libxext-dev libxtst-dev libxfixes-dev \
    libxrandr-dev libxrender-dev libxdamage-dev libxcomposite-dev libwayland-dev \
    xutils-dev meson ninja-build subversion patchelf qtbase5-dev qtdeclarative5-dev qtwebengine5-dev \
    qttranslations5-l10n binutils xpra zsync desktop-file-utils libgl1-mesa-dev fuse psmisc qtchooser -y
RUN add-apt-repository ppa:ubuntu-toolchain-r/test -y
RUN apt-get update
RUN apt-get install gcc-10 g++-10 -y
RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-10 60
RUN update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-10 60
RUN update-alternatives --config gcc
RUN add-apt-repository --remove ppa:ubuntu-toolchain-r/test -y

# First setup
RUN mkdir Libraries
WORKDIR Libraries
RUN wget -O tg_owt-version.json https://api.github.com/repos/desktop-app/tg_owt/git/refs/heads/master

# Patches
RUN git clone --depth 1 $GIT/desktop-app/patches.git

# Rnnoise
RUN git clone --depth 1 https://gitlab.xiph.org/xiph/rnnoise.git
WORKDIR rnnoise
RUN ./autogen.sh
RUN ./configure --disable-examples --disable-doc
RUN make -j$(nproc)
RUN make install
WORKDIR ..

# CMake
RUN wget $GIT/Kitware/CMake/releases/download/v$CMAKE_VER/cmake-$CMAKE_VER-Linux-$(arch).sh
RUN mkdir /opt/cmake
RUN sh cmake-$CMAKE_VER-Linux-*.sh --prefix=/opt/cmake --skip-license
RUN ln -s /opt/cmake/bin/cmake /usr/local/bin
RUN rm cmake-$CMAKE_VER-Linux-*.sh
RUN cmake --version

# Meson
RUN python3 -m pip install meson==0.54.0
RUN meson --version

# Ninja
RUN git clone --depth 1 $GIT/ninja-build/ninja.git
WORKDIR ninja
RUN cmake -Bbuild
RUN cmake --build build
RUN mv build/ninja /usr/local/bin
WORKDIR ..
RUN rm -rf ninja
RUN ninja --version

# MozJPEG
RUN git clone -b v4.0.3 --depth=1 $GIT/mozilla/mozjpeg.git
WORKDIR mozjpeg
RUN cmake -Bbuild -GNinja . -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local -DWITH_JPEG8=ON -DPNG_SUPPORTED=OFF
RUN cmake --build build --parallel
RUN cmake --install build
WORKDIR ..
RUN rm -rf mozjpeg

# Opus
RUN git clone -b v1.3.1 --depth=1 $GIT/xiph/opus.git
WORKDIR opus
RUN ./autogen.sh
RUN ./configure
RUN make -j$(nproc)
RUN make install
WORKDIR ..

# VPX build
RUN git clone -b v1.11.0 --depth=1 $GIT/webmproject/libvpx.git
WORKDIR libvpx
RUN ./configure --prefix=/usr --disable-examples --disable-unit-tests --disable-tools --disable-docs --enable-shared --disable-static --enable-vp8 --enable-vp9 --enable-webm-io
RUN make -j$(nproc)
RUN make DESTDIR="$(pwd)/../vpx-cache" install
WORKDIR ..
RUN rm -rf libvpx

# VPX install
RUN cp -R vpx-cache/. /
RUN ldconfig

# FFMpeg build
RUN git clone -b release/4.4 --depth=1 $GIT/FFMpeg/ffmpeg.git
WORKDIR ffmpeg
RUN ./configure --disable-static --disable-debug --disable-programs --disable-doc --disable-network --disable-autodetect --disable-encoders --disable-muxers --disable-bsfs --disable-protocols --disable-devices --disable-filters --enable-shared --enable-libopus --enable-libvpx --enable-protocol=file --enable-encoder=libopus --enable-muxer=ogg --enable-muxer=opus
RUN make -j$(nproc)
RUN make DESTDIR="$(pwd)/../ffmpeg-cache" install
WORKDIR ..
RUN rm -rf ffmpeg

# FFMpeg install
RUN cp -R ffmpeg-cache/. /
RUN ldconfig

# OpenAL Soft
RUN git clone -b fix_pulse_default --depth=1 $GIT/telegramdesktop/openal-soft.git
WORKDIR openal-soft
RUN cmake -B build -GNinja -DCMAKE_BUILD_TYPE=Release -DALSOFT_EXAMPLES=OFF -DALSOFT_TESTS=OFF -DALSOFT_UTILS=OFF -DALSOFT_CONFIG=OFF
RUN cmake --build build --parallel
RUN cmake --install build
RUN ldconfig
WORKDIR ..
RUN rm -rf openal-soft

# Libepoxy
RUN git clone -b 1.5.9 --depth=1 $GIT/anholt/libepoxy.git
WORKDIR libepoxy
RUN git apply ../patches/libepoxy.patch
RUN meson build --buildtype=release --default-library=static -Dtests=false
RUN meson compile -C build
RUN meson install -C build
WORKDIR ..
RUN rm -rf libepoxy

# QT6 build
RUN git clone -b v6.2.3 --depth=1 git://code.qt.io/qt/qt5.git qt_${QT}
WORKDIR qt_${QT}
RUN perl init-repository --module-subset=qtbase,qtwayland,qtimageformats,qtsvg,qt5compat,qttools
WORKDIR qtbase
RUN find ../../patches/qtbase_${QT} -type f -print0 | sort -z | xargs -r0 git apply
WORKDIR ../qtwayland
RUN find ../../patches/qtwayland_${QT} -type f -print0 | sort -z | xargs -r0 git apply
WORKDIR ../qt5compat
RUN find ../../patches/qt5compat_${QT} -type f -print0 | sort -z | xargs -r0 git apply
WORKDIR ..
RUN ./configure -prefix /usr/local -release -opensource -confirm-license -qt-libpng -qt-harfbuzz -qt-pcre -no-feature-xcb-sm -no-feature-highdpiscaling -openssl-linked -nomake examples -nomake tests
RUN cmake --build . --parallel
RUN DESTDIR="$(pwd)/../qt-cache" cmake --install .
WORKDIR ..
RUN rm -rf qt_${QT}
RUN cp -R qt-cache/. /
RUN ldconfig

# Qt6Gtk2
RUN git clone -b 0.1 --depth=1 $GIT/trialuser02/qt6gtk2.git
WORKDIR qt6gtk2
RUN wget https://github.com/trialuser02/qt6gtk2/commit/3d2cf8cbade92a175b2c878090f5f44a1b8a395c.patch
RUN git apply 3d2cf8cbade92a175b2c878090f5f44a1b8a395c.patch
RUN qmake
RUN make -j$(nproc)
RUN make install
WORKDIR ..
RUN rm -rf qt6gtk2

# Qt6Ct
RUN git clone -b 0.5 --depth=1 $GIT/trialuser02/qt6ct.git
WORKDIR qt6ct
RUN cmake -B build -GNinja -DCMAKE_BUILD_TYPE=Release
RUN cmake --build build --parallel
RUN cmake --install build
WORKDIR ..
RUN rm -rf qt6ct

# Kvantum
RUN git clone -b V1.0.0 --depth=1 $GIT/tsujan/Kvantum.git
WORKDIR Kvantum/Kvantum
RUN cmake -B build -GNinja -DCMAKE_BUILD_TYPE=Release -DENABLE_QT5=OFF
RUN cmake --build build --parallel
RUN cmake --install build
WORKDIR ../..
RUN rm -rf Kvantum

# WebRTC
RUN mkdir tg_owt
WORKDIR tg_owt
RUN git init
RUN git remote add origin $GIT/desktop-app/tg_owt.git
RUN git fetch --depth=1 origin 4cba1acdd718b700bb33945c0258283689d4eac7
RUN git reset --hard FETCH_HEAD
RUN git submodule init
RUN git submodule update
WORKDIR src/third_party/pipewire
RUN meson build -Dspa-plugins=disabled
WORKDIR ../../..
RUN cmake -B build -GNinja . -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DTG_OWT_DLOPEN_PIPEWIRE=ON
RUN cmake --build build --parallel
WORKDIR ..
ENV tg_owt_DIR /Libraries/tg_owt/build

# linuxdeployqt (custom)
RUN git clone --depth 1 $GIT/probonopd/linuxdeployqt.git
WORKDIR linuxdeployqt
RUN qtchooser -run-tool=qmake -qt=5
RUN make
RUN make install
WORKDIR ..
RUN rm -rf linuxdeployqt

# appimagetool (custom)
RUN wget -O appimagetool https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-$(arch).AppImage
RUN chmod +x appimagetool
# no fuses? insert pleading emoji
RUN ./appimagetool --appimage-extract
RUN rm appimagetool
RUN mv squashfs-root appimagetool
RUN ln -s $(pwd)/appimagetool/AppRun /usr/local/bin/appimagetool

COPY make-appimage /usr/local/bin/
WORKDIR ../ktg
