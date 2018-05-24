
Index	1
1) CREATE THE KAFKA INFRASTRUCTURE IN GOOGLE CLOUD	2
2) CONFIGURE GCLOUD’S KAFKA INFRASTRUCTURE SO THAT WE CAN PRODUCE MESSAGES IN HIS TOPICS FROM OUR LOCAL MACHINES	4
3) TESTING IN CUSTOMER’S INFRASTRUCTURE	5
TEST 1: REPLICATE 1.000 24 Kbytes MESSAGES FROM CUSTOMER KAFKA alcafka01 and madkafka01 to GOOGLE CLOUD’S KAFKA	5
TEST 2: REPLICATE 10.000 24 Kbytes MESSAGES FROM CUSTOMER KAFKA alcafka01 and madkafka01 to GOOGLE CLOUD’S KAFKA	6
STRESS TESTS WITH JMETER	7


1) DOCUMENT OBJECTIVE
PoC: Replicate messages from a topic in our customer's virtualized on-premise Kafka standalone framework to a Kafka topic in  Google Cloud using MirrorMaker
2) CREATING THE KAFKA INFRASTRUCTURE IN GOOGLE CLOUD

Instantiate a “Kafka Google Compute Engine” node in GCloud:

3) CONFIGURING GCLOUD’S KAFKA INFRASTRUCTURE SO THAT WE CAN PRODUCE MESSAGES IN HIS TOPICS FROM OUR LOCAL MACHINES

ssh arturo@35.205.74.176

root@kafka-1-vm:/# vi /opt/kafka/config/server.properties

advertised.listeners=PLAINTEXT://35.205.74.176:9092
advertised.host.name=35.205.74.176
port=9092


root@kafka-1-vm:~# service zookeeper restart
root@kafka-1-vm:~# service kafka restart

root@kafka-1-vm:~# service kafka status
● kafka.service - Apache Kafka Server
   Loaded: loaded (/lib/systemd/system/kafka.service; enabled; vendor preset: enabled)
   Active: active (exited) since Sat 2018-05-12 06:24:24 UTC; 20min ago
  Process: 7809 ExecStop=/opt/kafka/bin/c2d-service.sh stop (code=exited, status=0/SUCCESS)
  Process: 7850 ExecStart=/opt/kafka/bin/c2d-service.sh start (code=exited, status=0/SUCCESS)
 Main PID: 7850 (code=exited, status=0/SUCCESS)
	Tasks: 64 (limit: 4915)
   CGroup: /system.slice/kafka.service
       	└─8346 java -Xmx1G -Xms1G -server -XX:+UseG1GC -XX:MaxGCPauseMillis=20 -XX:InitiatingHeapOccupancyPercent=35 -XX:

May 12 06:24:24 kafka-1-vm systemd[1]: Stopped Apache Kafka Server.
May 12 06:24:24 kafka-1-vm systemd[1]: Started Apache Kafka Server.


root@kafka-1-vm:~# service zookeeper status
● zookeeper.service - Coordination service for distributed applications
   Loaded: loaded (/lib/systemd/system/zookeeper.service; enabled; vendor preset: enabled)
   Active: active (running) since Sat 2018-05-12 06:19:36 UTC; 13s ago
 Main PID: 7452 (java)
	Tasks: 15 (limit: 4915)
   CGroup: /system.slice/zookeeper.service
       	└─7452 /usr/bin/java -cp /etc/zookeeper/conf:/usr/share/java/jline.jar:/usr/share/java/log4j-1.2.jar:/usr/share/j

May 12 06:19:36 kafka-1-vm systemd[1]: Stopped Coordination service for distributed applications.
May 12 06:19:36 kafka-1-vm systemd[1]: Started Coordination service for distributed applications.


3) REPLICATION TESTING

Let’s see how MirrorMaker deals with message replication from on-premises Kafka to GCloud Kafka.
TEST 1: REPLICATE 1.000 24 Kbytes MESSAGES FROM CUSTOMER KAFKA alcafka01 and madkafka01 to GOOGLE CLOUD’S KAFKA

