# PyFlink Lab

## Prerequisites

- macOS or Linux with Bash
- For local runs: Java 17 on `PATH` or through `JAVA_HOME`, and curl if uv is missing
- For Docker runs: Docker with Compose

## Setup

### Local

```sh
./setup.sh
source .venv/bin/activate
```

### Docker

Start Docker, then run:

```sh
docker compose up --build -d --wait
```

## Example runs

### Local

Process the sample sentences once:

```sh
python3 process.py
```

Run continuously with the Web UI:

```sh
python3 process.py --stream --web-ui
```

Open <http://localhost:8081>. Stop with Ctrl+C.

### Docker

Submit the job:

```sh
docker compose exec jobmanager flink run -d \
  --python /opt/flink/usrlib/process.py --stream --parallelism 1
```

Open <http://localhost:8081> to inspect the job. View its output:

```sh
docker compose logs -f taskmanager
```

Stop following logs with Ctrl+C. List and cancel the job using its ID:

```sh
docker compose exec jobmanager flink list
docker compose exec jobmanager flink cancel JOB_ID
```

Stop the cluster:

```sh
docker compose down
```

For simultaneous local and Docker demos, use
`FLINK_UI_PORT=8082 docker compose up --build -d --wait` and open
<http://localhost:8082> for Docker.
