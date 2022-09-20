## 启动过程

1. 加载spring.factory中的监听器、初始化工具类
2. 准备环境
3. 创建applicationcontext
4. 初始化applicationcontext
5. 刷新上下文
6. 全部准备完毕，调用runner





环境属性

配置文件默认读取路径：

```java
locations.add(ConfigDataLocation.of("optional:file:./;optional:file:./config/;optional:file:./config/*/"));
locations.add(ConfigDataLocation.of("optional:classpath:/;optional:classpath:/config/"));
```

有一个先后顺序，是按照上面的顺序来的，其中的file是指jar包部署的路径，这里是指默认的顺序，如果	