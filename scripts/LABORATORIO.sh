#!/bin/bash

# set -x

verificarparametros () {

    echo
    if [ -z "$INDICE_REPLICACION_DATACENTER" ]; then
            echo "Falta indicar el número de réplicas que vamos a crear del datacenter $TIPO_DATACENTER"
    fi

    if [ -z "$CP_VERSION" ]; then
            echo "Falta indicar la versión de Confluent"
    fi

    if [ -z "$ZOOKEEPER_PORT" ]; then
            echo "Falta indicar el puerto de Zookeeper"
    fi

    if [ -z "$BROKER_PORT" ]; then
            echo "Falta indicar el puerto de Kafka Broker"
    fi

    if [ -z "$CP_VERSION" ] || [ -z "$ZOOKEEPER_PORT" ] || [ -z "$BROKER_PORT" ]; then
            echo
            ayuda
            exit 0
    fi

}

iniciarcontenedores () {
    # Creamos una red común a todos los datacenter
    docker network create $RED 2>/dev/null

    # Iniciamos el datacenter principal
    export DATACENTER=dc1

   docker-compose -p $DATACENTER -f $DOCKER_COMPOSE_ZK_KAFKA -f $DOCKER_COMPOSE_SCHEMA_REGISTRY \
         -f $DOCKER_COMPOSE_KAFKA_CONNECT -f $DOCKER_COMPOSE_KAFKA_REST -f $DOCKER_COMPOSE_DB2_ELK_MYSQL \
         up -d --remove-orphans zookeeper-1 zookeeper-2 zookeeper-3 kafka-1 kafka-2 kafka-3 #kafka-connect-1 \
         #kafka-connect-2 kafka-connect-3 kafka-rest-1 kafka-rest-2 kafka-rest-3 edgenode

    # Iniciamos Enterprise Replicator en el datacenter secundario
   docker-compose -p dc2 -f $DOCKER_COMPOSE_REPLICATOR \
         up -d --scale replicator-1=$NODOS_REPLICATOR --remove-orphans replicator

  # Iniciamos los datacenter de réplica
  for i in $(seq 2 $INDICE_REPLICACION_DATACENTER); do
        # Asignamos nuevos grupos de valores a los "BINDING_PORT", para que no choquen con los ya existentes
        export REST_BINDING_PORT_1=$((REST_BINDING_PORT_1 + 3))
        export REST_BINDING_PORT_2=$((REST_BINDING_PORT_1 + 1))
        export REST_BINDING_PORT_3=$((REST_BINDING_PORT_2 + 1))
        export REGISTRY_BINDING_PORT_1=$((REGISTRY_BINDING_PORT_1 + 3))
        export REGISTRY_BINDING_PORT_2=$((REGISTRY_BINDING_PORT_1 + 1))
        export REGISTRY_BINDING_PORT_3=$((REGISTRY_BINDING_PORT_2 + 1))
        export CONNECT_BINDING_PORT_1=$((CONNECT_BINDING_PORT_1 + 3))
        export CONNECT_BINDING_PORT_2=$((CONNECT_BINDING_PORT_1 + 1))
        export CONNECT_BINDING_PORT_3=$((CONNECT_BINDING_PORT_2 + 1))
        export DATACENTER=dc$i
        export BROKER_MIRROR_MAKER=dc$i\_kafka-1_1

        docker-compose -p $DATACENTER -f $DOCKER_COMPOSE_ZK_KAFKA -f $DOCKER_COMPOSE_REPLICATOR \
             -f $DOCKER_COMPOSE_KAFKA_CONNECT -f $DOCKER_COMPOSE_KAFKA_REST -f $DOCKER_COMPOSE_SCHEMA_REGISTRY \
             up -d --scale replicator-1=$NODOS_REPLICATOR --remove-orphans \
             zookeeper-1 zookeeper-2 zookeeper-3 kafka-1 kafka-2 kafka-3 replicator

        # Levamos al broker los archivos de configuración de mirror maker
        docker cp config/consumerdatacenterb.properties $BROKER_MIRROR_MAKER:/etc/kafka
        docker cp config/producerdatacenterb.properties $BROKER_MIRROR_MAKER:/etc/kafka

    done

    estadocontenedores

    configurarcontenedores

}

