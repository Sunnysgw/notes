# jvm

## 1. 类加载器

> 使用java命令启动一个java程序，会启动一个jvm，即java虚拟机，而java虚拟机中具体执行代码之前就是要加载所需要的类，加载类的工作是由类加载器实现的

### 1.1 加载器层级

jvm启动的时候，首先会由c++程序启动一个引导类加载器，即bootstrap类加载器；

之后由该类加载器加载Launcher类，其中会构建扩展类加载器以及应用类加载器；

构建的类加载器之间是有层级关系的，从逻辑而言从上到下依次是：

- 引导类加载器

  加载jre/lib下面的核心包，如Object String等

- 扩展类加载器

  加载jre/lib/ext下面的扩展包，现在可以理解成插件的形式

- 应用类加载器

  加载java程序启动时候传入的classpath下的包，java中代码中自定义加载器的父加载器就是应用类加载器

### 1.2 类加载过程

#### 1.2.1 双亲委派机制

jvm中默认采用双亲委派机制来加载类，具体过程如下：

1. 首先看当前加载器中是否已经加载了该类，如果有，直接返回

2. 如果没有，则从父加载器中去找

   1. 父加载器中也会采用相同的流程

      扩展类加载器的父加载器属性那里是空，代码中这么定义的，如果父加载器为空，则从引导类加载器中去找

   2. 父加载器中load class的代码忽略了classnotfound的错

3. 父加载器中也没找到，就执行自己定义的具体加载流程，即findclass，这里可以根据自己的需要扩展出对应的加载器，如urlclassloader，或者如果想要从remote加载类，就是根据传进来的名字从远端去读，之后加载。

一个简单的自定义类加载器只需要重写findclass方法，如下：

```java
/**
 * 核心方法，双亲委派机制由自带的loadclass实现，如果父类没有，即调用该方法
 * @param name
 * @return
 * @throws ClassNotFoundException
 */
@Override
protected Class<?> findClass(String name) throws ClassNotFoundException {
    String packagePath = name.replaceAll("\\.", "/");
    try {
        FileInputStream fileInputStream = new FileInputStream(classPath + packagePath + ".class");
        byte[] content = new byte[fileInputStream.available()];
        fileInputStream.read(content);
        return defineClass(name, content, 0, content.length);
    } catch (IOException e) {
        throw new ClassNotFoundException();
    }
}
```

**优点**

这种设计模式肯定是有自己的考虑的：

- 这样提供了一种沙箱的机制，防止核心类库被重新覆盖（从代码看，其他也会有地方去考虑的，比如，默认的classloader的loadfrombyte方法中，就不允许加载java开头包名下的类）

- 提升效率吧

  这样对于同样的包，就不要重复加载了，都在同一个地方去读

**不足**

这种加载模式保证了一个包只会加载一次，因为首先是从父加载器中取的，但是如果说我有几个子加载器，想要在这几个子加载器中分别加载不同版本的一个包，比如不同版本的spring，这种就会有点问题，因为如果委托父加载器去做，那么对于同一个包，只会有一个版本。

一个简单的思路就是重新调整下loadclass，即对于特定的包，由子类加载器负责，这样就能实现多版本包并存，如下：

```java
@Override
protected Class<?> loadClass(String name, boolean resolve) throws ClassNotFoundException {
    synchronized (getClassLoadingLock(name)) {
        // First, check if the class has already been loaded
        Class<?> c = findLoadedClass(name);
        if (c == null) {
            if (name.startsWith("java1")) {
                c = findClass(name);
            } else {
                c = getParent().loadClass(name);
            }
        }
        if (resolve) {
            resolveClass(c);
        }
        return c;
    }
}
```

**具体场景**

一个很实用的场景就是tomcat的加载过程，几个不同的webapplication，它们的spring版本可能不同，那么就需要分别在自己的子加载器中去加载。对于每个应用程序自己依赖的包，即使用自己的类加载器加载，即从自己的路径下去找，如果是公共的包，即交给父类加载器。

#### 1.2.2 具体加载过程

- 加载

  把字节码（class）文件加载到内存

- 验证

  验证字节码文件是否符合java的规范，这里就要看，是否是在自定义加载器中加载了java开头的包这种安全问题

- 准备

  给类的静态变量分配内存，并赋予默认值，对于基本类型，都会有一个默认值，如果是引用类型，赋值为null

- 解析

  符号引用 -> 直接引用

  这里**符号引用**指的是java中的引用，**直接引用**，即真实地址。

  完成**静态链接**的过程，即类加载期间做完上述过程。

  这里主要针对静态的方法，对于非静态的部分，需要**动态链接**，即程序运行期间执行上述过程。

- 初始化

  类的静态变量赋值，同时执行静态代码块

java程序启动的过程是一个懒加载的过程，对于一个类，只有在用它的时候，才会加载。对于程序员而言，加载一个类的具体启动顺序为：

1. 静态变量

2. 静态代码块

3. 常量

4. 构造代码块

5. 构造方法

## 2. jvm内存模型

java语言天然具有跨平台的特性，不同平台的区别体现在不同的jdk版本上，它们能识别同样的class文件，并转化为对应平台的机器码命令。jvm诞生的时候，正处于c/c++盛行的时代，很自然的它就是在c/c++的基础上诞生的，包括java程序启动，一些类加载器，字节码执行引擎，jvm内存模型中的很多部分都是由c/c++做的。

