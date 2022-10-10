kafka-topics.sh --create --bootstrap-server 172.16.237.91:9092,172.16.237.92:9092,172.16.237.93:9092 --replication-factor 3 --partitions 3 --topic event

kafka-topics.sh --list --bootstrap-server 172.16.237.91:9092,172.16.237.92:9092,172.16.237.93:9092

kafka-topics.sh --describe --bootstrap-server 172.16.237.91:9092,172.16.237.92:9092,172.16.237.93:9092 --topic event

kafka-topics.sh --delete --topic event --bootstrap-server 172.16.237.91:9092,172.16.237.92:9092,172.16.237.93:9092

kafka-console-producer.sh --broker-list 172.16.237.91:9092,172.16.237.92:9092,172.16.237.93:9092 --topic event

kafka-console-consumer.sh --bootstrap-server 172.16.237.91:9092,172.16.237.92:9092,172.16.237.93:9092 --from-beginning --topic event

kafka-consumer-groups.sh --bootstrap-server 172.16.237.91:9092,172.16.237.92:9092,172.16.237.93:9092 --list

kafka-consumer-groups.sh --bootstrap-server 172.16.237.91:9092,172.16.237.92:9092,172.16.237.93:9092 --describe --group sgw

kafka-console-producer.sh --broker-list 127.0.0.1:9192,127.0.0.1:9193,127.0.0.1:9194 --topic event