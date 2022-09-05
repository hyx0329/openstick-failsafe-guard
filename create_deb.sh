#!/usr/bin/env -S fakeroot sh

PACKAGE=openstick-utils

cp -r package ${PACKAGE}

PREFIX=${PACKAGE} make install-all

dpkg-deb --build ${PACKAGE}

rm -rf ${PACKAGE}