> jvm组成
>
> - 类装载子系统
>
> - 内存模型
>
>   jvm调优主要是针对这里做的
>
> - 字节码执行引擎

下面着重介绍jvm内存模型

### 2.1 jvm内存模型组成

内存模型由jvm栈、程序计数器、本地方法栈、堆、方法区五部分构成，其中前三部分是每个线程独有，即开启一个线程，就会单独分配这三部分空间，后两部分是线程共享的。

- jvm栈

  **线程独有**

  给线程分配的内存空间，用于存放线程内部的局部变量，保证了线程安全

  每个线程的栈是由一个个栈帧构成，每个栈帧对应一个方法，只有最上层的栈帧是激活状态，这里用栈描述了方法的调用关系，这个栈的容量是有限制的，所以不可能无限的调用，每个栈帧包含了如下信息：

  - 局部变量表 

    基本类型的值、指向堆中的地址

  - 操作数栈

    是一块中转存放的内存空间，执行具体操作的值，包括操作类型，操作的值是从局部变量表中取的

  - 动态链接 

    指向运行时常量（方法区）的地址

  - 返回地址

    指向调用该方法的栈帧地址 

- 本地方法区

  **线程独有**

  如果调用本地方法，即C++方法，会放在本地方法区，java最早诞生的时候，这种场景会比较多，原有的c++/c程序要向java过渡，在过渡的中间状态，免不了会有java调用c++/c程序的场景，这里更具体的是调用对应的dll动态链接库，在jdk的代码中还会有很多这种场景。

- 程序计数器

  **线程独有**

  表示当前线程的执行位置，用户线程切换的时候重新进行定位

- 堆

  存放对象的具体内容，其他地方，例如局部变量表、方法区中存放的都是地址，最终指向堆中，因而，堆是jvm内存模型中占用空间最大，且变化较为频繁的区域。

  根据对象的存活时间，分为年轻代、老年代俩部分：

  - 年轻代

    包括eden（意为伊甸园，即对象出生的地方） s0 s1三部分区域，一般比例是8:1:1，这里区域划分是为了方便之后的垃圾回收。应该是有一个参数配置这个比例。

  - 老年代

    一般占2/3的空间，一般而言，存活较久的对象会被放到老年代中。

  对象会有一个比较重要的属性，年龄，经过一次gc存活下来，年龄加一，一般到15之后，即被放到老年代，证明不会轻易被回收。这里取15是因为存放age的地方在对象头中，而对象头中只为age分配了4位的空间，所以age最大是15。

  **字符串常量池**

  提升字符串创建的效率的一种方法，算是一种缓存。

  -------

  ```java
  String name = "tom";
  ```

  为字符串开辟了一个字符串常量池，类似于缓冲区；

  之后基于字面量创建字符串常量的时候，首先查询字符串常量池中是否存在对应字符串；

  如果存在，即直接返回产量池中的地址，没有的话直接在常量池中创建对应string对象，并返回地址。

  ------

  ```java
  String name = new String("tom");
  ```

  这里创建name的时候，首先看字符串常量池中是否存在对应字符串；

  没有的话即在常量池中创建tom，同时在堆中也创建一个tom，返回在堆中创建的对象；

  如果存在，直接在堆中创建，并返回对象。

  ------

  同时有一个intern的方法，调用字符串的intern方法，如果字符串常量池中存在，即返回常量池中该对象的地址，否则，在字符串常量池中构建指向该地址的引用，并返回字符串的原地址。

  ------

  **jvm编译优化**

  如果java代码中存在由常量构成的表达式，会被编译器优化

  ```java
  String a = "a" + "b" + "c";
  ```

  以上代码会被优化成

  ```java
  String a = "abc";
  ```

  之所以能被优化，因为这里"a" "b" "c"都是常量，确定的量

  但是如果是下面这个例子就不一样了

  ```java
  String a = "a";
  String b = "b";
  String c = "c";
  String d = a + b + c;
  ```

  上面的代码是不会被优化成"abc"的，因为a b c都是变量。

  **整型常量池**

  Integer默认缓存-128到127的Integer对象。

  基本所有基本类型都会有一个缓存

- 方法区

  包含加载的类、方法、常量、静态变量，是多个线程之间共享的。

  这个是1.8之后做了一定的改动，是直接用的物理内存，如果不设置，默认初始值是21M，之后根据具体使用情况进行缩小或者扩张。每次缩小或者扩张，都是在full gc之后做的，而full gc是比较耗费时间的，故对于规模较大的程序，如果没有设置方法区初始大小，启动过程中，会频繁因为方法区不够而触发full gc，拖慢启动速度。
  
  **常量池**
  
  一般一个类中会有一部分常量池，包含其中的字面量以及符号引用，之后加载类的时候，会把这些常量放到方法区，而存放这些常量的区域被成为运行时常量池。
  
  **字面量**
  
  是由字母、数字等构成的字符串或者数值常量，应该是直接对应了基本数据类型以及string。
  
  **符号引用**
  
  类和接口的全限定名
  
  字段的名称和描述符
  
  方法的名称和描述符
  
  **直接引用**
  
  **动态链接**
  
  上面讲的符号引用在class文件中，我们并不知道它们的真实值是什么，即指向什么地址，只有在方法运行时，我们才能知道这些符号引用指向什么地址，这个过程被称为动态链接。
  
  **静态链接**
  
  与动态链接相对应的是静态链接，即在类加载的时候，把class文件中的常量池加载到运行时常量池，之后将类中的静态变量、常量等符号引用指向运行时常量池的具体地址，它们的地址是定的，被称为静态链接。

