## Mongo Setup in Kubernetes

### Setp #1 Install Mongo Database using Statefullset

#### - Generate a key

```openssl rand -base64 741 > internal-auth-mongodb-keyfile```

#### - Create k8s secrets

```kubectl create secret generic shared-bootstrap-data --from-file=internal-auth-mongodb-keyfile```

#### - Deploy in kubernetes

```kubectl create -f mongo-arbiter-rs-svc-all-in-one.yaml```

### Setp #2 Login Mongo 1st POD (mongod-0)

```kubectl exec -it mongod-0 bash```
then run ```mongo```

#### - Now create the Replica Set

```
rs.initiate({_id: "MainRepSet", version: 1, members: [
       { _id: 0, host : "mongod-0.mongodb-service.kubernetes-dashboard.svc.cluster.local:27017" },
       { _id: 1, host : "mongod-1.mongodb-service.kubernetes-dashboard.svc.cluster.local:27017" },
       { _id: 2, host : "mongod-arbiter-0.mongodb-service.kubernetes-dashboard.svc.cluster.local:27017" }
 ]});
```

#### - Check the Replica Set status

```rs.status();```

#### - Create a user “main_admin” for the “admin” database.

```
db.getSiblingDB("admin").createUser({
    user : "main_admin",
    pwd  : "abc123",
    roles: [ { role: "root", db: "admin" } ]
    });
```

#### - Disconnect current session and reconnect to the MongoDB with user & pass.

```
db.getSiblingDB('admin').auth("main_admin", "abc123");
use test;
db.testcoll.insert({a:1});
db.testcoll.insert({b:2});
db.testcoll.find();
db.restaurants.insert({'name': 'Pizzeria Sammy'});
db.restaurants.find();
show collections;
show dbs;
db;
db.isMaster();
```

### Setp #3 Login Mongo 2nd POD (mongod-1)

Exit out of the shell and exit out of the first container (“mongod-0”). 
Then using the following commands, connect to the second container (“mongod-1”), 
run the Mongo Shell again and see if the data we’d entered via the first replica, is visible to the second replica:

```kubectl exec -it mongod-1 bash```

then run ```mongo```

#### - Reconnect to the MongoDB with user & pass & check data availability.

```
db.getSiblingDB('admin').auth("main_admin", "abc123");
use test;
db.setSlaveOk();
db.testcoll.find();
db.restaurants.find();
show collections;
show dbs;
db;
```

### Setp #4 MongoDB backup & restore


#### - Install Mongo backup & restore tools

```
cat <<EOF > /etc/yum.repos.d/mongodb.repo
[MongoDB]
name=MongoDB Repository
baseurl=http://repo.mongodb.org/yum/redhat/7/mongodb-org/4.2/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-4.2.asc
EOF

yum install mongodb-org-tools -y

or

yum install mongodb-org -y

cp /usr/bin/mongodump /usr/local/bin/
cp /usr/bin/mongorestore /usr/local/bin/
```

#### - MongoDB  backup 

```
DEST=/root/db_backups/mongo-`date +%d%m%y"-"%H%M%S`
mkdir -p $DEST
mongodump -h 10.128.0.33:32017 -u main_admin -p abc123 -o $DEST
```

#### - MongoDB restore

```mongorestore -h 10.128.0.33:32017 -u main_admin -p abc123 --dir=$DEST```
