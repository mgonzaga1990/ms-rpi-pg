#!/bin/bash

PGDATA='/etc/postgresql/12/main'

#Validate if Master already exists
echo "Validating Master Host"
MASTER_HOST=$(nslookup pg-master-0.pg-master-headless | awk 'FNR == 5 {print $2}')

#set listen all
echo "Updating listener"
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g"  ${PGDATA}/postgresql.conf

#WAL Level
echo "setting wal_level to host_standby"
sed -i "s/#wal_level/wal_level/g"  ${PGDATA}/postgresql.conf

#WAL Senders
echo "setting max_wal_senders to 20"
sed -i "s/#max_wal_senders = 10/max_wal_senders = 20/g"  ${PGDATA}/postgresql.conf

#WAL Segments
echo "setting wal_keep_segments to 10"
sed -i "s/#wal_keep_segments = 0/wal_keep_segments = 10/g"  ${PGDATA}/postgresql.conf


if [ "x$MASTER_HOST" == "x" ]; then
 echo "There is no existing Master Server detected!"
 echo "Starting up as Master Server"
 
 #Test start up
 gosu postgres /etc/init.d/postgresql start
 gosu postgres /etc/init.d/postgresql status

 #Modify postgresql.conf
 echo "Updating host in pg_hba.conf"
 { echo; echo "host replication all 0.0.0.0/0 trust"; } | gosu postgres tee -a "$PGDATA/pg_hba.conf" > /dev/null
 { echo; echo "host all all 0.0.0.0/0 trust"; } | gosu postgres tee -a "$PGDATA/pg_hba.conf" > /dev/null


 #Create replica user
 echo "Creating replica user for slaves"
 if [ "$POSTGRES_USER" = 'postgres' ]; then
  op='ALTER'
 else
  op='CREATE'
 fi
 
 #gosu postgres /etc/init.d/postgresql psql -U 

 echo "Restarting server"
 gosu postgres /etc/init.d/postgresql restart

else
 echo "Master Detected : " $MASTER_HOST

 #Check if can reach the master
 until ping -c 1 -W 1 ${MASTER_HOST}
    do
       echo "Waiting for master to ping..."
	sleep 1s
    done

 #remove directory this will be replaced by the base backup
 echo "Purging directory " ${PGDATA}
 cp -R ${PGDATA} /pg_backup
 gosu postgres rm -rf ${PGDATA}

 #Pull updated copies from master
 echo "executing base backup. . . . . . . . . . ."
 until gosu postgres pg_basebackup -h ${MASTER_HOST} -p 5432 -D ${PGDATA} -U postgres -vP -w
    do
       echo "Waiting for master to connect..."
        sleep 1s
    done

 echo "archive_mode = 'on'" >> ${PGDATA}/postgresql.conf
 echo "archive_command = 'cp %p /var/lib/postgresql/12/main/archive/%f'" >> ${PGDATA}/postgresql.conf

 gosu postgres /etc/init.d/postgresql start
 gosu postgres /etc/init.d/postgresql status

fi

#tail log
tail -f /var/log/postgresql/postgresql-12-main.log
