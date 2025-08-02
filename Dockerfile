# --- Estágio 1: Builder ---
# Usamos uma imagem Node para compilar o projeto
FROM docker.io/library/node:20-slim as builder

# Definimos o diretório de trabalho
WORKDIR /app

# CORREÇÃO: Instalar o GIT, que é necessário para os scripts de build do projeto
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*

# Copiamos TODOS os arquivos de código-fonte primeiro
COPY . .

# Agora, rodamos o npm install. Ele vai rodar os scripts 'prepare' e 'generate'
# que agora funcionarão, pois o GIT está instalado.
RUN npm install

# Executamos o comando de 'package' para criar os pacotes .tgz
RUN npm run package


# --- Estágio 2: Final ---
# Começamos de uma imagem limpa
FROM docker.io/library/node:20-slim

# Instalamos as dependências de sistema que a CLI PRECISA para rodar.
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 make g++ man-db curl dnsutils less jq bc gh git unzip \
    rsync ripgrep procps psmisc lsof socat ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Configuramos o diretório global do NPM
RUN mkdir -p /usr/local/share/npm-global \
    && chown -R node:node /usr/local/share/npm-global
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin

# Trocamos para o usuário 'node' por segurança.
USER node

# Copiamos os pacotes .tgz compilados do estágio 'builder'.
COPY --from=builder /app/packages/cli/dist/google-gemini-cli-*.tgz /usr/local/share/npm-global/gemini-cli.tgz
COPY --from=builder /app/packages/core/dist/google-gemini-cli-core-*.tgz /usr/local/share/npm-global/gemini-core.tgz

# Instalamos a CLI globalmente a partir desses pacotes.
RUN npm install -g /usr/local/share/npm-global/gemini-cli.tgz /usr/local/share/npm-global/gemini-core.tgz \
    && npm cache clean --force \
    && rm -f /usr/local/share/npm-global/gemini-{cli,core}.tgz

# Definimos o comando padrão para manter o contêiner ativo.
CMD ["tail", "-f", "/dev/null"]
