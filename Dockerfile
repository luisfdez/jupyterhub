# An incomplete base Docker image for running JupyterHub
#
# Add your configuration to create a complete derivative Docker image.
#
# Include your configuration settings by starting with one of two options:
#
# Option 1:
#
# FROM jupyterhub/jupyterhub:latest
#
# And put your configuration file jupyterhub_config.py in /srv/jupyterhub/jupyterhub_config.py.
#
# Option 2:
#
# Or you can create your jupyterhub config and database on the host machine, and mount it with:
#
# docker run -v $PWD:/srv/jupyterhub -t jupyterhub/jupyterhub
#
# NOTE
# If you base on jupyterhub/jupyterhub-onbuild
# your jupyterhub_config.py will be added automatically
# from your docker directory.

FROM debian:jessie

MAINTAINER Jupyter Project <jupyter@googlegroups.com>

USER root

# install nodejs, utf8 locale, set CDN because default httpredir is unreliable
ENV DEBIAN_FRONTEND noninteractive
RUN REPO=http://cdn-fastly.deb.debian.org && \
    echo "deb $REPO/debian jessie main\ndeb $REPO/debian-security jessie/updates main" > /etc/apt/sources.list && \
    echo "deb http://http.us.debian.org/debian unstable main non-free contrib" > /etc/apt/sources.list && \
    echo "deb-src http://http.us.debian.org/debian unstable main non-free contrib" > /etc/apt/sources.list && \
    echo "deb http://ftp.us.debian.org/debian/ unstable main contrib non-free" > /etc/apt/sources.list && \
    echo "deb-src http://ftp.us.debian.org/debian/ unstable main contrib non-free" > /etc/apt/sources.list && \    
    apt-get -y update && \
    apt-get -y upgrade && \
    apt-get -y install wget locales git bzip2 libnss-wrapper &&\
    apt-get install -y -t unstable libnss-wrapper && \
    /usr/sbin/update-locale LANG=C.UTF-8 && \
    locale-gen C.UTF-8 && \
    apt-get remove -y locales && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Configure environment
ENV CONDA_DIR /opt/conda
ENV PATH $CONDA_DIR/bin:$PATH
ENV SHELL /bin/bash
ENV NB_USER jovyan
ENV NB_UID 1000
ENV HOME /home/$NB_USER
ENV LANG C.UTF-8

# Create jovyan user with UID=1000 and in the 'users' group
RUN useradd -m -s /bin/bash -N -u $NB_UID $NB_USER && \
    mkdir -p $CONDA_DIR && \
    chown $NB_USER $CONDA_DIR

ADD . /src/jupyterhub
RUN mkdir -p /srv/jupyterhub/

RUN chown -R $NB_USER:root /home/$NB_USER
RUN chown -R $NB_USER:root /src/jupyterhub
RUN chown -R $NB_USER:root /srv/jupyterhub

RUN ls -alh /home/$NB_USER && \
    ls -alh /src/jupyterhub && \
    ls -alh /srv/jupyterhub

USER $NB_UID

# Setup jovyan home directory
RUN mkdir /home/$NB_USER/work && \
    mkdir /home/$NB_USER/.jupyter && \
    echo "cacert=/etc/ssl/certs/ca-certificates.crt" > /home/$NB_USER/.curlrc

# install Python + NodeJS with conda
RUN wget -q https://repo.continuum.io/miniconda/Miniconda3-4.2.12-Linux-x86_64.sh -O /tmp/miniconda.sh  && \
    echo 'd0c7c71cc5659e54ab51f2005a8d96f3 */tmp/miniconda.sh' | md5sum -c - && \
    bash /tmp/miniconda.sh -f -b -p /opt/conda && \
    /opt/conda/bin/conda install --yes -c conda-forge python=3.5 sqlalchemy tornado jinja2 traitlets requests pip nodejs configurable-http-proxy && \
    /opt/conda/bin/pip install --upgrade pip && \
    rm /tmp/miniconda.sh
ENV PATH=/opt/conda/bin:$PATH

#
# Build Jupyterhub
WORKDIR /src/jupyterhub

RUN python setup.py js && pip install .
# && \
#    rm -rf $PWD ~/.cache ~/.npm

# Get Ready for running
WORKDIR /srv/jupyterhub/

EXPOSE 8000

LABEL org.jupyter.service="jupyterhub"

CMD ["jupyterhub"]
