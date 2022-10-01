# mysql 优化

## 1. 索引数据结构

> 索引是帮助MySQL高效获取数据的一种<排好序>的数据结构。`

如果不加索引，查询数据的过程需要逐行扫描，如果表中数据较多，就需要大量的磁盘io操作，而io操作是比较耗费性能的。索引的使命就是要通过预先存储一些地址信息，减少查询次数。

索引的几种候选的数据结构

- 二叉搜索树

  保证对于任意节点，左节点小于等于节点，右节点大于等于节点，可以用来存储mysql的索引，但是可能会退化成链表，不能保证查询效率

- 红黑树

  可以有效控制二叉搜索树的高度平衡，防止二叉树退化。但是，这样一层存储的内容还是有点少，表的容量上来了，树的高度也上来了，不太巧的话，查找过程中需要每层都走一遍，io还是高了

- b树

  针对红黑树每个节点容量比较小的问题，有了b树，如下

  ![image-20220928090224608](/Users/sunny/Documents/notes/image-20220928090224608.png)

- b+树

  针对b树做了一些优化

  ![image-20220928090303172](/Users/sunny/Documents/notes/image-20220928090303172.png)

  非叶子节点不存数据，叶子节点包含了所有的索引元素，**叶子节点使用指针连接，提高了区间访问的性能**。同时因为非叶子节点不存数据，所以可以存更多的地址，树的高度也就越小。

  一个非叶子节点大小为16kb，是磁盘一个卷的大小，读取一个节点需要一次io。

  
  
  一次查询过程？增加索引的过程？

- hash索引

  使用类似hash的方式存放每一行数据，使用方式类似于hashmap，单个查询效率更高，但是范围查询效率不会很高。

目前大多数用innodb引擎，引擎是在表级别生效的。存储引擎

- myisam引擎

  索引和数据是分离的？索引使用b+树的结构，属于**非聚集索引**

  查询的时候，即从根节点开始找，之后逐层向下，直到叶子结点，找到叶子结点中记录的对应行的地址，之后从数据文件中取对应数据。

- innodb引擎

  索引和数据是放一起的，即叶子节点存放的是其他列的数据，属于**聚集索引**
  
  不同于myisam引擎，innodb叶子结点存放的是索引所在行的其他列的数据。
  
  只有一个**聚集索引**，即使用**主键构建的索引**，对于其他的索引，同样用之来构建b+树，但是叶子结点不会存其他列的数据，存对应行的**主键**，后面查询的时候基于给的主键去查询数据，这个过程是**回表**。

**聚集和非聚集这两种索引的优劣？**

聚集索引查询效率要高一些，因为不涉及二次查找。

**为什么建议innodb表建主键，并推荐使用整型的自增主键？**

innodb引擎的表中，默认基于b+树的结构存储，如果没有主键，则去找一个具有唯一性的列作为键构建b+树。

b+树的查找过程，涉及逐层比较大小的过程，整型比较大小效率更高。同时整型占用空间较小，这样b+树每个节点就可以存放更多元素。

自增主键？逐步递增的索引对构建存储数据的b+树更友好。

-------

以下讲的步骤基本基于innodb来做的

**联合索引**

基于索引中的所有字段排序，按照声明索引的字典序列排序，解决了这个问题，那么聚合索引就跟单一的索引插入方式一致了。

联合索引查询过程按照**最左前缀**来的。具体来的话，就是联合索引给索引排序是按照字典序来的，也就保证只有从联合索引最前面的列开始，才能保证一定顺序。更具体来说，比如构建了a b c这三个列的的索引，只能保证a、a b、a b c才是能排序的，否则b+树这种结构就不能用了。

## 2. 索引优化

> mysql join表格，有：
>
> join 语义即遍历左侧表，执行条件语句，如右侧表中有满足条件的数据，即拼接成新的行，查出来几行就拼几行
>
> left join 基本同join，如果右侧表中没有满足条件的数据，也会拼接生成新的行，不过右侧数据部分是空
>
> right join 和leftjoin相反，以右侧表为主

### 2.1 explain工具

用于分析其后的sql执行情况

- id

  查询的id，值越大，执行越靠前

- select type

  查询的类型

  - 对于没有嵌套查询的sql，直接是simple
  - 对于有嵌套关系的查询，最外面的类型是primary，是最后执行的查询
  - from前的子查询是subquery
  - from后的子查询是drived，可以理解成是由查询语句生成的临时表，需要转存一下，供之后从中取结果，primary查询依赖其查询的结果

- table

  查询的表

- type

  - null

    sql解析的时候直接就优化了，已经得到了结果

  - system

    查询表中只有一条记录

  - const

    基于primary key或者unique key全部列通常数比较，只要在b+数中查询一次，之后只要查询结果。

  - eq_ref

    primary key或者unique key索引的所有列被链接使用，即使用多个唯一索引依次查询

  - ref

    使用了不唯一的索引或者唯一索引的部分前缀做了查询，这样一次可以查出来多个

  - range

    使用索引做范围查询，包含in between，> < >=等操作

  - index

    扫描所有索引得到结果，即看查询的字段是否能被某个索引覆盖，优先使用二级索引，因为二级索引不会存所有数据，占用空间会小

  - all

    全表扫描，即扫描聚合索引的所有叶子结点

  index、all这种要做优化的。

- possible_keys

  可能会使用的key

- key

  查询的时候真正使用的索引

- key_len

  用到的索引的字节数，可以用它来确定联合索引用到了哪几位

- ref

  查询的时候，索引要比对的值

- rows

  预估要查询的行数

- extra

  展示额外信息

  - Using index

    查询二级索引的时候，查询的结果集中的列，被索引包含了，不需要再回表了。
  
  - using filesort
  
    将使用外部排序而不是内部排序

### 2.2 索引最佳实践

**最左匹配原则**，对于最左匹配原则，即从索引的最左侧开始，看该列是否在查询条件中存在且条件为=、like 确定的值%，如存在则继续找索引中的下一列，如为>或者<这种范围查询，即停止搜索，索引使用到这一步就结束了。有点意思的是，**在使用like匹配前缀的搜索中，是可以继续处理下一个索引的**，这个东西明明语义上是范围查询，却能被当作定植处理，是真的想不通的，要理解这个，是要明白符合索引树是怎么做搜索的，如果查询的条件完全覆盖了索引列，搜索过程就和单一列的索引树一致，这里涉及<font color='red'>索引下推</font>，同时也是在成本预估的基础上做的选择的。

mysql针对in or这些查询条件，会结合具体情况看是否要走索引，跟数据库情况有关。

最好查询条件能够尽可能多的落在索引上，基于最左匹配原则来判断。



**最佳实践**：

- 不要在索引上做操作，因为索引树上的值并没有做对应操作
- 尽量使用**覆盖索引**，即查询列在索引树中，避免回表操作
- 基于索引树的结构，不等于、不存在这些操作基本用不到索引
- mysql会对范围索引做评估，如果范围索引单次查询耗费过多，可能不会走索引。

我自己的理解，索引本质上就是空间换时间的操作，换的时间是查询时间，对更新时间来讲，索引越多，越复杂，耗费时间会越久，因为可能会涉及同步修改二级索引树，对于innodb中，默认都会有一个primary索引树，是聚合索引，叶子结点放的是其它列的数据，二级索引树的叶子结点放的则是该行对应的primary key值，要得到所有数据还需要再次查询primary 索引树。所以索引并不是越多越好，一般会有一个经验值吧todo。

## 3. 索引执行优化

### 3.1 示例分析

结合上一节的结论具体做实践。

具体执行过程中，是经过优化器的选择的结果，包括使用哪个索引。

```mysql
create table if not exists sgw.employees
(
	id int auto_increment
		primary key,
	name varchar(24) default '' not null comment '姓名',
	age int default 0 not null comment '年龄',
	position varchar(20) default '' not null comment '职位',
	hire_time timestamp default CURRENT_TIMESTAMP not null comment '入职时间'
)
comment '员工记录表' charset=utf8mb3;

