#!/bin/bash

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#
# All settings which should be consistent with hive/Dockerfile, yaml/hive.yaml, and run-hive.sh.
#

#
# Basic settings
# 

REMOTE_BASE_DIR=/opt/mr3-run
REMOTE_WORK_DIR=$REMOTE_BASE_DIR/hive
CONF_DIR_MOUNT_DIR=$REMOTE_BASE_DIR/conf
KEYTAB_MOUNT_DIR=$REMOTE_BASE_DIR/key
WORK_DIR_PERSISTENT_VOLUME_CLAIM=workdir-pvc
WORK_DIR_PERSISTENT_VOLUME_CLAIM_MOUNT_DIR=/opt/mr3-run/work-dir

# JAVA_HOME and PATH are already set inside the container.

# If hive.mr3.compaction.using.mr3 in conf/hive-site.xml is set to true, Metastore need a PersistentVolume.
# See spec.template.spec.containers.volumeMounts/volumes in yaml/metastore.yaml and helm/hive/templates/metastore.yaml.
# metastore.mountLib in helm/hive/values.yaml should be set to true to mount the MySQL connector provided by the user.
METASTORE_USE_PERSISTENT_VOLUME=true
RUN_AWS_EKS=false

#
# Step 1. Building a Docker image
#

DOCKER_HIVE_IMG=${DOCKER_HIVE_IMG:-10.1.91.17:5000/hive3:latest}
DOCKER_HIVE_FILE=${DOCKER_HIVE_FILE:-Dockerfile}

DOCKER_HIVE_WORKER_IMG=${DOCKER_HIVE_WORKER_IMG:-$DOCKER_HIVE_IMG}
DOCKER_HIVE_WORKER_FILE=${DOCKER_HIVE_WORKER_FILE:-Dockerfile-worker}

DOCKER_RANGER_IMG=10.1.91.17:5000/ranger:latest
DOCKER_RANGER_FILE=Dockerfile

DOCKER_ATS_IMG=10.1.91.17:5000/ats-2.7.7:latest
DOCKER_ATS_FILE=Dockerfile

# do not use a composite name like hive@RED, hive/red0@RED (which results in NPE in ContainerWorker)
DOCKER_USER=hive

#
# Step 2. Configuring Pods
#

MR3_NAMESPACE=hivemr3
MR3_SERVICE_ACCOUNT=hive-service-account
CONF_DIR_CONFIGMAP=hivemr3-conf-configmap

CREATE_KEYTAB_SECRET=true   # specifies whether or not to create a Secret from key/*
KEYTAB_SECRET=hivemr3-keytab-secret

CREATE_RANGER_SECRET=true   # specifies whether or not to create a Secret from ranger-key/*
CREATE_ATS_SECRET=true      # specifies whether or not to create a Secret from ats-key/*

#
# Step 3. Update YAML files
#

#
# Step 4. Configuring HiveServer2 - connecting to Metastore
#

# HIVE_DATABASE_HOST = host for Metastore database 
# HIVE_METASTORE_HOST = host for Metastore itself 
# HIVE_METASTORE_PORT = port for Hive Metastore 
# HIVE_DATABASE_NAME = database name in Hive Metastore 
# HIVE_WAREHOUSE_DIR = directory for the Hive warehouse 
HIVE_DATABASE_HOST=indigo0

# if an existing Metastore is used 
# HIVE_METASTORE_HOST=red0
# if a new Metastore Pod is to be created inside K8s
HIVE_METASTORE_HOST=hivemr3-metastore-0.metastore.hivemr3.svc.cluster.local

HIVE_METASTORE_PORT=9850
HIVE_DATABASE_NAME=hive5mr3

# path to the data warehouse, e.g., hdfs://red0:8020/user/hive/warehouse
HIVE_WAREHOUSE_DIR=/opt/mr3-run/work-dir/warehouse/

# Specifies hive.metastore.sasl.enabled 
METASTORE_SECURE_MODE=true

# For security in Metastore 
# Kerberos principal for Metastore; cf. 'hive.metastore.kerberos.principal' in hive-site.xml
HIVE_METASTORE_KERBEROS_PRINCIPAL=hive/red0@RED
# Kerberos keytab for Metastore; cf. 'hive.metastore.kerberos.keytab.file' in hive-site.xml
HIVE_METASTORE_KERBEROS_KEYTAB=$KEYTAB_MOUNT_DIR/hive.service.keytab

