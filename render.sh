#!/bin/sh

# render the presentation from the MD file

cd scripts/md
python render.py
echo "Slides written to presentation-output.html"
cd ../..
