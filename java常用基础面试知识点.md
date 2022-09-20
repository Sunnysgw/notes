## **java常用基础面试知识点**

1、java中==和equals和hashCode的区别 

- ==是字面意义上的比较，对象之间比较对象地址

- equals和hashCode是更接近理解的比较方式，即比较两个对象的内容，一般流程如下，首先比较hashCode，如果不一致，即不一样，如一致，再调用equals

2、int、char、long各占多少字节数 

| 类型    | 长度 |
| ------- | ---- |
| byte    | 8    |
| char    | 32   |
| short   | 16   |
| int     | 32   |
| long    | 64   |
| boolean | 8    |
| float   | 32   |
| double  | 64   |

3、int与integer的区别 

- int是基本数据类型，地址直接指向数据本身，integer包装数据类型，地址指向数据在内存中的位置

- 默认值 int-0 integer-null

- integer是有缓存的，127以内的integer指向同一个地址（强制new除外）

4、谈谈对java多态的理解 

> 多态是指同一种类型的对象对同一个方法有不同的实现方式

- 继承
- 重写
- 父类的引用指向子类对象

5、String、StringBuffer、StringBuilder区别 

- 共同点
  - 都实现了CharSequence接口

- 不同点

  使用场景不同，String是不可变类，即初始化一个对象之后，就不能再改变对象的属性

  而StringBuilder和StringBuffer是可变类，即内容是可变化的

  其中StringBuffer是线程安全的，StringBuilder不是线程安全的，因为前者的方法都是synchronized修饰的，属于同步容器，所以如果不存在多线程的场景，使用StringBuilder，性能更好

6、什么是内部类？内部类的作用 

> 内部类是相对于正常声明的类而言的

内部类分以下几种类型



7、抽象类和接口区别 

8、抽象类与接口的应用场景 

9、抽象类是否可以没有方法和属性？ 

10、泛型中extends和super的区别 

11、父类的静态方法能否被子类重写 

12、final，finally，finalize的区别 

13、序列化的方式 

14、Serializable 和Parcelable 的区别 

15、静态属性和静态方法是否可以被继承？是否可以被重写？以及原因？ 

16、静态内部类的设计意图 

17、成员内部类、静态内部类、局部内部类和匿名内部类的理解，以及项目中的应用 

18、谈谈对kotlin的理解 

19、string 转换成 integer的方式及原理 

20、说说你对Java反射的理解 

21、说说你对Java注解的理解 

22、说说你对依赖注入的理解 

## **二.HashMap相关**

1、HashMap的实现原理 

2、HashMap数据结构？ 

3、HashMap源码理解 

4、HashMap如何put数据（从HashMap源码角度讲解）？ 

5、HashMap怎么手写实现？ 

6、ConcurrentHashMap的实现原理 

7、ArrayMap和HashMap的对比 

8、HashTable实现原理 

9、TreeMap具体实现 

10、HashMap和HashTable的区别 

11、HashMap与HashSet的区别 

12、HashSet与HashMap怎么判断集合元素重复？ 

13、[二叉树]()的深度优先遍历和广度优先遍历的具体实现 

14、堆和栈在内存中的区别是什么(解答提示：可以从数据结构方面以及实际实现方面两个方面去回答)？ 

15、讲一下对树，B+树的理解 

16、讲一下对图的理解 

17、判断单[链表]()成环与否？ 

18、[链表]()翻转（即：翻转一个单项[链表]()） 

19、合并多个单有序[链表]()（假设都是递增的） 

## **三.锁与多线程相关**

1、synchronize的原理 

2、谈谈对Synchronized关键字，类锁，方法锁，重入锁的理解 

3、static synchronized 方法的多线程访问和作用 

4、同一个类里面两个synchronized方法，两个线程同时访问的问题 

5、lock原理 

6、死锁的四个必要条件？ 

7、怎么避免死锁？ 

8、对象锁和类锁是否会互相影响？ 

9、开启线程的三种方式？ 

10、如何控制某个方法允许并发访问线程的个数？ 

11、什么导致线程阻塞？ 

12、如何保证线程安全？ 

13、如何实现线程同步？ 

14、两个进程同时要求写或者读，能不能实现？如何防止进程的同步？ 

