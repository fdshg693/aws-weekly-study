FROM amazonlinux:2023

ARG ANSIBLE_CORE_VERSION=2.19.6
ARG TARGETARCH

RUN dnf update -y \
    && dnf install -y \
        awscli \
        findutils \
        gzip \
        less \
        procps-ng \
        python3.11 \
        shadow-utils \
        tar \
        unzip \
        which \
        zip \
    && case "$TARGETARCH" in \
        amd64) SESSION_MANAGER_PLUGIN_URL="https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" ;; \
        arm64) SESSION_MANAGER_PLUGIN_URL="https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_arm64/session-manager-plugin.rpm" ;; \
        *) echo "Unsupported TARGETARCH: $TARGETARCH" >&2; exit 1 ;; \
    esac \
    && curl -fsSL "$SESSION_MANAGER_PLUGIN_URL" -o /tmp/session-manager-plugin.rpm \
    && dnf install -y /tmp/session-manager-plugin.rpm \
    && rm -f /tmp/session-manager-plugin.rpm \
    && python3.11 -m venv /opt/ansible \
    && /opt/ansible/bin/pip install --no-cache-dir --upgrade pip \
    && /opt/ansible/bin/pip install --no-cache-dir \
        "ansible-core==${ANSIBLE_CORE_VERSION}" \
        ansible-runner \
        boto3 \
    && dnf clean all \
    && rm -rf /var/cache/dnf

ENV PATH="/opt/ansible/bin:${PATH}" \
    AWS_REGION=ap-northeast-1 \
    AWS_DEFAULT_REGION=ap-northeast-1 \
    AWS_SDK_LOAD_CONFIG=1 \
    ANSIBLE_CONFIG=/workspace/ansible/ansible.cfg \
    PYTHONUNBUFFERED=1

COPY ansible/requirements.yml /tmp/requirements.yml

RUN ansible-galaxy collection install -r /tmp/requirements.yml \
    && rm -f /tmp/requirements.yml

WORKDIR /workspace/ansible

ENTRYPOINT ["/usr/bin/env"]
CMD ["bash"]