### 2.2 jvm启动参数

这里列举了常用的针对jvm内存模型大小设置的启动参数：

- 堆

  - Xms 堆大小的最小值

  - Xmx 堆大小的最大值

  - Xmn 年轻代大小

    一般这里Xms和Xmx设置成一样的值，一次分配到位，防止因为堆空间不足触发gc，拖慢系统运行。

  
  - XX:+UseAdaptiveSizePolicy
  
    这个参数会自动调整eden以及s0 s1之间的比例
  
  - Xss 线程栈大小
  
    这里是启动一个线程，jvm给它分配的内存大小，一般而言，对于io密集型程序，可以稍微小一些，对于运算密集型程序可以稍微大一些。
  
  - XX:MetaspaceSize 方法区触发fullgc的初始值
  
  - XX:MaxMetaspaceSize 方法区最大大小
  
    同堆大小设置，这里一般也会设置成相同的配置，视程序大小来设置，**一定要有**，否则就会采用默认初始值，拖慢系统启动速度，具体解释见2.1方法区介绍。

### 2.3 jvm gc初探

这里大体讲下gc的概念，语义上是垃圾回收，即空间不够用的时候，做的一步就是回收不会再被使用的对象。对于gc，有两个重要的概念，**gc root**、**stw**，前者是gc过程中进行对象引用标记的起点，由gc root开始，把被引用到的对象标记出来，意思是它们目前还在使用，不要回收，剩余的对象没有引用，则可以被当成垃圾回收。同时，由gc root开始做对象引用标记的过程中，需要所有的用户线程停止一切动作，否则会导致标记结果不准确，在这个过程中对于jvm中的用户线程而言，世界都停止了，所以这个过程被称为stop the world，即stw。stw因为设计所有用户线程的停止运行，故会影响java程序的流畅性。

gc分类：

- young gc

  针对年轻代的gc，前面讲解年轻代的空间的时候，提到年轻代有eden、s0、s1三部分构成，所有对象都是构建在eden中的，如果eden中的空间不够用了，即触发young gc，期间会stw，并找到还有被引用的对象，存放到s0中，之后清空eden以及s1中的对象，之后程序继续运行，直到eden空间又不够了，同样会stw，找到还有被引用的对象，放到干净的s1中（因为s1已经在上一轮gc中被清空）。。。。

  所以这里s0、s1是交替使用的关系，任意时刻，这两个区域总有一个是干净的，用于存放下一次gc之后还存活的对象。

  对于经过一次gc存活下来的对象，它的**age**会加一，当age足够大，会在适当的时机被放到老年代中，可能是存放存活对象的s区域不够用了或者是其它原因。

- full gc

  如果老年代经过一段时间程序运行，空间也不够了，或者方法区在程序启动过程中，空间不够了，就会触发full gc，相对于young gc，它耗费的时间要大的多，因为这里要扫描所有的对象，而young gc中只会扫描年轻代中的对象，因而full gc中stw时间会久一些。故full gc是要尽量避免的，之后的jvm调优中，一部分内容就是讲怎么避免频繁触发full gc。

讲义中讲了一个例子，说对于一个大促过程中的系统，产生对象的速度要比平时多很多，同时这些对象也会很快变成垃圾对象，这些对象都是在年轻代中生成、存放的，为了避免full gc，即这些垃圾对象在被回收之前进入老年代，可以考虑增加年轻代的空间，尽量让垃圾对象一直在年轻代中，到下次触发young gc的时候直接被回收。

系统的jvm参数应该是可以根据具体场景估算出来的，即根据要承担的压力来判断。

## 3. jvm对象创建

> 对象创建总体而言，包括类加载、分配内存空间、内存初始化、执行__init__方法等步骤
>

### 3.1 类加载

判断当前类加载器中是否有对象的类，没有的话，即重新加载，具体过程参照1.2。

### 3.2 内存分配

> jvm内存分配主要有两种方式：
>
> - 指针碰撞，针对内存空间连续的情况
> - 空闲列表，针对空间零散的情况
>
> 同时这两种方式都会面临并发线程安全的问题，可以采用以下方式解决：
>
> 1. 每个线程会给分配一块空间，由它单独使用，不存在线程竞争，这块区域被称为thread local allocate buffer（tlab）
> 2. 如果tlab不够用，只能通过cas的方式来竞争分配了

涉及一个概念：**逃逸分析**，1.8之后，jdk默认开启，即在方法中创建对象，分析对象是否会被方法作用域外部的对象引用，如果不存在，即说明对象没有逃逸出方法的作用域，就可以考虑在线程栈中直接构建对象。

如果对象不是太大，就直接构建在线程栈中，构建过程中，可以看对象是否可以做进一步拆分，如下：

```java
class Person {
  private String name;
  private Integer age;
}
```

这里，一个Person类型的对象即可拆分成为name和age，它们不会占用连续的内存空间，这里能够被继续拆分的对象被称为**聚合量**，拆分的过程即**标量替换**，不能再被继续拆分的量被称为**标量**。

