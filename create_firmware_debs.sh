#!/usr/bin/env -S fakeroot sh

for i in ./firmwares/* ; do
  chown -R root:root "$i"
  dpkg-deb --build "$i"
done 

mv ./firmwares/*.deb .

