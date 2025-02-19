#!/bin/bash -e
#
# Install Snowflake Python Connector
#
set -o pipefail

THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ "$TRAVIS_OS_NAME" == "osx" ]; then
    brew update
    brew install openssl readline sqlite3 xz zlib
    brew outdated pyenv || brew upgrade pyenv
    brew install pyenv-virtualenv
    pyenv install ${PYTHON_VERSION}
    export PYENV_VERSION=$PYTHON
    export PATH="${HOME}/.pyenv/shims:${PATH}"
    if [[ $PYTHON_VERSION == "2.7"* ]]; then
        pip install -U virtualenv
        python -m virtualenv venv
    else
        python3 -m venv venv
    fi
else
    sudo apt-get update
    pip install -U virtualenv
    python -m virtualenv venv
fi
if [[ -n "$SNOWFLAKE_AZURE" ]]; then
    openssl aes-256-cbc -k "$super_azure_secret_password" -in parameters_az.py.enc -out test/parameters.py -d
else
    openssl aes-256-cbc -k "$super_secret_password" -in parameters.py.enc -out test/parameters.py -d
fi

source ./venv/bin/activate
pip install pandas
pip install numpy
pip install pendulum
pip install pytest pytest-cov pytest-rerunfailures
if [[ "$TRAVIS_PYTHON_VERSION" == "2.7" ]] || [[ $PYTHON_VERSION == "2.7"* ]]; then
    pip install mock
fi

if [ "$TRAVIS_OS_NAME" == "osx" ]; then
    export ENABLE_EXT_MODULES=true
    cd $THIS_DIR/..
    pip install Cython pyarrow==0.14.1 wheel
    python setup.py bdist_wheel
    unset ENABLE_EXT_MODULES
    CONNECTOR_WHL=$(ls $THIS_DIR/../dist/snowflake_connector_python*.whl | sort -r | head -n 1)
    pip install -U $CONNECTOR_WHL[pandas]
else
    if [[ "$TRAVIS_PYTHON_VERSION" == "2.7" ]]; then
        pip install .
    else
        pv=${TRAVIS_PYTHON_VERSION/./}
        $THIS_DIR/build_inside_docker.sh $pv
        CONNECTOR_WHL=$(ls $THIS_DIR/../dist/docker/repaired_wheels/snowflake_connector_python*cp${PYTHON_ENV}*.whl | sort -r | head -n 1)
        pip install -U $CONNECTOR_WHL[pandas]
        cd $THIS_DIR/..
    fi
fi
pip list --format=columns