如果不满足以上条件，对象就要被创建在堆中，默认是创建在eden区域的，这里涉及一个概念：**tlab**（thread local allocate buffer），即为了降低多个线程之间申请堆内存的冲突，在构建线程的时候，即为该线程指定一块内存区域，一般是1m（todo 应该也是有参数配置），如果能放下，就可以直接放置在这块区域；如果放不下，当前线程即以**cas**的方式竞争申请地址。

同时，还会涉及一个**大对象**的问题，如果配置了大对象参数（todo 应该不是默认的），超过设置的值，即直接放置于老年代。这样做的好处是，根据程序实际出发，如果确定业务流程产生的对象基本不会特别大，而特别大的对象基本是一些静态的配置，就可以这么做。

ok，到这一步，即为对象申请到了内存，可能是在线程栈中，可能是在eden中，也可能直接分配到老年代。

### 3.3 初始化

即把分配到的内存空间置零，经过这一步，成员变量被初始化为默认值

| 类型    | 默认值 |
| ------- | ------ |
| int     | 0      |
| long    | 0L     |
| short   | 0      |
| double  | 0.0    |
| float   | 0.0F   |
| boolean | false  |
| byte    | 0      |
| char    | 0      |
| 对象    | null   |

### 3.4 初始化对象头

对象头用于存放对象的锁、hashcode、gc标记等信息。由mark work、klass pointer、数组长度（数组独有）构成。

- mark word

  存放对象运行的基本信息，32位占4个字节，64位占8个字节，这片空间基于对象的不同锁状态盛装不同结构的数据

  - sync锁状态标识位

    1.8，sync锁的状态包含：无锁、偏向锁、轻量级锁、重量级锁几种状态。

    - 无锁

      记录对象的hashcode

    - 偏向锁

      记录偏向线程的线程栈地址，没有位置存放hashcode

    - 轻量级锁

      todo

    - 重量级锁

      记录对应monitor地址

  - gc标记位

    zgc之前，对于serial、paral、cms、g1这些垃圾收集器，对象的gc标志位是在对象头的，即标记对象是否是垃圾，同时也会记录对象的age，age使用4位来记录，故age最大为15

- klass pointor

  指向方法区对象元数据，给c++程序用的。

  32位系统占用4个字节；

  64位系统理论上占用8个字节，但是目前内存大小不会有那么大，jvm默认开启了指针压缩，实际上是为了抹去地址前面相当长的无效位，即便内存到了TB的级别，也只是占用40位。**内存大小小于4g（地址实际占用空间在32以内），直接抹去前32位，指针压缩最多支持到35位，即内存大小在32g以内，会被压缩到32位；但是如果内存超过32g，指针压缩即失效，仍然占用64位的空间**。

- 数组长度

  只有对象是数组时才会有，占用4个字节

- 对象填充

  为了让对象加上对象头以及应用数据占用的空间是8字节的倍数，方便系统处理。

所以，基于以上的知识，64位的系统下，一个Object对象占用的空间是16个字节（8 + 4 + 4（padding） 32g以内）或者（8 + 8 超过32g）。

### 3.5 执行__init__方法

即执行对象的构造代码块以及构造方法。父类的构造代码块以及构造方法也是在这一步执行的。执行顺序如下

类加载阶段

父类静态代码块

子类静态代码块

----------------

对象初始化阶段

父类构造代码块

父类构造方法

子类构造代码块

子类构造方法

## 4. 垃圾收集

在所有问题之前，先确定一点，什么是垃圾？垃圾即没有用到的对象，在程序中，即没有任何引用指向该对象。基于此，一般有两种方案确定垃圾：

- 引用计数

  是一种简单高效的方法，即记录对每个对象的引用数量，数量为0，即为垃圾，因为在运行时即确定，不需要额外扫描，效率高，但是也有致命问题，即不能有效识别循环引用，如果存在a b两个对象，a引用b，b引用a，除此之外，再没有指向两个对象的引用，正常分析，这两个对象大概率是垃圾，但是引用计数法不能识别出来。

  优点：效率高

  缺点：不能识别有效引用

- 可达性分析

  从一系列gc root出发，记录所有被引用的对象。gc root一般是局部变量表、方法区常量对象，它们不是垃圾，被他们引用的对象也不会是垃圾，基于这种理论，即确定所有的存活对象。

  缺点：效率低

引用类型：

- 强引用

- 弱引用

- 软引用

- 虚引用

### 4.1 分代收集理论

java运行过程中生成的对象，多数存活时间都不会太久，经过一轮调用之后，就会变成垃圾，即朝生夕死。基于此，垃圾收集采用分代收集的理论，将堆内存分为年轻代和老年代，对象基于其大小、存活时间等因素被放置在不同的区域，同时，对两个区域采用不同的垃圾收集算法。

一般而言，gc的种类有两种，针对年轻代的gc被称为miner gc，其次是针对所有内存区域的gc，即full gc。对象基本都是在年轻代出生的，同时年轻代的大部分对象也会很快消亡，young gc一般触发频率会比较大，同时老年代的对象因为已经存活了足够久，所以一般不会太快消亡，加入老年代的对象也不会那么多，所以相对于年轻代，不是那么容易满，full gc也就不会太容易触发。

而针对年轻代对象朝生夕死，老年代对象存活较久的特点，它们会采用不同的垃圾回收算法，这一点会在下面具体讲解。

对象在堆中申请内存，没有什么意外，会出生在年轻代，同时可以配置大对象的阈值，如果超过这个阈值，即直接放置于老年代。