configurarcontenedores() {

  echo Configuramos MirrorMaker ...
  docker cp config/consumerdatacenterb.properties dc2_kafka-1_1:/etc/kafka 2> /dev/null
  docker cp config/producerdatacenterb.properties dc2_kafka-1_1:/etc/kafka 2> /dev/null
  docker cp config/consumerdatacenterb.properties dc2_kafka-2_1:/etc/kafka 2> /dev/null
  docker cp config/producerdatacenterb.properties dc2_kafka-2_1:/etc/kafka 2> /dev/null
  docker cp config/consumerdatacenterb.properties dc2_kafka-3_1:/etc/kafka 2> /dev/null
  docker cp config/producerdatacenterb.properties dc2_kafka-3_1:/etc/kafka 2> /dev/null

}

estadocontenedores () {
    docker-compose -p dc1 -f $DOCKER_COMPOSE_ZK_KAFKA -f $DOCKER_COMPOSE_SCHEMA_REGISTRY \
       -f $DOCKER_COMPOSE_KAFKA_CONNECT -f $DOCKER_COMPOSE_KAFKA_REST -f $DOCKER_COMPOSE_REPLICATOR \
       -f $DOCKER_COMPOSE_DB2_ELK_MYSQL ps

    docker-compose -p dc2 -f $DOCKER_COMPOSE_REPLICATOR ps

    for i in $(seq 2 $INDICE_REPLICACION_DATACENTER); do
        docker-compose -p dc$i -f $DOCKER_COMPOSE_ZK_KAFKA -f $DOCKER_COMPOSE_SCHEMA_REGISTRY \
             -f $DOCKER_COMPOSE_KAFKA_CONNECT -f $DOCKER_COMPOSE_KAFKA_REST -f $DOCKER_COMPOSE_REPLICATOR \
             -f $DOCKER_COMPOSE_DB2_ELK_MYSQL ps
    done
}

pararcontenedores () {
    for i in `docker ps | awk '{print $1}' | grep -v CONTAINER`; do docker stop $i; done
    exit 0
}

borrarcontenedores () {
  for i in `sudo docker ps | awk '{print $1}' | grep -v CONTAINER `; do sudo docker stop $i; done
  for i in `sudo docker ps -a | awk '{print $1}' | grep -v CONTAINER `; do sudo docker rm $i; done
  echo "Contenedores borrados"

  exit 0
}

ayuda () {
      echo  """
         Forma de uso:

         ./LABORATORIO.sh iniciar [dc1|dc2|todo]

         ./LABORATORIO.sh verificar

         ./LABORATORIO.sh parar [dc1|dc2|todo]

         ./LABORATORIO.sh borrar

         []: indica que es obligatorio elegir. Por ejemplo, "iniciar" requerirá indicar si vamos a iniciar únicamente
         dc1 o si vamos a iniciar todos los datacenter.

          * 'dc1' se refiere a los contenedores del rac principal.
          * 'dc2' se refiere a los contenedores del rac secundario.
          * 'todo' se refiere a todos los datacenter del laboratorio.
      """

      exit 1
}

