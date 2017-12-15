#!/bin/bash

docker-compose -f ./docker-hdp/examples/compose/accumulo-single-container.yml up -d

counter=0
until $(curl --output /dev/null --silent --head --fail -u admin:admin http://localhost:8080/api/v1/clusters); do
	echo -ne "\\rWaiting for Ambari to start...$counter seconds elapsed"
        ((counter=counter+5))
	sleep 5
done
echo ""

echo Submitting blueprint
./docker-hdp/submit-blueprint.sh single-container ./docker-hdp/examples/blueprints/single-container-accumulo.json

echo Adding users...
echo "Staring LDAP"

docker exec -i --privileged compose_dn0.dev_1 bash /root/addLdapUsers.sh

STATUS=""
counter=0
while [ "${STATUS}" != "STARTED" ];do 
	echo -ne "\\rWaiting to add policies...$counter seconds elapsed"
        ((counter=counter+5))
	sleep 5
	STATUS=`curl -k -u admin:admin -H "X-Requested-By:ambari" -s -X GET "http://localhost:8080/api/v1/clusters/dev/hosts/dn0.dev/host_components/RANGER_ADMIN" | grep "\"state\"" | cut -d'"' -f4`
done

cd docker-hdp/containers/node/scripts

echo Init ranger accumulo policies...
./addServiceType.sh
./addService.sh
./cleanPolicies.sh
./addPolicies.sh

cd -


STATUS=""
counter=0
while [ "${STATUS}" != "STARTED" ];do
        echo -ne "\\rWaiting to insert test table... $counter seconds elapsed"
        ((counter=counter+5))
        sleep 5
        STATUS=`curl -k -u admin:admin -H "X-Requested-By:ambari" -s -X GET "http://localhost:8080/api/v1/clusters/dev/hosts/dn0.dev/host_components/ACCUMULO_TRACER" | grep "\"state\"" | cut -d'"' -f4`
done

sleep 5

echo Creating sample table...
docker cp statements compose_dn0.dev_1:/root/
docker cp insert.sh compose_dn0.dev_1:/root/
docker exec -u root -it compose_dn0.dev_1 sh -c '/root/insert.sh'