### 4.2 垃圾收集算法

总体而言，垃圾收集算法有三种：复制、标记清除、标记整理

- 复制

  把内存分为两块区域，一块用来放对象，一块空置，放置对象的部分放满了之后，就开始垃圾回收，扫描到存活的对象之后，即复制到空置区域。

  优点：速度快

  缺点：如果存活对象比较多，就比较浪费空间

  基于以上特点，就比较适合年轻代的垃圾收集，因为年轻代的对象大部分生命周期较短，所以额外进行复制的区域不会太大。

- 标记清除

  不同于复制，整个垃圾回收步骤分为两个阶段，1.标记 2.清除，首先标记出存活的对象，之后清除对应的垃圾。

  会有两个问题：

  效率问题，标记比较浪费时间，所以会考虑和用户线程并行，减少stw的时间

  空间问题，这种直接清除，会产生空间碎片，所以一般使用标记清除算法的垃圾收集器都会加一步最后的空间整理

- 标记整理

  在清除的基础上加了整理的步骤，首先做标记清除，之后把存活的对象向一端移动，最后清空闲置空间。

  这么整，不会有垃圾碎片，但是，缺点就是因为有整理的步骤，就得要求整个标记整理的过程中不能有用户线程活动，stw时间就会比较久。

### 4.3 垃圾收集器

垃圾收集器即垃圾收集算法的具体实现，jdk中包含的垃圾收集器大体如下：

![](/Users/sunny/Documents/notes/垃圾收集器.png)

如图，g1之前的垃圾收集器即明确界定了年轻代和老年代之间的物理界限，之后他们的界限就不是那么清晰了，更倾向于把堆空间划分为一个个小区域，垃圾回收以小区域为单位进行，而年轻代、老年代即使用软件方式定义。

#### 4.3.1 单线程收集器

初代的垃圾收集器是单线程的方式进行的，即serial收集器，年轻代的收集器是serial，老年代是serial old，年轻代的收集算法是复制算法，老年代是标记整理算法。

--------

年轻代分为eden、survivor1、survivor2三个区域，其中对象出生在eden，s1、s2轮流用来放置垃圾收集之后存活的对象，使用xmn配置年轻代大小。基于对象大多朝生夕死的前提，eden会比s区域大的多，默认比例是8:1:1，大体流程如下：

1. 对象出生在eden

2. eden空间不够，触发minor gc

3. 将存活的对象复制到s1，之后清空eden

   ……

4. eden空间又不够了，再次触发minor gc

5. 将eden、s1的存活对象复制到s2，之后清空eden、s1

   ……

这就是minorgc的大体流程。其中有些细节：

1. 开始minor gc前，会判断年轻代中的存活对象是否比老年代剩余空间大，如果要大，即判断是否开启**老年代空间分配担保机制**，如果开启担保机制，再次判断之前每次执行minor gc之后进入老年代的对象大小是否比老年代的剩余空间大，如果还是放不下，就认为堆空间不够放了，就会触发full gc。
2. 对象会有一个**年龄**的概念，年轻代中，对象每经历一次gc不被回收，年龄加一，默认年龄到15之后，就要被放到老年代。这个年龄是可以配置的，根据系统实际情况来看，如果发现临时对象基本不到15就被回收了，可以考虑把到老年代的年龄配置的小一点，减少对象在s区域之间来回复制的次数。
3. 同时也会有一个**动态年龄判断机制**，即如果经过minor gc之后，年龄从1+2+……+n到对象大小占s区域大小超过50%，那么经过gc之后，年龄大于等于n的对象都会被放到老年代。从这里看，就是如果系统突然流量激增，而年轻代大小不够，导致频繁minor gc，而存活对象很容易达到s区域的50，这样就会导致一些生命周期本来不长的对象被放到了老年代，导致老年代空间逐步增加，之后引发full gc，拖慢系统运行。所以，如果考虑到系统会承受较大的流量冲击，年轻代不要设置的太小。

--------------

老年代大小一般是堆总大小的2/3。



这里单线程收集器整个过程都是要stw的，如果堆内存过大，stw时间会太久，用户的请求会有明显停顿；但是，因为是单线程，不存在多线程交互的消耗，效率较高。

综合以上，单线程垃圾收集器适合小内存，单核的系统。

#### 4.3.2 多线程垃圾收集器

- paralle收集器

  是单线程垃圾收集器的多线程版本，基本思路一致。分paralle做minor gc和paralle old做老年代gc。

- paralle new收集器

  做minor gc，大体步骤是和paralle收集器一致，是为了配置cms收集器来做的。

> 前面讲的收集器，从单线程到多线程，都是要全程stw，好处是可以集中cpu的生产力做完gc，吞吐量会比较高，缺点也比较明显，如果内存比较大，那么全程stw的时间就会比较久，系统停顿也会比较久，这对要求快速响应的场景几乎是致命的，所以后面垃圾收集器的发展方向就是尽量缩短stw的时间，垃圾收集的一些阶段也可以设计成和用户线程并行，缩短停顿时间，同时将原有的停顿时间分成几片，进一步降低调用方的对停顿的感知。之后的cms g1 zgc都是在这个思路上做的。

下面依次讲真正实现和用户线程并行的收集器，和他们的并发思路思路。

