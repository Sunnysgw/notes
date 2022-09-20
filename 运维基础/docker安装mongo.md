# docker安装mongo

## 分别使用docker安装

### 拉取mongo镜像

  ```shell
  docker pull mongo
  ```

### 本地创建mongo config-server配置文件----后面补上

  ```shell
  cd /Users/sunny/Documents/mongo-cluster
  #创建config-server
  mkdir -p configsvr/{data,conf}
  #编辑配置文件
  echo "storage:
    dbPath: /data/db
    journal:
      enabled: true
  systemLog:
    destination: file
    logAppend: true
    path: /var/log/mongodb/mongod.log
  net:
    bindIp: 0.0.0.0
  processManagement:
    timeZoneInfo: /usr/share/zoneinfo
  replication:
    replSetName: cfg
  sharding:
    clusterRole: configsvr" >> configsvr/conf/mongod.conf
  
  ```

  

### 创建配置服务器

  ```shell
  docker run 
  -d 
  --name mongo-config 
  -p 27019:27019 
  --network mongo-test 
  -v 
  mongo 
  mongod --configsvr --replSet config
  ```

### 进入配置服务器，初始化replica set

  类似于告诉mongo，你是一个配置服务器

  ```shell
  docker exec -it mongo-config bash
  mongo --host mongo-config --port 27019
  rs.initiate(
    {
      _id: "config",
      configsvr: true,
      members: [
        { _id : 0, host : "mongo-config:27019" }
    	]
    }
  )
  ```

### 创建mongodb shard

  ```shell
  docker run -d --name mongo-shard -p 27018:27018 --network mongo-test mongo mongod --shardsvr --replSet shard
  ```

- 进入分片服务器，初始化replica set

  ```shell
  docker exec -it mongo-shard bash
  mongo --host mongo-shard --port 27019
  rs.initiate(
    {
      _id: "shard",
      members: [
        { _id : 0, host : "mongo-shard:27018" }
    	]
    }
  )
  ```

### 创建mongos

  ```shell
  docker run -d --name mongo-router -p 27017:27017 --network mongo-test mongo mongos --configdb config/mongo-config:27019 --bind_ip_all
  ```

- 进入mongos，初始化replica set

  ```shell
  docker exec --it mongo-router bash
  mongo --host mongo-router --port 27017
  # 添加shard
  sh.addShard("shard/mongo-shard:27018")
  ```

------

## 使用mongo compose批量创建

> 上面是基于docker run 来做的，下面使用docker compose 将它们串起来

### 编辑mongo compose 文件

