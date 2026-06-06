# 🐳 OrbitAlert — DevOps & Cloud Computing

> **Repositório de infraestrutura, containerização e deploy em nuvem**  
> Global Solution FIAP 2026/1 · Disciplina: DevOps Tools & Cloud Computing

---

## 👥 Equipe

| Nome | RM |
|---|---|
| Gabriel Sbrana Campos | RM 565849 |
| Moisés Waidemann | RM 563719 |
| Thiago Rodrigues da Mota | RM 563765 |
| Richard Freitas | RM 566127 |

---

## 🎥 Vídeo Demonstrativo

| Conteúdo | Link |
|---|---|
| Demo DevOps — containers em nuvem (How to completo) | [Assistir no YouTube](#) |

> O vídeo segue o fluxo completo do How to abaixo: do `git clone` até os SELECTs conectados diretamente nos containers em nuvem.

---

## 🛰️ Sobre a solução — OrbitAlert

O Brasil perde centenas de vidas por ano em deslizamentos e enchentes porque os alertas chegam tarde demais. A **OrbitAlert** é uma plataforma B2G SaaS que usa dados do satélite **Sentinel-1** (ESA/Copernicus) e um modelo de IA para antecipar desastres com até **48 horas de antecedência**, notificando gestores municipais via app mobile e estações IoT de campo.

Este repositório contém a infraestrutura DevOps que containeriza a API REST (Java Spring Boot) e o banco de dados, permitindo deploy reproduzível em qualquer ambiente de nuvem.

---

## 🏗️ Arquitetura Macro — Infraestrutura em Nuvem

```
┌─────────────────────────────────────────────────────────────────────┐
│                        VM em Nuvem (Cloud)                          │
│                                                                     │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │              Docker Network: orbitalert-network             │   │
│   │                                                             │   │
│   │   ┌───────────────────────┐   ┌────────────────────────┐   │   │
│   │   │  Container: App       │   │  Container: Banco       │   │   │
│   │   │  orbitalert-app-RM    │   │  orbitalert-db-RM       │   │   │
│   │   │                       │   │                         │   │   │
│   │   │  Java Spring Boot     │◄──►  PostgreSQL 15          │   │   │
│   │   │  Porta: 8080          │   │  Porta: 5432            │   │   │
│   │   │  Usuário: orbituser   │   │  Volume nomeado:        │   │   │
│   │   │  WORKDIR: /app        │   │  orbitalert-pgdata      │   │   │
│   │   └───────────────────────┘   └────────────────────────┘   │   │
│   │                                                             │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
│   Porta 8080 exposta ao exterior (acesso à API)                     │
│   Porta 5432 exposta ao exterior (acesso direto ao banco)           │
└─────────────────────────────────────────────────────────────────────┘
```

> **Ferramentas usadas no desenho:** Draw.io  
> ⚠️ O desenho **não** segue padrão TOGAF — é uma arquitetura macro de infraestrutura conforme exigido.

---

## 📁 Estrutura do Repositório

```
orbitalert-devops/
├── app/
│   └── (código-fonte da API Java — submodule ou cópia)
├── Dockerfile                  ← imagem personalizada da aplicação
├── docker-compose.yml          ← orquestração dos dois containers
├── .env.example                ← variáveis de ambiente (template)
└── README.md                   ← este arquivo (How to incluído)
```

---

## ⚙️ Configuração — Variáveis de Ambiente

Crie um arquivo `.env` na raiz do repositório com base no template `.env.example`:

```env
# ── Banco de Dados ──────────────────────────────
POSTGRES_DB=orbitalert
POSTGRES_USER=orbitadmin
POSTGRES_PASSWORD=OrbitAlert@2026

# ── Aplicação Java ──────────────────────────────
SPRING_DATASOURCE_URL=jdbc:postgresql://orbitalert-db-565849:5432/orbitalert
SPRING_DATASOURCE_USERNAME=orbitadmin
SPRING_DATASOURCE_PASSWORD=OrbitAlert@2026
SPRING_JPA_HIBERNATE_DDL_AUTO=update
SERVER_PORT=8080
```

> ⚠️ Nunca suba o `.env` real para o GitHub. O `.env.example` está versionado; o `.env` está no `.gitignore`.

---

## 🐳 Dockerfile — Container da Aplicação

```dockerfile
# ── Stage 1: Build ──────────────────────────────────────────────────
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /build
COPY app/pom.xml .
COPY app/src ./src
RUN mvn clean package -DskipTests

# ── Stage 2: Runtime ────────────────────────────────────────────────
FROM eclipse-temurin:21-jre-alpine

# Usuário não privilegiado
RUN addgroup -S orbitgroup && adduser -S orbituser -G orbitgroup

# Diretório de trabalho
WORKDIR /app

# Copia o jar gerado no stage anterior
COPY --from=build /build/target/*.jar orbitalert.jar

# Ajusta permissões
RUN chown -R orbituser:orbitgroup /app

# Troca para usuário não privilegiado
USER orbituser

# Expõe a porta da aplicação
EXPOSE 8080

ENTRYPOINT ["java", "-jar", "orbitalert.jar"]
```

---

## 🗂️ docker-compose.yml

```yaml
version: "3.9"

networks:
  orbitalert-network:
    driver: bridge

volumes:
  orbitalert-pgdata:

services:

  # ── Container do Banco de Dados ─────────────────────────────────
  orbitalert-db-565849:
    image: postgres:15-alpine
    container_name: orbitalert-db-565849
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    ports:
      - "5432:5432"
    volumes:
      - orbitalert-pgdata:/var/lib/postgresql/data
    networks:
      - orbitalert-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5

  # ── Container da Aplicação ──────────────────────────────────────
  orbitalert-app-565849:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: orbitalert-app-565849
    restart: unless-stopped
    depends_on:
      orbitalert-db-565849:
        condition: service_healthy
    environment:
      SPRING_DATASOURCE_URL: ${SPRING_DATASOURCE_URL}
      SPRING_DATASOURCE_USERNAME: ${SPRING_DATASOURCE_USERNAME}
      SPRING_DATASOURCE_PASSWORD: ${SPRING_DATASOURCE_PASSWORD}
      SPRING_JPA_HIBERNATE_DDL_AUTO: ${SPRING_JPA_HIBERNATE_DDL_AUTO}
      SERVER_PORT: ${SERVER_PORT}
    ports:
      - "8080:8080"
    networks:
      - orbitalert-network
```

---

## 🚀 How To — Do Clone ao Deploy em Nuvem

> Siga cada passo na ordem. Este é o roteiro do vídeo demonstrativo.

### Pré-requisitos

- VM em nuvem com Ubuntu 22.04+ (AWS EC2, Azure VM, GCP Compute Engine etc.)
- Docker Engine instalado (`docker --version`)
- Docker Compose Plugin instalado (`docker compose version`)
- Git instalado

---

### Passo 1 — Clonar o repositório

```bash
git clone https://github.com/orbitalert-gs/orbitalert-devops.git
cd orbitalert-devops
```

---

### Passo 2 — Configurar variáveis de ambiente

```bash
cp .env.example .env
# Edite o .env com suas credenciais, se necessário
nano .env
```

---

### Passo 3 — Subir os containers em background (modo detached)

```bash
docker compose up -d --build
```

Saída esperada:
```
[+] Building ...  ✔
[+] Running 2/2
 ✔ Container orbitalert-db-565849   Started
 ✔ Container orbitalert-app-565849  Started
```

---

### Passo 4 — Verificar que ambos os containers estão rodando

```bash
docker ps
```

Você deverá ver os dois containers com status `Up`.

---

### Passo 5 — Exibir logs dos containers

```bash
# Logs do banco
docker logs orbitalert-db-565849

# Logs da aplicação
docker logs orbitalert-app-565849
```

---

### Passo 6 — Acessar o terminal dos containers e demonstrar estrutura

**Container da Aplicação:**
```bash
docker container exec -it orbitalert-app-565849 sh

# Dentro do container:
whoami          # deve retornar: orbituser
pwd             # deve retornar: /app
ls -l           # lista os arquivos no diretório de trabalho
exit
```

**Container do Banco:**
```bash
docker container exec -it orbitalert-db-565849 sh

# Dentro do container:
whoami          # deve retornar: postgres (ou root)
pwd
ls -l /var/lib/postgresql/data
exit
```

---

### Passo 7 — Testar a API (CRUD)

Com os containers rodando, acesse a documentação Swagger:

```
http://<IP-DA-VM>:8080/swagger-ui.html
```

Ou teste via curl:

```bash
# CREATE — criar zona de risco
curl -X POST http://localhost:8080/api/zonas \
  -H "Content-Type: application/json" \
  -d '{"nome":"Zona Norte SP","municipioId":1,"nivelRisco":3}'

# READ — listar zonas
curl http://localhost:8080/api/zonas

# UPDATE — atualizar nível de risco
curl -X PUT http://localhost:8080/api/zonas/1 \
  -H "Content-Type: application/json" \
  -d '{"nivelRisco":5}'

# DELETE — remover zona
curl -X DELETE http://localhost:8080/api/zonas/1
```

---

### Passo 8 — Evidenciar persistência com SELECT direto no container do banco

```bash
docker container exec -it orbitalert-db-565849 psql -U orbitadmin -d orbitalert
```

Dentro do psql, execute:

```sql
-- Verificar tabelas criadas
\dt

-- Evidência 1: Zonas de risco persistidas
SELECT * FROM tb_zona_risco;

-- Evidência 2: Alertas gerados
SELECT * FROM tb_alerta;

-- Sair
\q
```

---

### Passo 9 — Verificar volume nomeado (persistência)

```bash
docker volume ls
docker volume inspect orbitalert-pgdata
```

---

### Passo 10 — Parar os containers (opcional)

```bash
docker compose down
# Para remover também os volumes (cuidado: apaga os dados):
docker compose down -v
```

---

## 📊 Tabelas no Banco de Dados

A aplicação utiliza **no mínimo duas tabelas com relacionamento** para persistência do CRUD:

| Tabela | Descrição |
|---|---|
| `tb_municipio` | Municípios monitorados (id, nome, estado, lat, lon) |
| `tb_zona_risco` | Zonas de risco por município — **FK para tb_municipio** |
| `tb_alerta` | Alertas gerados — **FK para tb_zona_risco** |
| `tb_tipo_alerta` | Domínio de tipos (deslizamento, enchente, seca) |

Relacionamentos: `tb_municipio` 1:N `tb_zona_risco` 1:N `tb_alerta`.

---

## ✅ Checklist de Conformidade com o Edital

| Requisito | Status |
|---|---|
| Container da app construído via Dockerfile | ✅ |
| Imagem personalizada gerada | ✅ |
| Usuário não privilegiado (`orbituser`) | ✅ |
| Diretório de trabalho definido (`/app`) | ✅ |
| Variável de ambiente no container da app | ✅ |
| Porta exposta no container da app (8080) | ✅ |
| Nome do container contém RM (565849) | ✅ |
| CRUD completo com mínimo 2 tabelas | ✅ |
| App na mesma rede que o banco | ✅ |
| Container do banco com imagem pública | ✅ |
| Volume nomeado (`orbitalert-pgdata`) | ✅ |
| Variável de ambiente no banco | ✅ |
| Porta exposta no banco (5432) | ✅ |
| Nome do container do banco contém RM | ✅ |
| Ambos os containers em modo background | ✅ |
| Logs exibidos no terminal | ✅ (Passo 5) |
| `docker exec` com `whoami`, `pwd`, `ls -l` | ✅ (Passo 6) |
| SELECT direto no container do banco | ✅ (Passo 8) |
| How to no README (do clone até nuvem) | ✅ |
| Descrição da solução no README | ✅ |
| Desenho da arquitetura macro | ✅ (não é TOGAF) |
| Código-fonte + Dockerfile + compose no GitHub | ✅ |
| Deploy em nuvem (não localhost) | ✅ |

---

## 🔗 Links do Projeto

| Recurso | Link |
|---|---|
| Repositório geral (hub) | [orbitalert-geral](#) |
| API Java | [orbitalert-java](#) |
| App Mobile | [orbitalert-mobile](#) |
| Banco de Dados | [orbitalert-database](#) |
| IoT | [orbitalert-iot](#) |
| .NET | [orbitalert-.net](#) |
| QA | [orbitalert-QA](#) |
| Vídeo DevOps (YouTube) | [Assistir](#) |

---

## 📋 Informações Acadêmicas

| Campo | Valor |
|---|---|
| Instituição | FIAP — Faculdade de Informática e Administração Paulista |
| Curso | Análise e Desenvolvimento de Sistemas — 2º ano |
| Turma | 2TDS — Turmas de Fevereiro |
| Semestre | 2026/1 — Global Solution |
| Tema | Economia Espacial |
| Disciplina | DevOps Tools & Cloud Computing |
| Prazo de entrega | 09/06/2026 às 23h55 |

---

<div align="center">

**OrbitAlert** · FIAP Global Solution 2026/1  
Dados do espaço. Infraestrutura na nuvem. Vidas salvas na Terra.

</div>
