FROM debian:latest

RUN apt-get update && apt-get install -y \
    git \
    jq \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && apt-get install -y gh

WORKDIR /app
COPY . /app

# 🔥 **Ensure execute permissions for entrypoint.sh and all scripts**
RUN chmod +x /app/entrypoint.sh && chmod +x /app/*.sh

ENTRYPOINT ["/app/entrypoint.sh"]
