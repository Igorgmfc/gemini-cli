# --- Estágio 1: Builder (Onde a Mágica Acontece) ---
# Usamos uma imagem Node.js mínima, mas completa o suficiente para compilar.
# 'as builder' dá um nome a este estágio para que possamos copiar arquivos dele mais tarde.
FROM docker.io/library/node:20-slim as builder

# Definimos o diretório de trabalho dentro do contêiner.
WORKDIR /app

# CIRURGIA 1: Instalar o 'git'
# MOTIVO: O script de instalação do Gemini CLI (npm install) tenta executar
# o comando `git` para obter informações de versão. Sem o `git` instalado
# neste ambiente de build, o script falha.
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*

# Copiamos TODOS os arquivos do seu repositório para o contêiner.
# Isso garante que todos os scripts e códigos estejam disponíveis para os próximos passos.
COPY . .

# Agora, rodamos o npm install. Com o 'git' presente, o script
# 'prepare' -> 'bundle' -> 'generate' pode ser executado como os
# desenvolvedores originais pretendiam, criando o arquivo `git-commit.js`.
RUN npm install

# Executamos o comando 'package' (que descobrimos ser o correto)
# para compilar e empacotar a CLI nos arquivos .tgz necessários.
RUN npm run package


# --- Estágio 2: Imagem Final (Limpa e Otimizada) ---
# Começamos de uma nova imagem Node.js limpa. Isso garante que a imagem final
# não contenha ferramentas de build desnecessárias (como o git), tornando-a menor e mais segura.
FROM docker.io/library/node:20-slim

# Instalamos apenas as dependências de sistema que a CLI PRECISA para rodar.
# Note que `git` também está aqui porque a própria CLI pode usá-lo em tempo de execução.
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 make g++ man-db curl dnsutils less jq bc gh git unzip \
    rsync ripgrep procps psmisc lsof socat ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Configuramos um diretório global para o NPM e o adicionamos ao PATH.
# Isso garante que qualquer pacote instalado com `npm install -g` seja encontrado.
RUN mkdir -p /usr/local/share/npm-global \
    && chown -R node:node /usr/local/share/npm-global
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=$PATH:/usr/local/share/npm-global/bin

# Trocamos para um usuário não-root ('node') por segurança.
USER node

# A MÁGICA DO MULTI-STAGE: Copiamos APENAS os arquivos .tgz compilados
# do nosso estágio 'builder'. Não trazemos o código-fonte ou as dependências de build.
COPY --from=builder /app/packages/cli/dist/google-gemini-cli-*.tgz /usr/local/share/npm-global/gemini-cli.tgz
COPY --from=builder /app/packages/core/dist/google-gemini-cli-core-*.tgz /usr/local/share/npm-global/gemini-core.tgz

# Agora, na imagem limpa, instalamos a CLI globalmente a partir desses pacotes.
# Isso coloca o executável `gemini` no PATH global.
RUN npm install -g /usr/local/share/npm-global/gemini-cli.tgz /usr/local/share/npm-global/gemini-core.tgz \
    && npm cache clean --force \
    && rm -f /usr/local/share/npm-global/gemini-{cli,core}.tgz

# ALTERAÇÃO FINAL: Definimos o comando padrão para manter o contêiner ativo.
# O Coolify precisa que o contêiner fique rodando. `tail -f /dev/null` é um
# comando inofensivo que nunca termina, mantendo o contêiner "vivo".
CMD ["tail", "-f", "/dev/null"]
