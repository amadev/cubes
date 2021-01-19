#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

######################################################################
# PY stage that simply does a pip install on our requirements
######################################################################
ARG PY_VER=3.7.9
FROM python:${PY_VER} AS cubes-py

RUN mkdir /app \
        && apt-get update -y \
        && apt-get install -y --no-install-recommends \
            build-essential \
            default-libmysqlclient-dev \
            libpq-dev \
            libsasl2-dev \
            libecpg-dev \
        && rm -rf /var/lib/apt/lists/*

# First, we just wanna install requirements, which will allow us to utilize the cache
# in order to only build if and only if requirements change
COPY requirements.txt  /app/
COPY requirements-optional.txt  /app/

COPY setup.py /app/
RUN cd /app \
    && pip install --no-cache -r requirements.txt -r requirements-optional.txt

######################################################################
# Final lean image...
######################################################################
ARG PY_VER=3.7.9
FROM python:${PY_VER} AS lean

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    FLASK_ENV=development \
    FLASK_APP="cubes.app:create_app()" \
    PYTHONPATH="/app/pythonpath" \
    CUBES_HOME="/app/cubes_home" \
    CUBES_PORT=8080

RUN useradd --user-group --no-create-home --no-log-init --shell /bin/bash cubes \
        && mkdir -p ${CUBES_HOME} ${PYTHONPATH} \
        && apt-get update -y \
        && apt-get install -y --no-install-recommends \
            build-essential \
            default-libmysqlclient-dev \
            libpq-dev \
        && rm -rf /var/lib/apt/lists/*

COPY --from=cubes-py /usr/local/lib/python3.7/site-packages/ /usr/local/lib/python3.7/site-packages/
# Copying site-packages doesn't move the CLIs, so let's copy them one by one
# COPY --from=cubes-py /usr/local/bin/gunicorn /usr/local/bin/celery /usr/local/bin/flask /usr/bin/
# COPY --from=cubes-node /app/cubes/static/assets /app/cubes/static/assets
# COPY --from=cubes-node /app/cubes-frontend /app/cubes-frontend

## Lastly, let's install cubes itself
COPY cubes /app/cubes
COPY setup.py /app/
RUN cd /app \
        && chown -R cubes:cubes * \
        && pip install -e .

COPY ./docker/docker-entrypoint.sh /usr/bin/

WORKDIR /app

USER cubes

# HEALTHCHECK CMD curl -f "http://localhost:$CUBES_PORT/health"

EXPOSE ${CUBES_PORT}

ENTRYPOINT ["/usr/bin/docker-entrypoint.sh"]

# ######################################################################
# # Dev image...
# ######################################################################
# FROM lean AS dev

# COPY ./requirements/*.txt ./docker/requirements-*.txt/ /app/requirements/

# USER root
# # Cache everything for dev purposes...
# RUN cd /app \
#     && pip install --no-cache -r requirements/docker.txt \
#     && pip install --no-cache -r requirements/requirements-local.txt || true
# USER cubes