因为是和用户线程并行，所以会有多标、漏标的风险。多标会产生浮动垃圾，漏标就比较严重，会导致原来存活的对象被回收，下面每个收集器会讲下他们的处理方案。

- cms

  针对老年代，将原来的一次stw分成三部分，同时最耗费时间的对象标注和用户线程一起并发来做，极大降低stw时间。步骤如下：

  1. 初始标记

     会stw，这里首先标记了gc root

  2. 并发标记

     和用户线程并行，以第一步标记的gc root为基础，做可达性分析，将可到达的对象标注出来，使用的是三色标记。

  3. 重新标记

     会stw，第二步是和用户线程一起做的，标记结果会和真正结果有一些偏差，这里是来修正偏差，保证标记的准确性。具体是，使用写屏障，并发标记时，有引用变化的对象，会被重新标记为灰色，这样在这一步会重新基于这些对象做可达性分析。

  4. 并发清除

     使用标记清除的方案来清理未标记的对象。

  5. 标记重置

     重置对象中的标记信息。

  针对漏标的情况，cms中采用**增量更新**的方案，即有对象的引用发生变化，就在重新标记的过程中扫描这些对象。

  cms的这种设计会有一些问题：

  - 回收线程和用户线程抢占cpu，导致低吞吐量

  - 并发清除的时候，会产生浮动垃圾

  - 因为采用的是标记清除算法，会产生垃圾碎片。

    所以会配置在cms执行完毕之后进行内存整理。

  - 回收线程和用户线程并行工作，如果此时，又有大对象存入老年代，再次导致full gc，此时会stw，使用serial old单线程垃圾收集器来收集垃圾，效率更低。

    可以配置老年代的最大内存占用率，默认80%，即占用超过80%就触发fullgc。

- g1

  g1对stw做了进一步切分，其中已经没有了年轻代和老年代的明确的界限。cms中，一次full gc会把能找到的垃圾都回收了，遇到堆内存比较大的情况，stw还是不会太乐观，所以就有了g1。g1的核心是把内存分成同样大小的region，之后根据用户设置的最大停顿时间决定是否要做gc。

  g1垃圾回收器中，默认将堆内存划分成大小相同的块，默认为2048个，对于划分出来的块，可能会有几种状态：年轻代、老年代、大对象区域、空置。其中年轻代的软件结构基本没变，只不过最小单位是划分出来的块。初始年轻代的大小是5%的空间，之后随着对象增多，年轻代的空间会逐步增加，直到预估的回收时间到了设定的阈值。如果对象大小超过了一个块的50%，即称为大对象，会单独放到存放大对象的块中，而不是到老年代。

  年轻代的回收算法同样是复制算法。老年代用的是标记复制，老年代的具体步骤如下：

  1. 初始标记

  2. 并发标记

  3. 最终标记

  4. 筛选回收

     前三步基本和cms一致，第四步会对每个块基于回收的收益做排序，在用户给定的停顿时间内，基于块的收益，从高到低做标记复制。

  针对漏标的情况，g1使用原始快照的方式，即记录下来有引用变化的对象，本次垃圾回收不做清理，等到下次回收再做处理，即可能产生浮动垃圾。

  垃圾回收类型：

  - young gc

    初始年轻代的空间是整个空间的5%，当年轻代满了之后，不会马上执行young gc，而是会估算当前执行gc的时间是否超过设定的阈值，没有的话，扩容年轻代，直到下一次eden放满，回收时间接近设置的阈值，即执行young gc。

  - mixed gc

    老年代的堆占有率达到阈值，即触发mix gc，其中包括对年轻代所有对象、老年代部分对象、大对象的收集，不会收集所有老年代对象，会基于区域的回收收益，按收益从大到小的排序，在给定gc阈值内回收对应的区域。回收过程即将区域内存活对象复制到另一个空白区域中，拷贝过程中如果没有足够多的空白区域，即触发full gc。

  - full gc

    会stw，使用单线程进行标记、清理、压缩整理，好空下来一批区域供下次mixgc使用。

  常用配置：

  todo

cms以及g1中使用三色标记来做对象标记，具体的标记信息是放在对象头中的，将对象分为三种颜色：黑色、灰色、白色，黑色为已经扫描过的对象、灰色为还没扫描完的对象、白色为没有扫描到的对象，这样看，最终做收集的时候，要被清理的对象是白色标记的，颜色标记是放在对象头的mark word中的。

**为什么cms和g1中重新标记的思路不同**？

cms采用的是增量更新，g1采用的是原始快照。从效率上理解吧，cms适用的内存会比g1的内存小，这种直接重新扫描时间还是可以接受的，但是g1一般内存比较大，同时本身g1的垃圾回收也不是说要回收所有的垃圾，而是基于用户配置的最大停顿时间来的，这样做会影响最大停顿时间。

- zgc

  是jdk未来会使用的垃圾收集器，一直在完善。支持的内存更大，到TB水平、stw时间更短，控制在10ms以内，对cpu的影响控制在15%以内。

### 4.4 安全点

安全点是程序运行的一些位置，运行到这些地方，状态是确定的，jvm就可以安全的做一些操作。

不是所有时机都适合做gc的，会有一些安全点供stw，gc。

jvm会提供一个是否要gc的标识位，之后每个线程执行到安全点，发现标识位为true，即挂起等待gc，等所有线程都就位了，即开始gc。

常用安全点：

- 方法返回之后

- 调用方法之前
- ……

