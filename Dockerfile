FROM photon:3.0

COPY proxy.sh /proxy.sh

RUN tdnf update && tdnf install -y jq openssh-clients && \
    curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl" && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin/kubectl && \
    chmod +x /proxy.sh

ENTRYPOINT [ "/proxy.sh" ]

 
