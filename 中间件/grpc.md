# grpc

属于rpc的开源框架，常见的rpc框架

dubbo

spring cloud nacos

-------

**基本特征**

基于protobuf实现序列化/反序列化

基于https传输

跨语言支持

-------

## 1. protobuf

字面意思是协议的缓冲区，即首先把要传输的数据做编码，之后等待使用协议传输。

跨平台、语言无关、可扩展的序列化结构数据的方法，可用于网络数据交换及存储。相对于xml、json，其序列化之后数据量更小，序列化反序列化速度更快。

## 2. http2

是在http1.x上的封装，基于byte[]的方式传输

## 3. grpc

相对于传统的http调用，grpc实现了tcp的长连接复用，提升了传输效率。