**安全区域**

一块代码区域中，如果引用关系不会发生变化，即称为安全区域，如果线程位于安全区域，则允许开始gc等操作。

## 5. jvm并发调优实战

调优的思路主要是优化full gc，减少gc的stw时间，避免oom

### 5.1 jvm基本工具

- jmap 查看当前jvm的堆栈信息，包括堆空间使用情况、对象数量以及占用空间

```shell
Usage:
    jmap [option] <pid>
        (to connect to running process)
    jmap [option] <executable <core>
        (to connect to a core file)
    jmap [option] [server_id@]<remote server IP or hostname>
        (to connect to remote debug server)

where <option> is one of:
    <none>               to print same info as Solaris pmap
    -heap                to print java heap summary
    -histo[:live]        to print histogram of java object heap; if the "live"
                         suboption is specified, only count live objects
    -clstats             to print class loader statistics
    -finalizerinfo       to print information on objects awaiting finalization
    -dump:<dump-options> to dump java heap in hprof binary format
                         dump-options:
                           live         dump only live objects; if not specified,
                                        all objects in the heap are dumped.
                           format=b     binary format
                           file=<file>  dump heap to <file>
                         Example: jmap -dump:live,format=b,file=heap.bin <pid>
    -F                   force. Use with -dump:<dump-options> <pid> or -histo
                         to force a heap dump or histogram when <pid> does not
                         respond. The "live" suboption is not supported
                         in this mode.
    -h | -help           to print this help message
    -J<flag>             to pass <flag> directly to the runtime system
```

直接通过histo查看当前的所有对象以及其数量、占用空间

使用dump导出堆栈文件，之后使用可视化工具分析

- jstack查看当前线程运行情况，同时可以检测sync关键字导致的死锁

```shell
jstack pid
```

查看线程堆栈调用信息，一个例子是结合top，查看cpu使用率最高的线程的调用栈

1. top -pid pid，查看对应进程的使用情况
2. 按H，查看具体线程调用情况，找到目标线程（cpu占用、资源占用情况不正常）的id
3. 之后即根据线程id从jstack取出的信息中查看堆栈调用情况

以上是linux中的步骤，mac中top没有查看threadid的功能

- jinfo查看当前进程jvm启动参数、系统参数

```shell
Usage:
    jinfo <option> <pid>
       (to connect to a running process)

where <option> is one of:
    -flag <name>         to print the value of the named VM flag
    -flag [+|-]<name>    to enable or disable the named VM flag
    -flag <name>=<value> to set the named VM flag to the given value
    -flags               to print VM flags
    -sysprops            to print Java system properties
    <no option>          to print both VM flags and system properties
    -? | -h | --help | -help to print this help message
```

直接使用flags，打印jvm参数，或者使用sysprops打印系统参数。

- jstat查看堆内存各部分使用量，以及gc情况

```shell
Usage: jstat --help|-options
       jstat -<option> [-t] [-h<lines>] <vmid> [<interval> [<count>]]

Definitions:
  <option>      An option reported by the -options option
  <vmid>        Virtual Machine Identifier. A vmid takes the following form:
                     <lvmid>[@<hostname>[:<port>]]
                Where <lvmid> is the local vm identifier for the target
                Java virtual machine, typically a process id; <hostname> is
                the name of the host running the target Java virtual machine;
                and <port> is the port number for the rmiregistry on the
                target host. See the jvmstat documentation for a more complete
                description of the Virtual Machine Identifier.
  <lines>       Number of samples between header lines.
  <interval>    Sampling interval. The following forms are allowed:
                    <n>["ms"|"s"]
                Where <n> is an integer and the suffix specifies the units as 
                milliseconds("ms") or seconds("s"). The default units are "ms".
  <count>       Number of samples to take before terminating.
  -J<flag>      Pass <flag> directly to the runtime system.
  -? -h --help  Prints this help message.
  -help         Prints this help message.
```

打印gc信息、堆栈占用情况等，具体的options如下

```shell
-class
-compiler
-gc
-gccapacity
-gccause
-gcmetacapacity
-gcnew
-gcnewcapacity
-gcold
-gcoldcapacity
-gcutil
-printcompilation
```

**class**

实例输出如下：

```shell
# 查看对应进程class加载情况，每1秒看一次，一共输出10次
jstat -class pid 1000 10
Loaded  Bytes  Unloaded  Bytes     Time   
  6304 11885.8        0     0.0       1.53
  6304 11885.8        0     0.0       1.53
  6304 11885.8        0     0.0       1.53
  6304 11885.8        0     0.0       1.53
  6304 11885.8        0     0.0       1.53
  6304 11885.8        0     0.0       1.53
  6304 11885.8        0     0.0       1.53
  6304 11885.8        0     0.0       1.53
  6304 11885.8        0     0.0       1.53
  6304 11885.8        0     0.0       1.53
```

**compiler**

查看编译器编译情况？

```shell
Compiled Failed Invalid   Time   FailedType FailedMethod
    3652      0       0     1.14          0   
```

**gc**

查看gc的大体情况，包括eden、s0、s1、老年代、元数据区等占用大小，以及minor gc、full gc次数、占用时间。

可以根据eden的容量增加速率计算大概多久进行一次minor gc，同时基于minor gc的次数以及消耗时间算出每次消耗时间；

可以根据每次进入老年代的对象大小以及时间大致推算出老年代大概多久会满，同时也可以推算出full gc平均消耗时间。

