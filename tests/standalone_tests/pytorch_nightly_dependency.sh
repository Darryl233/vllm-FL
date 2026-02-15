#!/bin/sh
# This script tests if the nightly torch packages are not overridden by the dependencies

set -e
set -x

cd ..

source /opt/miniconda3/etc/profile.d/conda.sh
conda activate flagscale-inference

# check the environment
pip freeze

echo ">>> Installing nightly torch packages"
pip install --quiet torch torchvision torchaudio --pre --extra-index-url https://download.pytorch.org/whl/nightly/cu128

echo ">>> Capturing torch-related versions before requirements install"
pip freeze | grep -E '^torch|^torchvision|^torchaudio' | sort > before.txt
echo "Before:"
cat before.txt

echo ">>> Installing requirements/nightly_torch_test.txt"
pip install --quiet -r requirements/nightly_torch_test.txt

echo ">>> Capturing torch-related versions after requirements install"
pip freeze | grep -E '^torch|^torchvision|^torchaudio' | sort > after.txt
echo "After:"
cat after.txt

echo ">>> Comparing versions"
if diff before.txt after.txt; then
  echo "torch version not overridden."
else
  echo "torch version overridden by nightly_torch_test.txt, \
  if the dependency is not triggered by the pytroch nightly test,\
  please add the dependency to the list 'white_list'  in tools/generate_nightly_torch_test.py"
  exit 1
fi