- docker-compose.yml

  ```shell
  version: "3"
  
  services:
    # router
    mongos:
      image: mongo:latest
      volumes:
        - ./script:/script
      ports:
        - "27017:27017"
      # configdb 表示配置服务器的地址 
      command: mongos --configdb config/mongo-config-1:27019,mongo-config-2:27019,mongo-config-3:27019 --bind_ip_all
    # mongo-config 
    mongo-config-1:
      image: mongo:latest
      volumes:
        - ./script:/script
      # ports:
      #   - "27019:27019"
      # --configsvr 表示启动的是配置服务 --replSet 配置服务的名称
      command: mongod --configsvr --replSet config
    mongo-config-2:
      image: mongo:latest
      volumes:
        - ./script:/script
      # ports:
      #   - "27019:27020"
      # --configsvr 表示启动的是配置服务 --replSet 配置服务的名称
      command: mongod --configsvr --replSet config
    mongo-config-3:
      image: mongo:latest
      volumes:
        - ./script:/script
      # ports:
      #   - "27019:27021"
      # --configsvr 表示启动的是配置服务 --replSet 配置服务的名称
      command: mongod --configsvr --replSet config
    # mongo-shard
    mongo-shard-1-a:
      image: mongo:latest
      volumes:
        - ./script:/script
      # ports:
      #   - "28018:27118"
      # --shardsvr 表示启动的是shard服务器
      command: mongod --shardsvr --replSet shard-1
    mongo-shard-1-b:
      image: mongo:latest
      volumes:
        - ./script:/script
      # ports:
      #   - "28018:27118"
      # --shardsvr 表示启动的是shard服务器
      command: mongod --shardsvr --replSet shard-1
    mongo-shard-1-c:
      image: mongo:latest
      volumes:
        - ./script:/script
      # ports:
      #   - "28018:27118"
      # --shardsvr 表示启动的是shard服务器
      command: mongod --shardsvr --replSet shard-1
    mongo-shard-2-a:
      image: mongo:latest
      volumes:
        - ./script:/script
      # ports:
      #   - "28018:27119"
      # --shardsvr 表示启动的是shard服务器
      command: mongod --shardsvr --replSet shard-2
    mongo-shard-2-b:
      image: mongo:latest
      volumes:
        - ./script:/script
      # ports:
      #   - "28018:27119"
      # --shardsvr 表示启动的是shard服务器
      command: mongod --shardsvr --replSet shard-2
    mongo-shard-2-c:
      image: mongo:latest
      volumes:
        - ./script:/script
      # ports:
      #   - "28018:27119"
      # --shardsvr 表示启动的是shard服务器
      command: mongod --shardsvr --replSet shard-2
    mongo-shard-3-a:
      image: mongo:latest
      volumes:
        - ./script:/script
      # ports:
      #   - "28018:27120"
      # --shardsvr 表示启动的是shard服务器
      command: mongod --shardsvr --replSet shard-3
    mongo-shard-3-b:
      image: mongo:latest
      volumes:
        - ./script:/script
      # ports:
      #   - "28018:27120"
      # --shardsvr 表示启动的是shard服务器
      command: mongod --shardsvr --replSet shard-3
    mongo-shard-3-c:
      image: mongo:latest
      volumes:
        - ./script:/script
      # ports:
      #   - "28018:27120"
      # --shardsvr 表示启动的是shard服务器
      command: mongod --shardsvr --replSet shard-3
  
  
  ```

  

- Init_config.js

  > 这里的rs指的是副本集

  ```shell
  rs.initiate(
      {
        _id: "config",
        configsvr: true,
        members: [
              { _id : 1, host : "mongo-config-1:27019" },
              { _id : 2, host : "mongo-config-2:27019" },
              { _id : 3, host : "mongo-config-3:27019" }
          ]
      }
    )
  ```

  

- Init_mongo.js

  > 这里的sh指的是shard，分片集

  ```shell
  sh.addShard("shard-1/mongo-shard-1-a:27018,mongo-shard-1-b:27018,mongo-shard-1-c:27018");
  sh.addShard("shard-2/mongo-shard-2-a:27018,mongo-shard-2-b:27018,mongo-shard-2-c:27018");
  sh.addShard("shard-3/mongo-shard-3-a:27018,mongo-shard-3-b:27018,mongo-shard-3-c:27018");
  
  ```

  

- Init_sharded.js

  ```shell
  rs.initiate(
      {
        _id: "shard-1",
        members: [
              { _id : 1, host : "mongo-shard-1-a:27018" },
              { _id : 2, host : "mongo-shard-1-b:27018" },
              { _id : 3, host : "mongo-shard-1-c:27018" }
          ]
      }
    )
  ```
  
  

### 启动mongo

  ```shell
  docker-compose up -d --remove-orphans
  ```

### docker初始化

  ```shell
  # mongos
  docker exec mongo-docker_mongos_1 mongo --port 27017 /script/init_mongos.js
  # config
  docker exec mongo-docker_mongo-config-1_1 mongo --port 27019 /script/init_config.js
  # sharded
  docker exec mongo-docker_mongo-shard-1-a_1 mongo --port 27018 /script/init_sharded_1.js
  docker exec mongo-docker_mongo-shard-2-a_1 mongo --port 27018 /script/init_sharded_2.js
  docker exec mongo-docker_mongo-shard-3-a_1 mongo --port 27018 /script/init_sharded_3.js
  ```

-----

## 之后的一些实践

> 下面使用搭建好的mongo集群做一些有意思的东西

### 验证集群搭建状态

分别登录进去mongos和config、shard集群，执行如下命令，查看分片和副本集情况

- mongos

  ```shell
  sh.status()
  ```

- config shard

  ```shell
  rs.status()
  ```

### 分片集合实践

之后创建分片集合，并向其中插入数据，查看分片情况

# mongo的基础知识

