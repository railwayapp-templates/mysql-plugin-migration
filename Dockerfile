FROM alpine

RUN apk update && apk add mysql-client bash ncurses

WORKDIR app

ADD . .

CMD bash migrate.sh
