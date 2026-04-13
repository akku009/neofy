#!/usr/bin/env bash
set -e

# Install Ruby 3.4.9
curl -sSL https://get.rvm.io | bash -s stable
source /usr/local/rvm/scripts/rvm
rvm install 3.4.9
rvm use 3.4.9 --default

cd backend
bundle install
