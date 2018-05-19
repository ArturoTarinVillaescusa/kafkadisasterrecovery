#!/bin/bash

iniciarmirrormaker () {
    echo """
    Iniciando MirrorMaker ...
    Creamos el tópico "topicmirrormaker" en kafka de mi laptop ...
    """

    /opt/kafka/bin/kafka-topics.sh --delete \
        --topic topicmirrormaker \
        --zookeeper broker1:2181,broker2:2181,broker3:2181

    /opt/kafka/bin/kafka-topics.sh --create \
        --topic topicmirrormaker --replication-factor 3 --partitions 3 \
        --zookeeper broker1:2181,broker2:2181,broker3:2181

    echo
    /opt/kafka/bin/kafka-topics.sh --describe \
        --topic topicmirrormaker \
        --zookeeper broker1:2181,broker2:2181,broker3:2181

    echo """
    Creamos el tópico "topicmirrormaker" en kafka de gcloud ...
    """
    
    /opt/kafka/bin/kafka-topics.sh --delete \
        --topic topicmirrormaker \
        --zookeeper 35.189.219.82:2181

    /opt/kafka/bin/kafka-topics.sh --create \
        --topic topicmirrormaker --replication-factor 1 --partitions 1 \
        --zookeeper 35.189.219.82:2181

    echo
    /opt/kafka/bin/kafka-topics.sh --describe \
        --topic topicmirrormaker \
        --zookeeper 35.189.219.82:2181

    echo """
        MirrorMaker ha sido arrancado en local ...
        Puedes verificar el funcionamiento de la réplica de mensajes entre local y GCloud
        abriendo dos nuevos terminales y lanzando en uno de ellos el comando
        $ ./mirrormaker.sh consumir local
        y en el otro
        $ ./mirrormaker.sh consumir cloud
        PULSA Ctrl+C para terminar MirrorMaker
    """

    export KAFKA_HEAP_OPTS="-Xmx1024M -Xms1024M -XX:+HeapDumpOnOutOfMemoryError"
    /opt/kafka/bin/kafka-mirror-maker.sh \
              --consumer.config config/consumermirrormaker.properties  \
              --producer.config config/producermirrormaker.properties \
              --whitelist="topicmirrormaker" &
}

producir () {
    if [ -z "$2" ]
      then
        echo """
           Falta indicar cuantos mensajes hay que producir
        """
        ayuda
        exit 0
    fi

    nummensajes=$(($2))

    echo "Produciendo $nummensajes mensajes en el tópico \"topicmirrormaker\" de kafka de mi laptop ..."

    echo
    case $1 in
      "mensaje2bytesConClave") bash -c 'rm /tmp/mensajes.txt;for i in $(seq '$nummensajes'); \
                           do echo $(($i % 10)):$i >> /tmp/mensajes.txt; done';
                  bash -c 'cat /tmp/mensajes.txt | \
                   /opt/kafka/bin/kafka-console-producer.sh \
                   --request-required-acks 1 \
                   --property "parse.key=true" --property "key.separator=:" \
                   --broker-list broker1:9092,broker2:9092,broker3:9092 \
                   --topic topicmirrormaker'; ;;                           
      "mensaje24kbytesConClave1a1")
                  bash -c 'for i in $(seq '$nummensajes'); \
                           do echo $(($i % 10)):"$(cat FALSOJSONMensaje1250SARSIMILARSIZE.xml)" | \
                           /opt/kafka/bin/kafka-console-producer.sh \
						   --request-required-acks 1 \
						   --property "parse.key=true" --property "key.separator=:" \
						   --broker-list broker1:9092,broker2:9092,broker3:9092 \
						   --topic topicmirrormaker; \
                           done'; ;;
      "mensaje24kbytesConClave") 
		  bash -c 'rm /tmp/mensajes.txt; \
				   for i in $(seq '$nummensajes'); do \
					 echo $(($i % 10)):"$(cat FALSOJSONMensaje1250SARSIMILARSIZE.xml)"  >> /tmp/mensajes.txt; \
				     if (( $i % 10 == 0 )); \
				     then \
						 cat /tmp/mensajes.txt | /opt/kafka/bin/kafka-console-producer.sh \
							 --request-required-acks 1 \
							 --property "parse.key=true" --property "key.separator=:" \
							 --broker-list broker1:9092,broker2:9092,broker3:9092 \
							 --topic topicmirrormaker; \
						 rm /tmp/mensajes.txt; \
					 fi \
				   done';
		  bash -c 'cat /tmp/mensajes.txt | /opt/kafka/bin/kafka-console-producer.sh \
					 --request-required-acks 1 \
					 --property "parse.key=true" --property "key.separator=:" \
					 --broker-list broker1:9092,broker2:9092,broker3:9092 \
					 --topic topicmirrormaker'; ;;
      "SinClave") bash -c "seq '$nummensajes' | \
					/opt/kafka/bin/kafka-console-producer.sh \
				   --broker-list broker1:9092,broker2:9092,broker3:9092 \
				   --topic topicmirrormaker && echo '$nummensajes' mensajes producidos."; ;;
      *) ayuda; ;;
    esac

}