create index idx_name_age_position
	on sgw.employees (name, age, position);

```

**例子1**

```mysql
explain select * from employees where name > 'lilei' and age = 22 and position = 'hello';
```

![截屏2022-09-30 11.32.55](/Users/sunny/Documents/notes/explain1.png)

这里是没有走索引的，做的是全表扫描，应该是考虑到这里查询结果没有被二级索引覆盖，查到结果之后还要做回表，所以干脆直接全表了。这里如果查询结果在二级索引中，如下，不需要回表，就会直接用二级索引。或者可以选择强制走索引，使用force index(indexname)。

```mysql
explain select name, age, position from employees where name > 'lilei' and age = 22 and position = 'hello';
```

**例子2**

```mysql
explain select * from employees where name like 'lilei%' and age = 22 and position = 'hello';
```

```mysql
explain select * from employees where name > 'lilei' and age = 22 and position = 'hello';
```

这两个看起来是一致的，但是索引执行情况完全不同，使用了**like 'lilei%'**是会继续走索引的，但是使用**> 'lilei'**这种就不会走索引。

5.6之前，执行like 'lilei%'语句的时候，会首先回表找到所有满足like条件的主键，之后回表，再基于后面的条件查询，只用了一个索引。

### 3.2 mysql优化规则

目前的版本引入了**索引下推**，即依次在二级索引中找到对应的满足条件的值，之后在这个基础上基于索引中的其他条件字段做搜索，找到对应的主键，之后回表，基于主键找到对应的行数据，如果还有其他条件，再做比对。这样就用了所有索引，基于这种解释，mysql中在做索引匹配的时候，遇到like 'lilei%'这种匹配条件，表象看来和=匹配条件一致。

<font color='red'>但是，这里最终的优化效果，应该还是由优化器评估之后决定，并不是所有的like 'xxx%'都能触发索引下推，如果like几乎把表中绝大多数数据都查出来了，之后还要回表，就真不如直接遍历聚合索引来的快一些，实际也是这么表现的。然后还有一点，就是最好查询的列也是在索引范围内的，不需要再做一次回表，这样优化器也会优先选择走索引了。</font>

<font color='red'>打开trace，会看到mysql优化器会对扫描的时候可能遇到的所有情况会有一个评估，大体会算出来一个cost，之后综合所有情况即得到最终选择的索引。所以，对于同一种表结构，表的存储情况不同，具体算出来的cost不一样，实际的索引也可能会不一致</font>

```mysql
# 直接全表扫描，猜测是因为zhuge%几乎匹配了绝大多数行
select * from employees where name like 'zhuge%' and age = 10 and position = 'dev';
# 使用全量索引，索引下推
select * from employees where name like 'zhuge10000%' and age = 10000 and position = 'dev';
# 直接全表扫描
select * from employees where name >= 'zhuge10000' and age = 10000 and position = 'dev';
# 使用了全量索引，因为查询内容在index中，所以就只要扫描一遍二级索引就ok了吧
select name from employees where name >= 'zhuge10000' and age = 10000 and position = 'dev';
# 这里强制使用了索引，这么整确实比全表扫描要快点，但是还是比不上like的速度
select * from employees force index(idx_name_age_position) where name >= 'zhuge10000' and age = 10000 and position = 'dev';

