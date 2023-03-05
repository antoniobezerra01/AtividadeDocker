# PB DevSecOps Compass.uol - Atividade de Docker

# Sumário
- [Integrantes](#integrantes)
- [Sobre a Atividade](#sobre-a-atividade)
- [Configurando instância EC2](#configurando-instância-ec2)
    - [Configuração dos grupos de seguranças](#configuração-dos-grupos-de-seguranças)
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

# Configurando instância EC2

Iremos utilizar duas instâncias, sendo uma o Bastion host e a outra a instância que deverá conter a aplicação com o Docker.
## Configuração dos grupos de seguranças
Configurar 3 grupos de segurança um para , um para o balanceador de carga e o último para a aplicação, o qual será o responsável pelo acesso a instância via SSH.

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



# Referências