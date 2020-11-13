FROM photon:3.0

COPY proxy.sh /proxy.sh

RUN tdnf update -y && tdnf install -y jq openssh-clients shadow && \
    curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl" && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin/kubectl && \
    chmod +x /proxy.sh && \
    groupadd inject && useradd -G inject inject

ENTRYPOINT [ "/proxy.sh" ]

 