operador@alckafka01:~/scripts_de_pruebas$ ./mirrormaker.sh iniciarmirrormaker

    Iniciando MirrorMaker ...
    Creamos el tópico topicmirrormaker en kafka de mi laptop ...

Topic topicmirrormaker is marked for deletion.
Note: This will have no impact if delete.topic.enable is not set to true.
Created topic "topicmirrormaker".

Topic:topicmirrormaker  PartitionCount:1        ReplicationFactor:1     Configs:
        Topic: topicmirrormaker Partition: 0    Leader: 0       Replicas: 0     Isr: 0

    Creamos el tópico topicmirrormaker en kafka de gcloud ...

Topic topicmirrormaker is marked for deletion.
Note: This will have no impact if delete.topic.enable is not set to true.
Created topic "topicmirrormaker".

Topic:topicmirrormaker  PartitionCount:1        ReplicationFactor:1     Configs:
        Topic: topicmirrormaker Partition: 0    Leader: 0       Replicas: 0     Isr: 0

        MirrorMaker ha sido arrancado en local ...
        Puedes verificar el funcionamiento de la réplica de mensajes entre local y GCloud
        abriendo dos nuevos terminales y lanzando en uno de ellos el comando
        $ ./mirrormaker.sh consumir local
        y en el otro
        $ ./mirrormaker.sh consumir cloud
        PULSA Ctrl+C para terminar MirrorMaker

operador@alckafka01:~/scripts_de_pruebas$ ./mirrormaker.sh producir mensaje24kbytesConClave 1000
Produciendo 1000 mensajes en el tópico "topicmirrormaker" de kafka de mi laptop ...

rm: cannot remove '/tmp/mensajes.txt': No such file or directory
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>[2018-05-14 14:09:13,022] WARN [Producer clientId=console-producer] Got error produce response with correlation id 7 on topic-partition topicmirrormaker-0, retrying (2 attempts left). Error: NETWORK_EXCEPTION (org.apache.kafka.clients.producer.internals.Sender)
[2018-05-14 14:09:13,023] WARN [Producer clientId=console-producer] Got error produce response with correlation id 6 on topic-partition topicmirrormaker-0, retrying (2 attempts left). Error: NETWORK_EXCEPTION (org.apache.kafka.clients.producer.internals.Sender)
[2018-05-14 14:09:13,023] WARN [Producer clientId=console-producer] Got error produce response with correlation id 5 on topic-partition topicmirrormaker-0, retrying (2 attempts left). Error: NETWORK_EXCEPTION (org.apache.kafka.clients.producer.internals.Sender)
[2018-05-14 14:09:13,023] WARN [Producer clientId=console-producer] Got error produce response with correlation id 4 on topic-partition topicmirrormaker-0, retrying (2 attempts left). Error: NETWORK_EXCEPTION (org.apache.kafka.clients.producer.internals.Sender)
[2018-05-14 14:09:13,023] WARN [Producer clientId=console-producer] Got error produce response with correlation id 3 on topic-partition topicmirrormaker-0, retrying (2 attempts left). Error: NETWORK_EXCEPTION (org.apache.kafka.clients.producer.internals.Sender)
[2018-05-14 14:09:14,627] WARN [Producer clientId=console-producer] Got error produce response with correlation id 14 on topic-partition topicmirrormaker-0, retrying (1 attempts left). Error: NETWORK_EXCEPTION (org.apache.kafka.clients.producer.internals.Sender)
[2018-05-14 14:09:14,628] WARN [Producer clientId=console-producer] Got error produce response with correlation id 13 on topic-partition topicmirrormaker-0, retrying (1 attempts left). Error: NETWORK_EXCEPTION (org.apache.kafka.clients.producer.internals.Sender)
[2018-05-14 14:09:14,628] WARN [Producer clientId=console-producer] Got error produce response with correlation id 12 on topic-partition topicmirrormaker-0, retrying (1 attempts left). Error: NETWORK_EXCEPTION (org.apache.kafka.clients.producer.internals.Sender)
[2018-05-14 14:09:14,628] WARN [Producer clientId=console-producer] Got error produce response with correlation id 11 on topic-partition topicmirrormaker-0, retrying (1 attempts left). Error: NETWORK_EXCEPTION (org.apache.kafka.clients.producer.internals.Sender)
[2018-05-14 14:09:14,628] WARN [Producer clientId=console-producer] Got error produce response with correlation id 10 on topic-partition topicmirrormaker-0, retrying (1 attempts left). Error: NETWORK_EXCEPTION (org.apache.kafka.clients.producer.internals.Sender)
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>cat: /tmp/mensajes.txt: No such file or directory