15、谈谈对多线程的理解 

16、多线程有什么要注意的问题？ 

17、谈谈你对并发编程的理解并举例说明 

18、谈谈你对多线程同步机制的理解？ 

19、如何保证多线程读写文件的安全？ 

20、Java的并发、多线程、线程模型 

## **四.MySQL相关**

1、MySQL InnoDB、Mysaim的特点？ 

2、MySQL主备同步的基本原理。 

3、select * from table t where size > 10 group by size order by size的sql语句执行顺序？ 

4、如何优化数据库性能（索引、分库分表、批量操作、分页[算法]()、升级硬盘SSD、业务优化、主从部署） 

5、SQL什么情况下不会使用索引（不包含，不等于，函数） 

6、一般在什么字段上建索引（过滤数据最多的字段） 

7、如何从一张表中查出name字段不包含“XYZ”的所有行？ 

8、MySQL，B+索引实现，行锁实现，SQL优化 

9、Redis，RDB和AOF，如何做高可用、集群 

10、如何解决高并发减库存问题 

11、mysql存储引擎中索引的实现机制； 

12、数据库事务的几种粒度； 

## **五.Spring相关**

1、SpringBoot 如何固定版本 

2、SpringBoot 自动配置原理 

3、SpringBoot 配置文件注入 

4、[@Value]() 和 @ConfigurationProperties 比较 

5、@PropertySource 

6、@ImportResource 

7、springboot 的 profile 加载 

8、SpringBoot **指定 profile 的几种方式 

9、SpringBoot 项目内部配置文件加载顺序 

19、 SpringBoot 外部配置文件加载顺序 

11、 Springboot 日志关系 

12、SpringBoot 如何扩展 SpringMVC 的配置 

13、SpringBoot 如何注册 filter ， servlet ， listener 

14、SpringBoot 切换成 undertow 

15、SpringBoot 的任务 

16、SpringBoot 热部署 

17、SpringBoot 的监控 

18、 SpringBoot 整合 [redis]()

SpringBoot 是简化 Spring 应用开发的一个框架。他整合了 Spring的技术栈，提供各种标准化的默认配置。使得我们可以快速开发 Spring 项目，免掉 xml 配置的麻烦。降低 Spring 项目的成本。 

## **六.Redis等缓存系统中间件相关**

1、列举一个常用的Redis客户端的并发模型。 

2、HBase如何实现模糊查询？ 

3、列举一个常用的消息中间件，如果消息要保序如何实现？ 

4、如何实现一个Hashtable？你的设计如何考虑Hash冲突？如何优化？ 

5、分布式缓存，一致性hash 

6、LRU[算法]()，slab分配，如何减少内存碎片 

7、如何解决缓存单机热点问题 

8、什么是布隆过滤器，其实现原理是？ False positive指的是？ 

9、memcache与[redis]()的区别 

10、zoo[keep]()er有什么功能，选举[算法]()如何进行 

11、map/reduce过程，如何用map/reduce实现两个数据源的联合统计 

## **七.[算法]()相关**

1、[排序]()[算法]()有哪些？ 

2、最快的[排序]()[算法]()是哪个？ 

3、手写一个冒泡[排序]()

4、手写快速[排序]()代码 

5、快速[排序]()的过程、时间复杂度、空间复杂度 

6、手写堆[排序]()

7、堆[排序]()过程、时间复杂度及空间复杂度 

8、写出你所知道的[排序]()[算法]()及时空复杂度，稳定性 

9、[二叉树]()给出根节点和目标节点，找出从根节点到目标节点的路径 

10、给2万多名员工按年龄[排序]()应该选择哪个[算法]()？ 

11、GC[算法]()(各种[算法]()的优缺点以及应用场景) 

12、蚁群[算法]()与蒙特卡洛[算法]()

13、子串包含问题(KMP [算法]())写代码实现 

14、一个无序，不重复数组，输出N个元素，使得N个元素的和相加为M，给出时间复杂度、空间复杂度。手写[算法]()

15、万亿级别的两个URL文件A和B，如何求出A和B的差集C(提示：Bit映射->hash分组->多文件读写效率->磁盘寻址以及应用层面对寻址的优化