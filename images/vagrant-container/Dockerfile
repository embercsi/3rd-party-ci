FROM centos:7

RUN cd /tmp && \
    curl -o vagrant.rpm https://releases.hashicorp.com/vagrant/2.2.7/vagrant_2.2.7_x86_64.rpm && \
    yum -y install ./vagrant.rpm git && \
    yum clean all && \
    rm -rf /var/cache/yum

WORKDIR /vagrant
ENTRYPOINT ["vagrant"]
CMD ["--help"]
