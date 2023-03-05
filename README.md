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
- [Referências](#referências)

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
Configurar 3 grupos de segurança um para o Bastion host, um para o balanceador de carga e o último para a aplicação. Para isso, inicie navegando para o console da EC2 no link https://us-east-1.console.aws.amazon.com/vpc/home e acesse a seção do grupo de segurança.

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

# Referências