iniciarEntornos () {

      if [ -z $2 ] ; then
        echo Falta indicar qué es lo que quieres iniciar
        echo
        ayuda
      else
        case $2 in
          "dc1") export INDICE_REPLICACION_DATACENTER=0;
                 ;;

          "todo") export INDICE_REPLICACION_DATACENTER=2; ;;
          *) ayuda; ;;
        esac

        for var in ${2:+"$@"}
        do
          case $var in
            "db2") export DB2="db2"; ;;
            "elastic") export ELASTIC="elasticsearch"; ;;
            "kibana") export KIBANA="kibana"; ;;
            "oracle") export ORACLE="oracle"; ;;
            "mysql") export MYSQL="mysql"; ;;
            *) if [ $var != "iniciar" ] && [ $var != "dc1" ] && [ $var != "todo" ] ; then
                 echo No puedo iniciar $var;
                 ayuda;
               fi
               ;;
          esac
        done

      fi

    # Exportamos otras variables de entorno calculadas en base al valor guardado en
    # el archivo de configuración
    export ZOOKEEPER_ELECTION_PORT_1=$((ZOOKEEPER_INTERNAL_PORT_1 + 1000))
    export ZOOKEEPER_INTERNAL_PORT_2=$((ZOOKEEPER_INTERNAL_PORT_1 + 10000))
    export ZOOKEEPER_INTERNAL_PORT_3=$((ZOOKEEPER_INTERNAL_PORT_2 + 10000))
    export ZOOKEEPER_ELECTION_PORT_2=$((ZOOKEEPER_ELECTION_PORT_1 + 10000))
    export ZOOKEEPER_ELECTION_PORT_3=$((ZOOKEEPER_ELECTION_PORT_2 + 10000))
    export REST_BINDING_PORT_1=$((REST_BINDING_PORT))
    export REST_BINDING_PORT_2=$((REST_BINDING_PORT_1 + 1))
    export REST_BINDING_PORT_3=$((REST_BINDING_PORT_2 + 1))

    export REGISTRY_BINDING_PORT_1=$((REGISTRY_BINDING_PORT))
    export REGISTRY_BINDING_PORT_2=$((REGISTRY_BINDING_PORT_1 + 1))
    export REGISTRY_BINDING_PORT_3=$((REGISTRY_BINDING_PORT_2 + 1))
    export CONNECT_BINDING_PORT_1=$((CONNECT_BINDING_PORT))
    export CONNECT_BINDING_PORT_2=$((CONNECT_BINDING_PORT_1 + 1))
    export CONNECT_BINDING_PORT_3=$((CONNECT_BINDING_PORT_2 + 1))

    verificarparametros

    iniciarcontenedores

}

pararEntornos () {

      if [ -z $2 ] ; then
        echo Falta indicar qué es lo que quieres parar
        echo
        ayuda
      else
        case $2 in
          "todo") echo "Parando el laboratorio ..."
                  for i in `docker ps | awk '{print $1}' | grep -v CONTAINER`; do docker stop $i; done;
                 exit 0;
                 ;;
          "dc2") echo "Parando el rac secundario (dc2) ..."
                 for i in `docker ps | grep dc2 | awk '{print $1}' | grep -v CONTAINER`; do docker stop $i; done;
                 exit 0;
                 ;;
          "bd") echo "Parando los contenedores de persistencia (db2, elastic, mysql, etc ..."
                for i in `docker ps | grep db2 | awk '{print $1}' | grep -v CONTAINER`; do docker stop $i; done;
                for i in `docker ps | grep sql | awk '{print $1}' | grep -v CONTAINER`; do docker stop $i; done;
                for i in `docker ps | grep elastic | awk '{print $1}' | grep -v CONTAINER`; do docker stop $i; done;
                for i in `docker ps | grep kibana | awk '{print $1}' | grep -v CONTAINER`; do docker stop $i; done;
                for i in `docker ps | grep sql | awk '{print $1}' | grep -v CONTAINER`; do docker stop $i; done;
                 exit 0;
                 ;;
          *) ayuda; ;;
        esac
      fi

      pararcontenedores


}

main () {
    cd "${0%/*}"

    clear

    if [ -z $1 ]; then
      ayuda
    fi

    # Leemos el archivo de configuración para exportar las variables de entorno
    export CONFIG=./config/LABORATORIO.conf
    while read LINE
    do
        var1=$(echo $LINE | awk '{print $1}')
        var2=$(echo $LINE | awk '{print $2}')

        if [ $var1 != "#" ] && [ $var1 != "" ] ; then
            export $var1=$var2
        fi
    done < $CONFIG

    case $1 in
        "iniciar") iniciarEntornos "$@";
               ;;
        "parar") pararEntornos "$@";
               ;;
        "borrar") borrarcontenedores "$@";
               ;;
        "verificar") estadocontenedores "$@";
               ;;
        *) ayuda; ;;
    esac

}

main "$@"
