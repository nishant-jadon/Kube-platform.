## Mongo Setup in Kubernetes
MongoDB uses multiple PODs. One POD in the cluster is designated as the primary node and receives all write operations, while other PODs are designated as secondary nodes and asynchronously replicate the operations performed by the primary node on their own copies of the data set. Binary logging is enabled by default.

If a primary node fails, an election takes place and the first secondary node receiving a majority of votes becomes the new primary node. This configuration provides a horizontally scalable and fault-tolerant deployment.

If you select an even number of nodes, it’s a good idea to add an arbiter POD. Arbiter POD do not store any data; their function is to provide an additional vote in replica set elections.

The minimum requirement for a MongoDB cluster is to have at least two PODs: one primary and one secondary. A replica set can have up to 50 nodes, but only 7 can be voting members.

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
       { _id: 0, host : "mongod-0.mongodb-service.<namespace>.svc.cluster.local:27017" },
       { _id: 1, host : "mongod-1.mongodb-service.<namespace>.svc.cluster.local:27017" },
       { _id: 2, host : "mongod-arbiter-0.mongodb-service.<namespace>.svc.cluster.local:27017" }
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
mongodump -h <hostname>:<nodeport> -u main_admin -p abc123 -o $DEST
```

#### - MongoDB restore

```mongorestore -h <hostname>:<nodeport> -u main_admin -p abc123 --dir=$DEST```

### Miscellaneous 


