FROM ubuntu:jammy

RUN apt-get update && apt-get install -y mysql-client bash

WORKDIR /app

ADD . .

CMD ["bash", "migrate.sh"]
