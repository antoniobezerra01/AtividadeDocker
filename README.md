# PB DevSecOps Compass.uol - Atividade de Docker

# Sumário
- [Integrantes](#integrantes)
- [Sobre a Atividade](#sobre-a-atividade)
- [Configurando instância EC2](#configurando-instância-ec2)
    - [Configuração dos grupos de seguranças](#configuração-dos-grupos-de-seguranças)
    - [Configuração da VPC](#configuração-da-vpc)
        - [Configuração das sub-redes](#configuração-das-sub-redes)
        - [Configuração dos gateways](#configuração-dos-gateways)
    - [Pares de chaves](#pares-de-chaves)
    - [Executando Bastion Host](#executando-bastion-host)
    - [Executando instância da aplicação](#executando-instância-da-aplicação)
- [Configurando porta do SSH no bastion](#configurando-porta-ssh-no-bastion)
- [Instalação do Docker na instância](#instalação-docker-na-instância)
- [Instalação do Docker Compose](#instalação-do-docker-compose)
- [Montagem do EFS](#montagem-do-efs)
- [Executando contêineres via Docker Compose](#executando-contêineres-via-docker-compose)
- [Configuração do balanceador de cargas](#configuração-do-balanceador-de-cargas)
    - [Grupo de destino](#grupo-de-destino)
    - [Aplication Load Balancer](#aplication-load-balancer)
    - [Associando instância da aplicação ao grupo destino](#associando-instância-da-aplicação-ao-grupo-destino)
- [Acessando instâncias criadas](#acessando-instâncias-criadas)
    - [Acessando Bastion](#acessando-bastion)
    - [Acessando aplicação](#acessando-aplicação)


# Integrantes
- [Antonio Bezerra](https://github.com/antoniobezerra01)
- [Alex Lopes](https://github.com/alexlsilva7)
- [Erik Alexandre](https://github.com/Alexandreerik)

# Sobre a Atividade

- Instalação e configuração do DOCKER ou CONTAINERD no host EC2;
- Ponto adicional para o trabalho utilizar a instalação via script de Start Instance (user_data.sh)
- Efetuar Deploy de uma aplicação Wordpress com: 
  - Container de aplicação
  - Container database Mysql
  - Configuração da utilização do serviço EFS AWS para estáticos do container de aplicação Wordpress
  - Configuração do serviço de Load Balancer AWS para a aplicação Wordpress

### Pontos de atenção

- Não utilizar ip público para saída do serviços WP (Evitar publicar o serviço WP via IP Público)
- Sugestão para o tráfego de internet sair pelo LB (Load Balancer Classic)
- Pastas públicas e estáticos do wordpress sugestão de utilizar o EFS (Elastic File Sistem)
- Fica a critério de cada integrante (ou dupla) usar Dockerfile ou Dockercompose;
- Necessário demonstrar a aplicação wordpress funcionando (tela de login)
- Aplicação Wordpress precisa estar rodando na porta 80 ou 8080;
- Utilizar repositório git para versionamento;
- Criar documentação

# Configurando instâncias EC2

Iremos utilizar duas instâncias sendo uma o Bastion host, o qual será o responsável pelo acesso a instância via SSH, e a outra a instância que deverá conter a aplicação com o Docker.
## Configuração dos grupos de seguranças
Configurar 3 grupos de segurança um para o Bastion host, um para o balanceador de carga e o último para a aplicação. Para isso, inicie navegando para o console da EC2 no link https://us-east-1.console.aws.amazon.com/ec2/home e acesse a seção do grupo de segurança.

- Grupo de segurança do Bastion
  Porta | Protocolo | Origem
  --- | --- | ---
  22222  | TCP | "MEU-IP"

- Grupo de segurança do balanceador de carga
  Porta | Protocolo | Origem
  --- | --- | ---
  80  | TCP | 0.0.0.0/0

- Grupo de segurança da aplicação
  Porta | Protocolo | Origem 
  --- | --- | ---
  22 | TCP | Grupo de segurança do Bastion Host
  2049 | TCP | 172.31.0.0/16
  2049 | UDP | 172.31.0.0/16
  80 | TCP | Grupo de segurança do balanceador de carga

## Configuração da VPC

Inicie navegando para o console da VPC no link https://us-east-1.console.aws.amazon.com/vpc/home
### Configuração das sub-redes
Iremos utilizar a VPC padrão já criada, porém pra essa vpc devemos considerar o uso de duas sub-redes, sendo uma privada, que contém a instância da aplicação, e a outra pública, que contém a instância do bastion. Então, navegue para seção de sub-redes.

- Criando sub-rede privada
    - `Nome: private-wordpress`
    - `Zona de disponibilidade: us-east-1a`
    - `CIDR: 172.31.1.0/24`

- Criando sub-rede pública
    - `Nome: aws-controltower-PrivateSubnet1A`
    - `Zona de disponibilidade: us-east-1a`
    - `CIDR: 172.31.64.0/20`

### Configuração dos Gateways

Para uma instância privada obter acesso a internet para baixar/instalar alguns pacotes devemos utilizar um gateway NAT, o qual é associado a um gateway da internet. Então, navegue para seção de gateway.

- Criando gateway da internet
    - `Nome: Antonio`
    
- Criando gateway NAT
    - `Nome: gtw-wordpress`
    - `Sub-rede: aws-controltower-PrivateSubnet1A`
    - `Conectividade: Público`
    - `IP elástico: alocar IP elástico`

### Tabela de rotas
Precisaremos criar duas tabela de roteamento, sendo uma pra cada sub-rede criada, onde uma vai permitir o tráfego à internet pelo gateway da internet e o outro vai permitir o tráfego à internet pelo gateway NAT. Então, navegue para seção de tabela de rotas.

- Criando a tabela de roteamento para sub-rede pública
    - `Nome: Antonio`
    - `VPC: default`
- Criando a tabela de roteamento para sub-rede privada
    - `Nome: rt-wordpress`
    - `VPC: default`

Após isso devemos associar cada sub-rede criada anteriormente a sua respectiva tabela de roteamento. 

- Associando sub-rede privada a sua tabela de roteamento

    Selecione a tabela de roteamento, siga para associações de sub-redes e selecione `Editar associações`. Após isso, selecione a sub-rede privada, com `nome:private-wordpress` e clique `salvar`.

- Associando sub-rede pública a sua tabela de roteamento

    Selecione a tabela de roteamento, siga para associações de sub-redes e selecione `Editar associações`. Após isso, selecione a sub-rede pública, com `nome: aws-controltower-PrivateSubnet1A` e clique `salvar`.

Além disso, devemos também permitir o tráfego a internet para cada sub-rede, sendo pelo gateway da internet para sub-rede pública e gateway NAT para sub-rede privada.

- Adicionando rota para gateway da internet na tabela de roteamento da sub-rede pública

    Selecione a tabela de roteamento, siga para rotas e selecione `Editar rotas`. Após isso, selecione `adicionar rotas` e preencha:
    
    Destino    | Alvo 
     ---       |  --- 
     0.0.0.0/0 | gateway da internet
   
- Adicionando rota para gateway da internet na tabela de roteamento da sub-rede pública

    Selecione a tabela de roteamento, siga para rotas e selecione `Editar rotas`. Após isso, selecione `adicionar rotas` e preencha:

    Destino    | Alvo 
     ---       |  --- 
     0.0.0.0/0 | gateway NAT

Após esses passos, finalizamos as configurações necessárias para o serviço de VPC.

## Pares de chaves

Inicie navegando para o console da EC2 no link https://us-east-1.console.aws.amazon.com/ec2/home

Antes da execução das instâncias, devemos iniciar com a criação dos par de chaves. Então, navegue para seção de pares de chaves.

- Criação do par de chaves
    - `Nome: keySSHAntonio`
    - `Tipo: RSA`
    - `Formato: .pem`

Seguindo com a execução das instâncias, iremos continuar com a execução do Bastion Host.

## Executando Bastion Host
Inicie navegando para o console da EC2 no link https://us-east-1.console.aws.amazon.com/ec2/home e selecione `executar instância`.
### Configuração da instância
- `AMI: Linux 2`
- `VPC: default`
- `Sub-rede:  aws-controltower-PrivateSubnet1A`
- `Tipo da instância: t2.micro`
- `par de chaves: keySSHAntonio`
- `EBS: 16GB GP2`
- `Auto-associamento de IP público: habilitado`

## Executando instância da aplicação
Inicie navegando para o console da EC2 no link https://us-east-1.console.aws.amazon.com/ec2/home e selecione `executar instância`.

### Configuração da instância
- `AMI: Linux 2`
- `VPC: default`
- `Sub-rede:  private-wordpress`
- `Tipo da instância: t3.small`
- `par de chaves: keySSHAntonio`
- `EBS: 16GB GP2`
- `Auto-associamento de IP público: desabilitado`

## Configurando porta SSH no Bastion
Antes da execução da instância do bastion, devemos executar um script no user data do Bastion host, que irá modificar a porta de acesso ao SSH. Veja abaixo:

```bash
#!/bin/bash

yum update -y

# Configuração da porta SSH
echo "Port 22222" >> /etc/ssh/sshd_config
systemctl restart sshd.service
```

# Instalação Docker na instância

Para instalar o docker na instância iremos executar os seguintes comandos:

```bash
#atualizar os pacotes para a última versão
sudo yum update -y
#instalar o docker
sudo yum install docker
#iniciar o serviço do docker
sudo systemctl start docker
#habilitar o serviço do docker para iniciar automaticamente
sudo systemctl enable docker
#adicionar o usuário ec2-user ao grupo docker
sudo usermod -a -G docker ec2-user
```

# Instalação do Docker Compose
Para instalar o docker compose na instância iremos executar os seguintes comando:

```bash
# baixar o docker-compose para a pasta /usr/local/bin
sudo curl -L "https://github.com/docker/compose/releases/download/v2.15.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
# dar permissão de execução ao binário do docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

# Montagem do EFS

Para acessar o EFS configurado podemos executar os seguinte comandos:

```bash
# criar o diretório para o EFS
mkdir -p /mnt/nfs
# adicionar o EFS no fstab
echo "IP_OU_DNS_DO_NFS:/ /mnt/nfs nfs defaults 0 0" >> /etc/fstab
# montar o EFS
mount -a
```

# Executando contêineres via Docker Compose

Para subir os contêineres que estarão responsáveis pela aplicação do Wordpress, iremos utilizar a execução de um [docker-compose.yml](/docker-compose.yml) que está disponibilizado nesse repositório. Então o primeiro passo é clonar esse arquivo para dentro da instância, iremos fazer isso usando os seguintes comandos:

```bash
# instalar o git
sudo yum install git -y
git clone https://github.com/antoniobezerra01/AtividadeDocker.git /home/ec2-user/AtividadeDocker
```
Após isso podemos subir os contêineres utilizando o seguinte comando:
```bash 
docker-compose -f /home/ec2-user/AtividadeDocker/docker-compose.yml up -d
```

# Configuração do balanceador de cargas

Inicie navegando para o console da EC2 no link https://us-east-1.console.aws.amazon.com/ec2/home e acesse a seção do balanceador de carga.

## Grupo de destino
Vamos seguir com a criação do grupo de destino

- Criação do grupo de destino
    - `Tipo: instância`
    - `Nome: wordpressTG`
    - `VPC: default`
    - `Protocolo: http`
    - `Códigos de sucesso: 200,302`

## Aplication Load Balancer
Seguimos com a criação do ALB.

- Criação do Aplication Load Balancer
    - `Nome: wordpressALB`
    - `Esquema: voltado pra internet`
    - `Tipo de endereço IP: IPv4`
    - `VPC: default`
    - `Mapeamento:`
        - `us-east-1a`
        - `us-east-1b`
    - `Grupo de segurança: wordpress`
    - `Listeners:`
        Protocolo | Porta | Ação padrão
        ---       | ---   | ---
        http      | 80    | wordpressTG

## Associando instância da aplicação ao grupo destino
Por fim, devemos associar a instância que tem a aplicação do wordpress ao grupo de destino.
Então, navegue até o grupo criado e selecione-o, após isso selecione a ação de `Registrar destinos`.

Em seguida, selecione a instância que detem a aplicação wordpress e clique `Incluir como pendente abaixo`. Então, clique `Registrar destinos pendentes`. Com isso finalizamos.

# Acessando instâncias criadas
Como dito anteriormente, iremos acessar a instância da aplicação através do Bastion Host.

## Acessando Bastion
Vamos utilizar o ssh-agent para conseguirmos acessar a instância privada sem necessitar copiar a chave de acesso para dentro do bastion. Então, na sua máquina local execute o seguinte:

```bash
ssh-agent # Executando agente SSH
ssh-add "NomeDaChave.pem" # Adicionando chave ao agente
```
Com isso podemos acessar a chave de acesso dentro do Bastion. Vamos acessar o bastion utilizando o seguinte comando:

```bash
ssh -A -i "NomeDaChave.pem" ec2-user@ip-bastion -p 22222 # Acessando instância e encaminhando chave para o bastion 
```

## Acessando aplicação
Dado que estamos acessando o bastion, podemos acessa a instância da aplicação. Então, como já foi copiado a chave pelo agente ssh, podemos acessar a instância da aplicação pelo seguinte:

```bash
ssh ec2-user@ip-privado-wp # Acessando instância da aplicação utilizando IP privado
```


[Voltar para o início](#pb-devsecops-compassuol---atividade-de-docker)