尽量让每次minor gc之后，进入s区域的对象大小小于总大小的50%，大于50%的话，会触发**动态年龄判断机制**，一些年龄还不够的对象会进入老年代，间接增大了full gc的频率。我的理解就是，尽量让临时对象在年轻代就被清理，同时尽量让一些已知的存活较久的对象尽早进入老年代。如果出现了因为空间分配不合理，导致临时对象进入了老年代，或者持久对象在年轻代中来回复制了多次，才进入老年代，都会降低jvm的gc效率。

**大对象机制。**

老年代的空间也不能太小，不然会因为**空间担保机制**导致full gc。

### 5.2 调优实例

计算minor gc、full gc的次数、时间。

年轻代对象增长速率

minor gc触发频率

full gc触发频率，耗时

‐XX:CMSInitiatingOccupancyFraction=75 老年代容量到75%左右，触发full gc

‐XX:SurvivorRatio=6 eden和survivor的比例

```shell
‐Xms1536M‐Xmx1536M‐Xmn512M‐Xss256K‐XX:SurvivorRatio=6‐XX:MetaspaceSize=256M‐XX:MaxMetaspaceSize=256M ‐XX:+UseParNewGC‐XX:+UseConcMarkSweepGC‐XX:CMSInitiatingOccupancyFraction=75‐XX:+UseCMSInitiatingOccupancyOnly
```



fullgc频繁发生的实例

元空间不够

显示调用了system.gc()，有jvm参数控制禁止这种调用

空间担保机制，老年代空间不够，触发full gc



基于jmap找到不太对劲的对象，之后看这种对象哪里生成的，如果简单的话，可以直接全局搜索到，之后，可以看下哪些线程占用cpu时间会比较长，大概率是有问题的，可以从jstack中追踪下线程的调用栈。



**内存泄漏的问题？**

jvm缓存的使用场景可能会出现，即map，如果map不做特殊处理，会越来越大，首先频繁导致full gc，最终导致oom。要注册缓存淘汰策略，缓存过多了，按照一定策略淘汰。

### 5.3 调优工具

#### 5.3.1 artha

#### 5.3.2 gclog

有一些打印gc的vm参数，大体功能是控制gc 日志内容，控制gc文件数量、路径、大小、名称格式等。

```shell
# 路径 名称格式
‐Xloggc:./gc‐%t.log
# 打印gc详细信息
‐XX:+PrintGCDetails
# 打印gc日期
‐XX:+PrintGCDateStamps
# 打印gc时间
‐XX:+PrintGCTimeStamps
# 打印引发gc的原因 可能是年轻代空间不够 元空间空间不够 老年代空间不够
‐XX:+PrintGCCause 
‐XX:+UseGCLogFileRotation
‐XX:NumberOfGCLogFiles=10
‐XX:GCLogFileSize=100
```

加上前面的jvm的垃圾收集器参数一起整

```shell
-Xms2048m  
-Xmx2048m  
-Xmn768m  
-Xss256k  
-XX:SurvivorRatio=8  
-XX:TargetSurvivorRatio=60  
-XX:MetaspaceSize=256m  
-XX:MaxMetaspaceSize=256m  
-XX:+UseParNewGC  
-XX:+UseConcMarkSweepGC  
-XX:CMSInitiatingOccupancyFraction=92  
-XX:+UseCMSInitiatingOccupancyOnly  
```

cms的日志如下，可以跟cms的流程对应起来

```shell
[GC (CMS Initial Mark) [1 CMS-initial-mark: 1208738K(1310720K)] 1293896K(2018560K), 0.0005314 secs] [Times: user=0.00 sys=0.00, real=0.00 secs] 
[CMS-concurrent-mark-start]
[CMS-concurrent-mark: 0.006/0.006 secs] [Times: user=0.00 sys=0.00, real=0.01 secs] 
[CMS-concurrent-preclean-start]
[CMS-concurrent-preclean: 0.001/0.001 secs] [Times: user=0.00 sys=0.00, real=0.00 secs] 
[CMS-concurrent-abortable-preclean-start]
[CMS-concurrent-abortable-preclean: 0.000/0.000 secs] [Times: user=0.00 sys=0.00, real=0.00 secs] 
[GC (CMS Final Remark) [YG occupancy: 156287 K (707840 K)]2022-09-26T20:46:50.534+0800: 172.032: [Rescan (parallel) , 0.0014300 secs]2022-09-26T20:46:50.536+0800: 172.034: [weak refs processing, 0.0000246 secs]2022-09-26T20:46:50.536+0800: 172.034: [class unloading, 0.0020103 secs]2022-09-26T20:46:50.538+0800: 172.036: [scrub symbol table, 0.0031584 secs]2022-09-26T20:46:50.541+0800: 172.039: [scrub string table, 0.0003604 secs][1 CMS-remark: 1208738K(1310720K)] 1365026K(2018560K), 0.0070799 secs] [Times: user=0.20 sys=0.00, real=0.01 secs] 
[CMS-concurrent-sweep-start]
[CMS-concurrent-sweep: 0.005/0.005 secs] [Times: user=0.00 sys=0.00, real=0.01 secs] 
[CMS-concurrent-reset-start]
[CMS-concurrent-reset: 0.001/0.001 secs] [Times: user=0.00 sys=0.00, real=0.00 secs] 
```