operador@alckafka01:~/scripts_de_pruebas$ ./mirrormaker.sh consumir local
...
Ty1RoDOrDlkOVvwb</diagram></mxfile>
Processed a total of 1000 messages


operador@alckafka01:~/scripts_de_pruebas$ ./mirrormaker.sh consumir cloud
...
Ty1RoDOrDlkOVvwb</diagram></mxfile>
Processed a total of 1000 messages
TEST RESULTS

1.000 Messages produced in 3 seconds, and replicated to Google Cloud in 7 seconds. Some NETWORK_EXCEPTION but no message were lost.
TEST 2: REPLICATE 10.000 24 Kbytes MESSAGES FROM CUSTOMER KAFKA alcafka01 and madkafka01 to GOOGLE CLOUD’S KAFKA

TEST RESULTS

10.000 messages were sent to be produced in 41 seconds, 400 weren’t due to producer timeouts, but the 9.600 were replicated to Google Cloud in 100 seconds.

4) PERFORMANCE, PEAKS AND RAMPUP TESTS

TEST1: LINEA_BASE_PRODUCTOR_ONLINE with 100 concurrent messages per second during 5 minutes

Configuration file:

operador@alckafka01:~$ cat scripts/config/LINEA_BASE_PRODUCTOR_ONLINE.properties
DURACION=60
METRONOMO=1000
JMX="./Productor.jmx"
NUMHILOS=100
BUCLE=1000000

Launch command:

operador@alckafka01:~$ scripts/testJmeter.sh LINEA_BASE_PRODUCTOR_ONLINE

Test results: 

the machine doesn’t get stressed, all the messages have been replicated from alckafka01 to Google Cloud

TEST2: LINEA_BASE_PRODUCTOR_ONLINE with 200 concurrent messages per second during 5 minutes

Configuration file:

operador@alckafka01:~$ cat scripts/config/LINEA_BASE_PRODUCTOR_ONLINE.properties
DURACION=60
METRONOMO=1000
JMX="./Productor.jmx"
NUMHILOS=200
BUCLE=1000000

Launch command:

operador@alckafka01:~$ scripts/testJmeter.sh LINEA_BASE_PRODUCTOR_ONLINE

Test results:

The machine resources are almost exhausted, 100% memory and cpu consumption, 100% swaping to disk. Local consumer has no resources and it looses half of the produces messages, but curiously MirrorMaker has been able to replicate to Gcloud all the produced messages.

TEST 3: LINEA_BASE_PRODUCTOR_ONLINE with 400 concurrent messages per second during 1 minute

The machine gets into panic and crashes. No messages produced and no replicas to Gcloud were made.

TEST3: LINEA_BASE_PRODUCTOR_ONLINE with 100 concurrent messages per second during one hour

Configuration file:

operador@alckafka01:~$ cat scripts/config/LINEA_BASE_PRODUCTOR_ONLINE.properties
DURACION=3600
METRONOMO=1000
JMX="./Productor.jmx"
NUMHILOS=100
BUCLE=1000000

Launch command:

operador@alckafka01:~$ scripts/testJmeter.sh LINEA_BASE_PRODUCTOR_ONLINE

LAUNCH PENDING TO BE APPROVED




