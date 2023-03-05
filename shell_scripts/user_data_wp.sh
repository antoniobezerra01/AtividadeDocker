#!/bin/bash

# Instalação e configuração do Docker
yum update -y
yum install docker -y
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user