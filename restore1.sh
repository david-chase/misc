#!/usr/bin/env bash

rsync -avh --progress --inplace --partial --delete \
    /home/dchase/data.backup/ \
    /home/dchase/data/