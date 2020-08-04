FROM ubuntu

MAINTAINER Mark Jayson Gonzaga

RUN apt-get update && apt-get install iputils-ping dnsutils -y

RUN apt install wget gosu gnupg2 -y
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc \
   | apt-key add - 

RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" |tee  /etc/apt/sources.list.d/pgdg.list

RUN apt install postgresql-12 -y 

COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 5432

ENTRYPOINT /entrypoint.sh
