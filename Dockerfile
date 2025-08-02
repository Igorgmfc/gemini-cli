# --- Estágio 1: Builder ---
# Usamos uma imagem Node para compilar o projeto
FROM docker.io/library/node:20-slim as builder

# Definimos o diretório de trabalho
WORKDIR /app

# Copiamos TODOS os arquivos de código-fonte primeiro
COPY . .

# CIRURGIA: Criamos o arquivo falso que o build espera encontrar ANTES de tudo.
RUN mkdir -p packages/cli/generated && \
    echo "export const GIT_COMMIT_INFO = { commit: 'docker-build', date: 'N/A' };" > packages/cli/generated/git-commit.js

# Agora, rodamos o npm install com a flag --ignore-scripts para evitar
# que o script "prepare" problemático seja executado.
RUN npm install --ignore-scripts

# Com as dependências instaladas, AGORA rodamos o build e o package.
RUN npm run build
RUN npm run package


# --- Estágio 2: Final ---
# Começamos de uma imagem limpa
FROM docker.io/library/node:20-slim

# Instalamos as dependências de sistema necessárias
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

# Trocamos para o usuário 'node'
USER node

# Copiamos os pacotes .tgz compilados do estágio 'builder'
COPY --from=builder /app/packages/cli/dist/google-gemini-cli-*.tgz /usr/local/share/npm-global/gemini-cli.tgz
COPY --from=builder /app/packages/core/dist/google-gemini-cli-core-*.tgz /usr/local/share/npm-global/gemini-core.tgz

# Instalamos a CLI globalmente a partir dos arquivos que acabamos de copiar
RUN npm install -g /usr/local/share/npm-global/gemini-cli.tgz /usr/local/share/npm-global/gemini-core.tgz \
    && npm cache clean --force \
    && rm -f /usr/local/share/npm-global/gemini-{cli,core}.tgz

# Definimos o comando padrão para manter o contêiner ativo
CMD ["tail", "-f", "/dev/null"]
