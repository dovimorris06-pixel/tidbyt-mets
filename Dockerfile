FROM golang:1.21

# Install pixlet
RUN curl -LO https://github.com/tidbyt/pixlet/releases/download/v0.34.0/pixlet_0.34.0_linux_amd64.tar.gz && \
    tar -xzf pixlet_0.34.0_linux_amd64.tar.gz && \
    mv pixlet /usr/local/bin/ && \
    rm pixlet_0.34.0_linux_amd64.tar.gz

# Install Python
RUN apt-get update && apt-get install -y python3 python3-pip

WORKDIR /app

COPY mets_mlb.star .
COPY push.py .

CMD ["python3", "push.py"]