consumir () {
    echo "Consumiendo los mensajes enviados al tópico \"topicmirrormaker\" del Kafka en $1 ..."
    
    echo
    case $1 in
      "local") bash -c "/opt/kafka/bin/kafka-console-consumer.sh \
						--property 'print.timestamp=true' \
						--property 'print.key=true' \
						--property 'print.offset=true' \
						--bootstrap-server broker1:9092,broker2:9092,broker3:9092 \
						--topic topicmirrormaker &"; ;;
      "cloud") bash -c "/opt/kafka/bin/kafka-console-consumer.sh \
						--property 'print.timestamp=true' \
						--property 'print.key=true' \
						--property 'print.offset=true' \
						--bootstrap-server 35.189.219.82:9092 \
						--topic topicmirrormaker &"; ;;
      *) ayuda; ;;
    esac
}

ayuda () {
   clear
    echo """
   Forma de uso:

   Arrancar MirrorMaker desde una ventana con el comando

   $ ./mirrormaker.sh iniciarmirrormaker

   A continuación, abrir otra ventana y producir mensajes en el tópico "topicmirrormaker" del Kafka local usando el comando

   $ ./mirrormaker.sh producir SinClave <nummensajes>

   o

   $ ./mirrormaker.sh producir mensaje2bytesConClave <nummensajes>
   o
   $ ./mirrormaker.sh producir mensaje24kbytesConClave <nummensajes>
   o
   $ ./mirrormaker.sh producir mensaje24kbytesConClave1a1 <nummensajes>

   Abrir otra ventana más y consumir los mensajes replicados al tópico "topicmirrormaker" del Kafka en GCloud usando el comando

   $ ./mirrormaker.sh consumir local

   o

   $ ./mirrormaker.sh consumir cloud
    """
    
for (( counter = 0; counter <= 5000; counter++ ))
do
    if (( counter % 1000 == 0 ))
    then
            echo "$(( counter / 1000 ))"
    fi
done    
 }



case $1 in
  "iniciarmirrormaker") iniciarmirrormaker; ;;
  "producir")  if [ $2 == "SinClave" ] || 
                  [ $2 == "mensaje2bytesConClave" ]  || 
				  [ $2 == "mensaje24kbytesConClave" ] || 
				  [ $2 == "mensaje24kbytesConClave1a1" ] ; then
                    producir $2 $3
               else
                 echo """
                 ERROR: falta indicar con el segundo parámetro si se está produciendo mensajes pequeños o grandes con clave, o mensajes pequeños sin clave
                 """
                 ayuda
               fi; ;;
  "consumir")  if [ $2 == "local" ] || [ $2 == "cloud" ]  ; then
                    consumir $2
               else
                 echo """
                 ERROR: falta indicar con el segundo parámetro si se está consumiendo de Kafka local local o de Kafka en GCloud
                 """
                 ayuda
               fi; ;;
  *) ayuda; ;;
esac
