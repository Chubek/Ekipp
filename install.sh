#!/usr/bin/env sh

mkdir -p /tmp/ekipp-install && cd /tmp/ekipp-install

wget https://github.com/Chubek/Ekipp/releases/download/v1.0/ekipp-v1.0-dist.tar.gz

tar -xvzf ekipp-v1.0-dist.tar.gz 

make dist && sudo make install

cd ~

rm -r /tmp/ekipp-install

echo "Successfully install Ekipp, type in 'man 1 ekipp' to view the manual"
