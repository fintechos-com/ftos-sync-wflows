FROM ubuntu:latest

# Install dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    jq \
    gh

# Set working directory
WORKDIR /app

# Copy the entrypoint script
COPY entrypoint.sh /entrypoint.sh

# Give execution permissions
RUN chmod +x /entrypoint.sh

# Run the script
ENTRYPOINT ["/entrypoint.sh"]
