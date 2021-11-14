FROM julia:1.7

RUN apt-get update && apt-get install --no-install-recommends -y git && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# COPY Project.toml .

# RUN julia -e 'using Pkg; Pkg.dev(""); Pkg.instantiate(); Pkg.precompile();'
