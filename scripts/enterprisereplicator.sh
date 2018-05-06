#!/bin/bash

iniciarenterprisereplicator () {
    echo Creamos el tópico \"topicreplicador\" en el dc1 ...

    docker exec -it dc1_kafka-1_1 kafka-topics --create \
        --topic topicreplicador --replication-factor 3 --partitions 3 \
        --zookeeper dc1_zookeeper-1_1:2181,dc1_zookeeper-2_1:2181,dc1_zookeeper-3_1:2181


    docker exec -it dc1_kafka-2_1 kafka-topics --describe \
        --topic topicreplicador \
        --zookeeper dc1_zookeeper-1_1:2181,dc1_zookeeper-2_1:2181,dc1_zookeeper-3_1:2181

    echo """
    Tópicos que tenemos en dc1 antes de crear el Connector Replicator ...
    """

    docker exec -it dc1_kafka-2_1 kafka-topics --list \
    --zookeeper dc1_zookeeper-1_1:2181,dc1_zookeeper-2_1:2181,dc1_zookeeper-3_1:2181

    echo """
    Tópicos que tenemos en dc2 antes de crear el Connector Replicator ...
    """

    docker exec -it dc2_kafka-2_1 kafka-topics --list \
    --zookeeper dc2_zookeeper-1_1:2181,dc2_zookeeper-2_1:2181,dc2_zookeeper-3_1:2181

    echo """
    Consultamos los nombres de los conectores que existen antes de crear ninguno. Debe retornarnos una lista vacía ...
    """

    docker exec -it dc2_replicator_1 \
        curl -X GET \
        http://dc2_replicator_1:28082/connectors

    echo """
    Creamos el conector 'conector-replicador' llamando a Kafka Connect REST API. Obligamos a que se clonen las particiones \
     es decir, las particiones del tópico \"topicreplicador\" se replicarán en contenido y orden desde el Datacenter A al Datacenter B ...
    """

    docker exec -it dc2_replicator_1 \
        curl -X POST \
             -H "Content-Type: application/json" \
             --data '{
                "name": "conector-replicador",
                "config": {
                  "connector.class":"io.confluent.connect.replicator.ReplicatorSourceConnector",
                  "key.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
                  "value.converter": "io.confluent.connect.replicator.util.ByteArrayConverter",
                  "src.zookeeper.connect": "dc1_zookeeper-1_1:2181,dc1_zookeeper-2_1:2181,dc1_zookeeper-3_1:2181",
                  "src.kafka.bootstrap.servers": "dc1_kafka-1_1:9092,dc1_kafka-2_1:9092,dc1_kafka-3_1:9092",
                  "dest.zookeeper.connect": "dc2_zookeeper-1_1:2181,dc2_zookeeper-2_1:2181,dc2_zookeeper-3_1:2181",
                  "topic.whitelist": "topicreplicador",
                  "topic.preserve.partitions": true}}'  \
             http://dc2_replicator_1:28082/connectors | json_pp

    echo """
    Comprobamos que Connector Replicator ha creado el tópico \"topicreplicador\" en Datacenter B ...
    """

    docker exec -it dc2_kafka-2_1 kafka-topics --describe \
        --topic topicreplicador \
        --zookeeper dc2_zookeeper-1_1:2181,dc2_zookeeper-2_1:2181,dc2_zookeeper-3_1:2181

    echo """
    Consultamos el estado del conector  \"conector-replicador\" ...
    """

    docker exec -it dc2_replicator_1 \
        curl -X GET \
        http://dc2_replicator_1:28082/connectors/conector-replicador/status | json_pp

    echo """
    Enterprise Replicator ha sido iniciado.
    """
}

ayuda () {
    echo  """
         Forma de uso:

         $ ./enterprisereplicator.sh iniciarenterprisereplicator
         $ ./enterprisereplicator.sh producir SinClave <nummensajes>
         $ ./enterprisereplicator.sh producir ConClave <nummensajes>
         $ ./enterprisereplicator.sh consumir dc1
         $ ./enterprisereplicator.sh consumir dc2
    """
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

    echo "Iniciando Enterprise Replicator ..."
    iniciarenterprisereplicator

    echo
    case $1 in
      "ConClave") echo """
                      Produciendo $nummensajes mensajes con clave ...
                  """
                  docker exec -it dc1_kafka-1_1 \
                     bash -c 'rm /tmp/mensajes.txt;for i in $(seq '$nummensajes'); do echo $(($i)):$i >> /tmp/mensajes.txt; done'
                  docker exec -it dc1_kafka-1_1 \
                     bash -c 'cat /tmp/mensajes.txt | \
                     kafka-console-producer \
                     --request-required-acks all \
                     --property "parse.key=true" --property "key.separator=:" \
                     --broker-list dc1_kafka-1_1:9092,dc1_kafka-2_1:9092,dc1_kafka-3_1:9092 \
                     --topic topicreplicador'; ;;
      "SinClave") echo """
                     Produciendo $nummensajes mensajes sin clave en el datacenter principal ...
                  """
                  docker exec -it dc1_kafka-1_1 \
                                         bash -c "seq '$nummensajes' | kafka-console-producer \
                                         --request-required-acks 1 \
                                         --broker-list dc1_kafka-1_1:9092,dc1_kafka-2_1:9092,dc1_kafka-3_1:9092 \
                                         --topic topicreplicador && echo $nummensajes' mensajes producidos.'"; ;;
      *) ayuda; ;;
    esac

}

consumir () {
    echo "Consumiendo los mensajes del tópico \"topicreplicador\" del $1 ..."
    bash -c "docker exec -it $1_kafka-3_1 \
               kafka-console-consumer \
               --topic topicreplicador  \
                    --property 'print.timestamp=true' \
                    --property 'print.key=true' \
                    --property 'print.offset=true' \
               --bootstrap-server $1_kafka-1_1:9092,$1_kafka-2_1:9092,$1_kafka-3_1:9092 \
               --from-beginning"
}


case $1 in
  "iniciarenterprisereplicator") iniciarenterprisereplicator; ;;
  "producir")  if [ $2 == "SinClave" ] || [ $2 == "ConClave" ]  ; then
                    producir $2 $3
               else
                 echo """

   ERROR: falta indicar con el segundo parámetro si se está produciendo sin clave o con clave

                 """
                 ayuda
               fi; ;;
  "consumir")  if [ $2 == "dc1" ] || [ $2 == "dc2" ]  ; then
                    consumir $2
               else
                 echo """

    ERROR: falta indicar con el segundo parámetro si se está consumiendo de dc1 o de dc2

                 """
                 ayuda
               fi; ;;
  *) ayuda; ;;
esac

