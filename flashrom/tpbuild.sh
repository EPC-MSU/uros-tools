#!/bin/sh

rm -rf libftdi libusb &&
rm -rf build &&

svn export https://team.t-platforms.ru/svn/src/vendor/libftdi/mingw32/0.18 libftdi &&
svn export https://team.t-platforms.ru/svn/src/vendor/libusb/win32-bin/1.2.4.0 libusb &&

make CC=i586-mingw32msvc-gcc \
     STRIP=i586-mingw32msvc-strip \
     AR=i586-mingw32msvc-ar \
     RANLIB=i586-mingw32msvc-ranlib \
     CPPFLAGS="-Ilibusb/include -Ilibftdi/include" \
     LDFLAGS="-Llibusb/lib/gcc -Llibftdi/lib" &&

mkdir build &&
i586-mingw32msvc-strip flashrom.exe &&
mv flashrom.exe build/ &&
cp libftdi/dll/libftdi.dll build/ &&

make clean &&

make CC="gcc -m32" &&
strip flashrom &&
mv flashrom build/flashrom-centos6.2.i686

