#!/bin/bash

set -ex

%{load_statement}

id=$(docker run -d %{flags} %{image} %{command})

docker commit $id %{tag}
# docker save %{tag} > %{output}