#
# Step 5. Configuring HiveServer2 - connecting to HiveServer2
#

# HIVE_SERVER2_PORT = port for HiveServer2 (for both cluster mode and local mode)
#
HIVE_SERVER2_HOST=$HOSTNAME
HIVE_SERVER2_PORT=9852

# Heap size in MB for HiveServer2
# With --local option, mr3.am.resource.memory.mb and mr3.am.local.resourcescheduler.max.memory.mb should be smaller. 
# should not exceed than the resource limit specified in yaml/hive.yaml
HIVE_SERVER2_HEAPSIZE=16384

# For security in HiveServer2 
# Beeline should also provide this Kerberos principal.
# Authentication option: NONE (uses plain SASL), NOSASL, KERBEROS, LDAP, PAM, and CUSTOM; cf. 'hive.server2.authentication' in hive-site.xml 
HIVE_SERVER2_AUTHENTICATION=KERBEROS
# Kerberos principal for HiveServer2; cf. 'hive.server2.authentication.kerberos.principal' in hive-site.xml 
HIVE_SERVER2_KERBEROS_PRINCIPAL=hive/red0@RED
# Kerberos keytab for HiveServer2; cf. 'hive.server2.authentication.kerberos.keytab' in hive-site.xml 
HIVE_SERVER2_KERBEROS_KEYTAB=$KEYTAB_MOUNT_DIR/hive.service.keytab

# Specifies whether Hive token renewal is enabled inside DAGAppMaster and ContainerWorkers 
TOKEN_RENEWAL_HIVE_ENABLED=false

# Truststore for HiveServer2
# For Timeline Server, Ranger, see their configuration files
HIVE_SERVER2_SSL_TRUSTSTORE=$KEYTAB_MOUNT_DIR/hivemr3-ssl-certificate.jks
HIVE_SERVER2_SSL_TRUSTSTORETYPE=jks
HIVE_SERVER2_SSL_TRUSTSTOREPASS=

#
# Step 6. Reading from a secure HDFS
#

# 1) for renewing HDFS/Hive tokens in DAGAppMaster (mr3.keytab in mr3-site.xml)
# 2) for renewing HDFS/Hive tokens in ContainerWorker (mr3.k8s.keytab.mount.file in mr3-site.xml)

# Kerberos principal for renewing HDFS/Hive tokens (Cf. mr3.principal)
USER_PRINCIPAL=hive@RED
# Kerberos keytab (Cf. mr3.keytab)
USER_KEYTAB=$KEYTAB_MOUNT_DIR/hive.service.keytab

# Specifies whether HDFS token renewal is enabled inside DAGAppMaster and ContainerWorkers 
TOKEN_RENEWAL_HDFS_ENABLED=true

#
# Step 7. Additional settings
#

# Logging level 
LOG_LEVEL=INFO

#
# Additional environment variables for HiveServer2 and Metastore
#
# Here the user can define additional environment variables using 'EXPORT', e.g.:
#   export FOO=bar
#

#
# For running Metastore
#

# Heap size in MB for Metastore
# should not exceed the resource limit specified in yaml/metastore.yaml
HIVE_METASTORE_HEAPSIZE=16384

# Type of Metastore database which is used when running 'schematool -initSchema'
HIVE_METASTORE_DB_TYPE=mysql

#
# For running HiveCLI 
#

# Heap size in MB for HiveCLI ('hive' command) 
# With --local option, mr3.am.resource.memory.mb and mr3.am.local.resourcescheduler.max.memory.mb should be smaller. 
HIVE_CLIENT_HEAPSIZE=16384

# Note. Specify the same garbage collector in all of the following:
#   hive.tez.java.opts in hive-site.xml 
#   tez.am.launch.cmd-opts and tez.task.launch.cmd-opts in tez-site.xml 
#   mr3.am.launch.cmd-opts and mr3.container.launch.cmd-opts in mr3-site.xml 

#
# For running Timeline Server 
#

ATS_HEAPSIZE=2048

# unset because 'hive' command reads SPARK_HOME and may accidentally expand the classpath with HiveConf.class from Spark. 
unset SPARK_HOME