```

**索引下推**的方式可以理解成走多个等于。

> 最后是不是都可以把锅甩到优化器上，就是优化器会对不同情况做一个评估，之后按照评估出来的最优解来走。

### 3.3 常见sql优化

- order by是否使用索引

  结合索引的结构，如索引顺序为 a b c，a给定了，b是按照索引排序的，b给定了，c就是按照索引排序的，如果查询字段中用到了索引，且排序字段的顺序是能够在索引树中根据前面字段确定的。

  还是上面的表结构，例子如下：

  ```mysql
  # 用到了索引排序，name + age 满足最左前缀
  select * from empolyees where name = 'lilei' order by age;
  # 用到了索引排序，name + age + position 满足最左前缀
  select * from empolyees where name = 'lilei' order by age, position;
  # 没有用到索引，name + position + age，不符合索引的顺序
  select * from empolyees where name = 'lilei' order by position, age;
  # 大概率没有用到索引，因为本身 > 'lilei'这个查询大概率会做主键索引的全表扫描，主键索引就不是基于name排序的了，这种可以优化，把select *换成查询符合索引内的列，之后就用到了复合索引，name自然也就是有序的，如下
  select * from empolyees where name > 'lilei' order by name;
  # 用到了覆盖索引，不要回表
  select name, age, position from empolyees where name > 'lilei' order by name;
  ```

  排序涉及两种，一种是基于索引排序，一种是文件排序，后者后浪费额外的时间。

  **文件排序**

  这里是有一个字段大小阈值，为1kb。

  - 单路排序

    要排序的字段不多，直接把所有要排序的数据加载到内存中，之后基于对应列排序

  - 双路排序

    要排序的字段比较多，就只加载要排序的列以及该列的主键，之后做排序，排完序之后，再基于主键把其余的列查回来。

  具体的排序信息在trace中有展示，单路排序的sort_mode为<sort_key, packed_additional_fields>，双路排序的mode为<sort_key, rowid>，mysql中用于排序的内存被称为sort buffer，默认大小为1m，如果buffer中放不下，就会用磁盘排序。

  **总结**

  - order by用来排序的列也要和查询的列满足最左前缀原则

  - 尽量使用**覆盖索引**

- group by是否使用索引

  group by和order by类似，默认情况下是首先基于group by的列排序，之后再做输出，所以是否使用索引列也就明了了。

### 3.4 索引设计原则

索引是为了业务服务的，应该是首先设计表，之后结合具体场景做开发，开发稳定之后，结合所有的查询场景构建索引。

索引要尽量覆盖大部分where order by group by语句，同时，确定要加索引的字段之后，对索引的顺序进行适当调整。

尽量使用复合索引，节省空间，同时覆盖多个场景。

尽量不要在小基数字段上建索引，基数较小，使用二分查找的效率不会太高。

长字符可以考虑使用前缀索引，类似如下：

```mysql
alter table add index(demo(1))
```

where和order by冲突时优先where，首先由快速的where筛选大部分数据，之后再由order by的列做排序。一般是先过滤，后排序。

基于慢sql查询做优化。

**实践**

一般而言，是设计一到两个比较大的复合索引，抗下大部分sql请求，同时针对剩下的场景，可以有两到三个小的索引来cover。

范围索引一般而言建在最后。

如果索引中间有基数比较小的字段，本次查询的时候没有用上，但是对应的索引中就是在这个小字段中断掉了，例如索引是省份+城市+年龄+性别+昵称，一个查询就差了性别，考虑到性别的基数小，只有男、女，那可以加上sex in ('male', 'female')。

如果有两个范围查询的字段，冲突了，而且他们大概率会同时出现，正常使用索引，大概率只能有一个能用到，就可以考虑把其中一个字段的范围查询转化成等值查询。

## 4. mysql执行过程

**大体构成**

- 客户端

  客户端服务端建立连接，会建立一个会话，其中存放登录时用户的权限。

- server

  1. 会有一个缓存的机制，5.7之后默认关了，8.0缓存直接没了，其实，对于类似于配置表这种读多写少的场景还是可以用缓存的机制的。

  2. 分析器，解析mysql语法

     antlr4，idea语法分析插件

     基于分析出来的结果做分库分表，ShardingSphere是apache的一个分库分表中间件，听起来做的就像mongodb的分片策略。

  3. 优化器

     生成执行计划，之后选择索引。

     类似于join是由小表驱动大表的策略。

  4. 执行器

     首先要做权限判断

  **bin-log**

  server端会记录一些操作日志，是bin-log，mysql的主从同步即是通过binlog来做的

  有几种格式：

  - statement

    记录执行的命令，相对于raw不是太安全，具体来说有个例子，可能sql执行的结果不一致

    ```mysql
    select name from table where a = val1 or b = var2 limit 1;
    ```

    这种不一定是基于a还是b做查询，而又limit1，所以结果不一定一致。

    那如果采用statement的方式，主库的执行结果可能跟从库不一致。

  - raw

    记录执行之后的结果，相对于statement来说，存储空间比较大。

  - mixed

    结合statement和raw

    如果结果确定，直接用statemnet，如果结果不确定，就用raw的方式。

  raw格式的binlog如下

  ```shell
  BEGIN
  /*!*/;
  # at 310
  #220930 10:43:00 server id 1  end_log_pos 370 CRC32 0x5e3d6560  Table_map: `sgw`.`role` mapped to number 169
  # at 370
  #220930 10:43:00 server id 1  end_log_pos 431 CRC32 0x6f583c43  Write_rows: table id 169 flags: STMT_END_F
  
  BINLOG '
  tFc2YxMBAAAAPAAAAHIBAAAAAKkAAAAAAAEAA3NndwAEcm9sZQAFAw8DAw8EAAJgABoBAQACAeBg
  ZT1e
  tFc2Yx4BAAAAPQAAAK8BAAAAAKkAAAAAAAEAAgAF/wAOAAAAAwBwZXQHAAAABwAAAAdiaW4gbG9n
  QzxYbw==
  '/*!*/;
  # at 431
  #220930 10:43:00 server id 1  end_log_pos 462 CRC32 0x4c04286e  Xid = 5155
  COMMIT/*!*/;
  ```

  比如这里，会有一个begin、commit记录事务的开启、提交，同时也会记录pos，这些都是数据恢复的重要的点；

  例子：

  1. 首先可以模拟删库跑路

     ```mysql
     truncate database.table;
     ```

  2. 之后确定我们要恢复的日志

     在log_bin_basename这个变量中配置了日志路径，在路径下找到我们要恢复的日志。

  3. 通过mysqlbinlog来恢复指定日志

     ```shell
     # 直接全量恢复binlog中的内容
     mysqlbinlog --no-defaults /path/to/binlog | mysql -u -p database
     # 恢复指定位置
     --start-position="" --stop-position=""
     # 恢复指定时间
     --start-date="" --stop-date=""
     ```

     

- 引擎

  插拔的方式来做的，innodb、myisam等，是针对

