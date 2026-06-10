# 🛰️ OrbitAlert — Deployment & DevOps Guide

**Plataforma de alertas precoces de desastres naturais com dados orbitais Sentinel-1 e IA generativa**

**FIAP Global Solution 2026/1** | Turma: 2TDS Fevereiro | Prazo: 09/06/26

---

## 📋 Índice

- [Arquitetura](#arquitetura)
- [Pré-requisitos](#pré-requisitos)
- [Setup Local (Docker)](#setup-local-docker)
- [Deployment em Azure](#deployment-em-azure)
- [Acesso & Testes](#acesso--testes)
- [Troubleshooting](#troubleshooting)
- [CI/CD & Escalabilidade](#cicd--escalabilidade)

---

## 🏗️ Arquitetura
<img width="1049" height="704" alt="Captura de Tela 2026-06-09 às 22 16 47" src="https://github.com/user-attachments/assets/d5f5dc59-88d9-4f3c-a122-090309d05f09" />


Acesso Local:
  Browser: http://localhost:8080
  Swagger: http://localhost:8080/swagger
  API: http://localhost:8080/api/*
  Oracle JDBC: jdbc:oracle:thin:@localhost:1521:XEPDB1
```

---

## 📦 Pré-requisitos

### Local (Desenvolvimento)

```bash
# System
- macOS, Linux ou Windows (WSL2)
- 8GB RAM mínimo (16GB recomendado)
- 50GB disco disponível

# Software
- Docker Desktop 20.10+ (ou Docker Engine standalone)
- Docker Compose 2.0+ (incluso no Docker Desktop)
- Git 2.30+
- Bash 4.0+
```

Verificar instalação:
```bash
docker --version
docker-compose --version
git --version
bash --version
```

### Azure (Produção)

```bash
# CLI & Subscription
- Azure CLI 2.40+
- Conta Azure ativa com subscription
- Permissão: Contributor role ou superior

# Azure resources (criadas pelo script)
- Resource Group
- Virtual Network + Subnet + NSG
- Compute: VM Ubuntu 22.04 (Standard_D2s_v3)
- Storage: Managed Disk (Premium SSD, 64GB)
```

Verificar:
```bash
az version
az account show
```

---

## 🐳 Setup Local (Docker)

### 1. Clonar Repositórios

```bash
cd ~/projects  # ou diretório de preferência

# DevOps (Scripts & Dockerfile)
git clone https://github.com/Waidemannm/DEVOPS-GS-2026.git
cd DEVOPS-GS-2026
```

### 2. Construir Imagens Docker

```bash
# Network (isolado, compartilhado entre containers)
docker network create orbitalert-network

# Volume nomeado para persistência de dados Oracle
docker volume create oracle-orbitalert-data

# Build da imagem Oracle
cd DB-GS-2026
docker build -t oracle-orbitalert-image:latest .
cd ..

# Build da imagem API (Java/Spring Boot)
cd JAVA-GS-2026
docker build -t api-orbitalert-image:latest .
cd ..

# Verificar imagens
docker images | grep orbitalert
```

### 3. Executar Containers

#### 3a. Oracle Database

```bash
docker run \
  --name oracle-orbitalert \
  --detach \
  --publish 1521:1521 \
  --volume oracle-orbitalert-data:/opt/oracle/oradata \
  --network orbitalert-network \
  --env ORACLE_PWD=111206 \
  --health-cmd='sqlplus -v' \
  --health-interval=30s \
  --health-timeout=30s \
  --health-start-period=60s \
  --health-retries=5 \
  oracle-orbitalert-image:latest
```

Aguardar Oracle estar pronto (~60 segundos):
```bash
docker logs -f oracle-orbitalert | grep "DATABASE IS READY"
```

#### 3b. Spring Boot API

```bash
docker run \
  --name api-orbitalert \
  --detach \
  --publish 8080:8080 \
  --network orbitalert-network \
  --env SPRING_DATASOURCE_URL="jdbc:oracle:thin:@oracle-orbitalert:1521:XEPDB1" \
  --env SPRING_DATASOURCE_USERNAME="rm563719" \
  --env SPRING_DATASOURCE_PASSWORD="111206" \
  --env SPRING_DATASOURCE_DRIVER_CLASS_NAME="oracle.jdbc.OracleDriver" \
  --health-cmd='curl -f http://localhost:8080/swagger-ui.html || exit 1' \
  --health-interval=30s \
  --health-timeout=10s \
  --health-start-period=60s \
  --health-retries=3 \
  api-orbitalert-image:latest
```

### 4. Validar Status

```bash
# Containers rodando
docker ps --filter "name=orbitalert"

# Logs em tempo real
docker logs -f api-orbitalert
docker logs -f oracle-orbitalert

# Health checks
docker inspect api-orbitalert | jq '.[0].State.Health'
docker inspect oracle-orbitalert | jq '.[0].State.Health'

# Conectividade entre containers
docker exec api-orbitalert curl -s http://oracle-orbitalert:1521/ || echo "Oracle OK"
```

### 5. Popular Dados Iniciais

```bash
# Entrar no container Oracle
docker exec -it oracle-orbitalert bash

# Conectar ao SQL*Plus
sqlplus rm563719/111206@XEPDB1

# Executar script de inicialização
@/container-entrypoint-initdb.d/orbitalert.sql

# Inserir usuário teste (opcional)
INSERT INTO TB_USUARIO (
    ID_USUARIO,
    NM_USUARIO,
    DS_EMAIL,
    DS_SENHA_HASH,
    TP_PERFIL,
    ST_ATIVO,
    DT_CADASTRO
) VALUES (
    SEQ_USUARIO.NEXTVAL,
    'Moises Waidemann',
    'moises.test@orbitalert.com',
    'hashed_password_here',
    'GESTOR',
    'S',
    SYSDATE
);
COMMIT;
EXIT;
```

### 6. Acessar a API

```
Swagger UI:    http://localhost:8080/swagger-ui.html
OpenAPI JSON:  http://localhost:8080/v3/api-docs
API Base:      http://localhost:8080/api

Exemplo de request:
curl -X GET "http://localhost:8080/api/Alertas" \
  -H "accept: application/json"
```

---

## ☁️ Deployment em Azure

### 1. Preparar Ambiente Azure

```bash
# Login na Azure (abrirá browser)
az login

# Listar subscriptions
az account list --output table

# Definir subscription ativa (se tiver múltiplas)
az account set --subscription "SUBSCRIPTION_ID_OU_NAME"

# Verificar contexto
az account show --query "{name:name, id:id, type:type}"
```

### 2. Executar Script de Infrastructure as Code

```bash
cd DEVOPS-GS-2026

# Tornar script executável
chmod +x gs-scripts.sh

# Remover caracteres Windows (se necessário)
sed -i 's/\r$//' gs-scripts.sh

# Executar script
./gs-scripts.sh
```

O script automatiza:
- ✅ Resource Group creation (rg-orbitalert)
- ✅ Virtual Network + Subnet (10.10.0.0/16)
- ✅ Network Security Group (Firewall rules)
- ✅ VM Ubuntu 22.04 (Standard_D2s_v3)
- ✅ Instalação Docker + Git via Azure CLI

**Tempo total: ~10-15 minutos**

### 3. SSH para VM e Deploy Containers

```bash
# Obter IP público da VM
az vm list-ip-addresses \
  --resource-group rg-orbitalert \
  --name vm-orbitalert \
  --output table

# SSH (credenciais: azureuser / OrbitAlert12@)
ssh azureuser@<PUBLIC_IP>

# Dentro da VM:

# Clonar repositórios
git clone https://github.com/Waidemannm/JAVA-GS-2026.git
git clone https://github.com/Waidemannm/DB-GS-2026.git

# Build imagens
docker network create orbitalert-network
docker volume create oracle-orbitalert-data

cd DB-GS-2026 && docker build -t oracle-orbitalert-image:latest . && cd ..
cd JAVA-GS-2026 && docker build -t api-orbitalert-image:latest . && cd ..

# Run containers (idêntico ao setup local)
docker run --name oracle-orbitalert -d -p 1521:1521 \
  -v oracle-orbitalert-data:/opt/oracle/oradata \
  --network orbitalert-network \
  -e ORACLE_PWD=111206 \
  oracle-orbitalert-image:latest

sleep 90  # Aguardar Oracle iniciar

docker run --name api-orbitalert -d -p 8080:8080 \
  --network orbitalert-network \
  -e SPRING_DATASOURCE_URL="jdbc:oracle:thin:@oracle-orbitalert:1521:XEPDB1" \
  -e SPRING_DATASOURCE_USERNAME="rm563719" \
  -e SPRING_DATASOURCE_PASSWORD="111206" \
  api-orbitalert-image:latest

# Verificar
docker ps
curl -s http://localhost:8080/swagger-ui.html | head -20
```

---

## 🔐 Acesso & Testes

### Credenciais Padrão

| Serviço | Username | Senha | Host | Porta |
|---------|----------|-------|------|-------|
| **Oracle DB** | rm563719 | 111206 | oracle-orbitalert | 1521 |
| **Oracle SID** | XEPDB1 | - | - | - |
| **Spring Boot** | (nenhuma) | (nenhuma) | localhost/vm | 8080 |

### URLs de Acesso

```
Local (Docker):
  API Base:        http://localhost:8080/api
  Swagger UI:      http://localhost:8080/swagger-ui.html
  OpenAPI JSON:    http://localhost:8080/v3/api-docs

Azure (Produção):
  API Base:        http://<VM_PUBLIC_IP>:8080/api
  Swagger UI:      http://<VM_PUBLIC_IP>:8080/swagger-ui.html
```

### Teste de API

```bash
# Listar alertas
curl -X GET "http://localhost:8080/api/Alertas" \
  -H "accept: application/json" | jq

# Listar municípios
curl -X GET "http://localhost:8080/api/Municipios" \
  -H "accept: application/json" | jq

# Criar novo alerta (JSON body)
curl -X POST "http://localhost:8080/api/Alertas" \
  -H "accept: application/json" \
  -H "Content-Type: application/json" \
  -d '{
    "nrNivelRisco": 4,
    "stStatus": "ATIVO",
    "dsObservacao": "Precipitação acumulada de 80mm nas últimas 6h",
    "dtFechamento": null,
    "idZona": 1,
    "idTipoAlerta": 1
  }'
```

### Conexão Oracle com SQL*Plus

```bash
# Local
sqlplus rm563719/111206@localhost:1521/XEPDB1

# Azure (dentro da VM)
docker exec -it oracle-orbitalert sqlplus rm563719/111206@XEPDB1

# Queries teste
SELECT COUNT(*) FROM TB_USUARIO;
SELECT * FROM TB_ALERTA WHERE ROWNUM <= 5;
DESC TB_ZONA_RISCO;
```

---

## 🔧 Troubleshooting

### Oracle não inicia

```bash
# Verificar logs
docker logs oracle-orbitalert | tail -50

# Se houver erro "ORA-" ou "invalid"
# Remover volume corrompido e recriado:
docker stop oracle-orbitalert
docker rm oracle-orbitalert
docker volume rm oracle-orbitalert-data
docker volume create oracle-orbitalert-data

# Rebuild container
docker build -t oracle-orbitalert-image:latest DB-GS-2026/
docker run ... (conforme seção 3a)
```

### API não conecta ao Oracle

```bash
# Verificar conectividade entre containers
docker exec api-orbitalert nslookup oracle-orbitalert

# Resultado esperado:
# Name:   oracle-orbitalert
# Address: 172.18.0.2  (ou IP similar)

# Se falhar:
# 1. Ambos containers estão no mesmo network?
docker network inspect orbitalert-network | grep "Containers" -A 10

# 2. Firewall ou NSG bloqueando porta 1521?
# (em Azure, liberar porta 1521 apenas para Subnet)

# 3. Verificar logs da API
docker logs -f api-orbitalert | grep "datasource\|jdbc\|oracle"
```

### Porta 8080 já em uso

```bash
# Encontrar processo na porta
lsof -i :8080

# Matar processo (macOS/Linux)
kill -9 <PID>

# Ou usar porta diferente no docker run:
docker run ... -p 9080:8080 ...
# Acessar em http://localhost:9080
```

### Container não salva dados após restart

```bash
# Verificar se volume está sendo usado
docker inspect oracle-orbitalert | grep -A 5 "Mounts"

# Resultado esperado: "Name": "oracle-orbitalert-data"
# Se houver "/var/lib/docker/volumes" → volume não está nomeado

# Solução: Remover e refazer com volume correto
docker stop oracle-orbitalert && docker rm oracle-orbitalert
docker run -v oracle-orbitalert-data:/opt/oracle/oradata ...
```

### Falta espaço em disco

```bash
# Limpar imagens, containers e volumes não utilizados
docker system prune -a --volumes

# Cuidado: REMOVE TUDO NÃO UTILIZADO
# Se quiser manter volumes:
docker system prune -a

# Ver uso de disco
docker system df
```

---

## 🚀 CI/CD & Escalabilidade

### Pipeline CI/CD Recomendado

```yaml
# GitHub Actions workflow (exemplo)
name: OrbitAlert CI/CD

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build Docker images
        run: |
          docker build -t api-orbitalert:${{ github.sha }} JAVA-GS-2026/
          docker build -t oracle-orbitalert:${{ github.sha }} DB-GS-2026/
      
      - name: Push to Registry (Azure ACR)
        run: |
          az acr login -n orbitalertregistry
          docker tag api-orbitalert:${{ github.sha }} orbitalertregistry.azurecr.io/api-orbitalert:${{ github.sha }}
          docker push orbitalertregistry.azurecr.io/api-orbitalert:${{ github.sha }}
      
      - name: Deploy to Azure Container Instances
        run: |
          az container create \
            --resource-group rg-orbitalert \
            --name api-orbitalert-${{ github.sha }} \
            --image orbitalertregistry.azurecr.io/api-orbitalert:${{ github.sha }} \
            --ports 8080 \
            --environment-variables SPRING_DATASOURCE_URL="..." SPRING_DATASOURCE_USERNAME="..." \
            --registryLoginServer orbitalertregistry.azurecr.io \
            --registry-username="..." \
            --registry-password="..."
```

### Escalabilidade Horizontal

```
Fase 1 (Atual):
├─ 1 VM (Docker Host)
├─ 1 Oracle Container
└─ 1 API Container

Fase 2 (Próximo):
├─ Azure Container Registry (ACR)
├─ Azure Kubernetes Service (AKS)
│  ├─ 3+ API Pods (replicas)
│  ├─ 1 Oracle Pod (StatefulSet)
│  └─ Ingress Controller (nginx)
├─ Azure Database for Oracle (Managed Service)
└─ Azure DevOps Pipelines (CI/CD)

Fase 3 (Produção):
├─ Multi-region deployment (eastus2 + westus2)
├─ Azure Load Balancer / Application Gateway
├─ Azure Traffic Manager (DNS-based routing)
├─ Azure Monitor + Application Insights
├─ Azure Backup (Daily snapshots)
└─ Azure Site Recovery (Disaster recovery)
```

### Comandos Úteis de Produção

```bash
# Monitorar recursos Azure
az monitor metrics list \
  --resource /subscriptions/{id}/resourceGroups/rg-orbitalert/providers/Microsoft.Compute/virtualMachines/vm-orbitalert

# Backup automático (Dia 23:00 UTC)
az vm auto-shutdown \
  --resource-group rg-orbitalert \
  --name vm-orbitalert \
  --time 23:00

# Agendar snapshot do disco
az snapshot create \
  --resource-group rg-orbitalert \
  --name snapshot-oracle-$(date +%Y%m%d) \
  --source /subscriptions/{id}/resourceGroups/rg-orbitalert/providers/Microsoft.Compute/disks/vm-orbitalert_OsDisk_1_hash

# Update image do container
docker pull api-orbitalert:latest
docker stop api-orbitalert
docker rm api-orbitalert
docker run ... api-orbitalert:latest
```

---

## 📊 Monitoramento

### Logs Centralizados

```bash
# Azure Monitor Integration
az vm extension set \
  --resource-group rg-orbitalert \
  --vm-name vm-orbitalert \
  --name DependencyAgentLinux \
  --publisher Microsoft.Azure.Monitoring.DependencyAgent \
  --version 9.10

# Query logs via Azure CLI
az monitor log-analytics query \
  --workspace "/subscriptions/{id}/resourcegroups/rg-orbitalert/providers/microsoft.operationalinsights/workspaces/orbitalert-logs" \
  --analytics-query "ContainerLog | where ContainerID contains 'orbitalert' | top 100 by TimeGenerated"
```

### Dashboard Prometheus/Grafana (Opcional)

```bash
# Adicionar Prometheus ao docker-compose
docker run -d --name prometheus \
  --network orbitalert-network \
  -p 9090:9090 \
  -v prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus:latest

# Adicionar Grafana
docker run -d --name grafana \
  --network orbitalert-network \
  -p 3000:3000 \
  -e GF_SECURITY_ADMIN_PASSWORD=OrbitAlert12@ \
  grafana/grafana:latest
```

---

## 📋 Checklist de Deployment

- [ ] **Local**
  - [ ] Docker Desktop instalado
  - [ ] Repositórios clonados
  - [ ] Imagens buildadas sem erro
  - [ ] Ambos containers rodando (`docker ps`)
  - [ ] API respondendo em http://localhost:8080/swagger
  - [ ] Banco de dados populado

- [ ] **Azure**
  - [ ] Azure CLI instalado e autenticado
  - [ ] Subscription ativa verificada
  - [ ] Script `gs-scripts.sh` executado com sucesso
  - [ ] VM criada e acessível via SSH
  - [ ] Docker instalado na VM (verifique via SSH: `docker --version`)
  - [ ] Repositórios clonados na VM
  - [ ] Imagens buildadas na VM
  - [ ] Containers rodando na VM (`docker ps`)
  - [ ] API respondendo em http://<VM_IP>:8080/swagger
  - [ ] NSG rules liberando tráfego (22, 8080)

- [ ] **Produção**
  - [ ] Senhas alteradas (não usar padrão)
  - [ ] Backup diário configurado
  - [ ] Monitoramento ativado
  - [ ] Logs centralizados (Azure Monitor)
  - [ ] DNS configurado (apontar para IP público)
  - [ ] HTTPS/SSL habilitado (nginx reverse proxy)
  - [ ] Rate limiting implementado
  - [ ] Testes de carga realizados

---

## 📚 Referências

- **Azure CLI Documentation**: https://learn.microsoft.com/en-us/cli/azure/
- **Docker Documentation**: https://docs.docker.com/
- **Oracle Database in Docker**: https://github.com/oracle/docker-images/tree/main/OracleDatabase
- **Spring Boot Docker**: https://spring.io/guides/topicals/spring-boot-docker/
- **Infrastructure as Code (IAC)**: https://learn.microsoft.com/en-us/devops/deliver/what-is-infrastructure-as-code

---

## 👥 Equipe

| Membro | RM | Função |
|--------|-----|--------|
| Gabriel Sbrana Campos | 565849 | Arquitetura |
| Moisés Waidemann | 563719 | DevOps / Infraestrutura |
| Thiago Rodrigues da Mota | 563650 | Backend |
| Richard Freitas | 566127 | Banco de Dados |

---

## 📝 Versionamento

| Versão | Data | Alterações |
|--------|------|-----------|
| 1.0 | 07/06/2026 | Setup inicial com Docker local + Azure deployment |
| 1.1 (Planejado) | 09/06/2026 | CI/CD com GitHub Actions + ACR |
| 2.0 (Roadmap) | Q3 2026 | Kubernetes (AKS) + Multi-region |

---

**Última atualização**: 07 de junho de 2026

Para suporte ou dúvidas, contacte a equipe DevOps via GitHub Issues ou chat do FIAP.
