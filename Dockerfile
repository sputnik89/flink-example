FROM flink:2.3.0-scala_2.12-java17

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 python3-venv python3-dev build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt pyproject.toml /tmp/pyflink-lab/
RUN python3 -m venv /opt/pyflink \
    && /opt/pyflink/bin/python3 -m pip install --no-cache-dir 'uv==0.12.13' \
    && /opt/pyflink/bin/uv pip install --no-cache \
        --python /opt/pyflink/bin/python3 --project /tmp/pyflink-lab \
        -r /tmp/pyflink-lab/requirements.txt

ENV PATH="/opt/pyflink/bin:${PATH}"
# Make the Python runtime JAR available to the standalone cluster.
RUN cp /opt/flink/opt/flink-python-*.jar /opt/flink/lib/

USER flink
