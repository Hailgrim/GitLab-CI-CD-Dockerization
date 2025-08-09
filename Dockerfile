FROM ubuntu:latest AS simple-vps

RUN apt-get update && apt-get install -y \
    systemd \
    systemd-sysv \
    sudo \
    curl \
    vim \
    openssh-server \
    ca-certificates

RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc && \
    chmod a+r /etc/apt/keyrings/docker.asc && \
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

RUN echo '{"insecure-registries": ["host.docker.internal:5050"]}' > /etc/docker/daemon.json

RUN systemctl enable ssh docker

RUN useradd -m -s /bin/bash -G sudo,docker vpsuser && \
    echo 'vpsuser:password' | chpasswd && \
    mkdir -p /opt/project && \
    chown -R vpsuser:vpsuser /opt/project

CMD ["/sbin/init"]