FROM nvidia/cuda:11.6.1-cudnn8-devel-ubuntu20.04

ARG USER
ARG USER_ID
ARG GROUP_ID
ENV PATH="/opt/miniconda/bin:${PATH}"
ARG PATH="/opt/miniconda/bin:${PATH}"

ENV TZ=Europe/Berlin
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
RUN apt-get update -y && apt-get install -y sudo curl less nano htop nload

RUN groupadd -g ${GROUP_ID} ${USER} && useradd -u ${USER_ID} -g ${USER} --create-home ${USER}
RUN echo "\n"\
  "# Allowing the ML container's user to access password-less sudo.\n"\
  "%#${GROUP_ID}  ALL=(ALL)       NOPASSWD: ALL"\
  >> /etc/sudoers

RUN curl https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh >/opt/miniconda.sh && chown $USER_ID:$GROUP_ID /opt/miniconda.sh && chmod +x /opt/miniconda.sh
RUN mkdir -p /opt/miniconda && chown -R $USER_ID:$GROUP_ID /opt/miniconda
USER ${USER}


RUN /opt/miniconda.sh -u -b -p /opt/miniconda
RUN conda install -y mamba -n base -c conda-forge
RUN mamba install -y tensorflow-gpu numpy scipy h5py keras pandas matplotlib jupyterlab pytorch torchvision imageio torchaudio cudatoolkit=11.3 -c pytorch -c conda-forge
RUN mamba init

USER root
RUN rm /opt/miniconda.sh
USER ${USER}

ENTRYPOINT ["/bin/bash"]
