# kotatoimg

A docker image made by copying the Linux workflow that helps in building Kotatogram Desktop, tested on an arm64/aarch64 system.
Also read [Kotatogram's linux build instructions](https://github.com/kotatogram/kotatogram-desktop/blob/dev/docs/building-linux.md)

## Creating the Image

Clone and go to `kotatoimg`, then run

```bash
docker build -t kotatoimg .
```

## Building Kotatogram Desktop

Go to the root of kotatogram-desktop's repository and run

```bash
docker run --rm -v $(pwd):/ktg kotatoimg \
    bash Telegram/build/docker/centos_env/build.sh \
    -DDESKTOP_APP_USE_PACKAGED_LAZY=ON \
    -DDESKTOP_APP_DISABLE_CRASH_REPORTS=ON
```

If you want a debug build, run

```bash
docker run --rm -v $(pwd):/ktg -e DEBUG=1 kotatoimg \
    bash Telegram/build/docker/centos_env/build.sh \
    -DDESKTOP_APP_USE_PACKAGED_LAZY=ON \
    -DDESKTOP_APP_DISABLE_CRASH_REPORTS=ON
```

## Creating an AppImage

Since Telegram likes to compile everything, we'll need to create an appimage. While in kotatogram-desktop, run

```bash
docker run --rm -v $(pwd):/ktg kotatoimg build-appimage
```

Likewise, if you want a debug build then run

```bash
docker run --rm -v $(pwd):/ktg -e DEBUG=1 kotatoimg build-appimage
```
