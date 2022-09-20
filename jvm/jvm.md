# jvm

## 1. 类加载器

> 使用java命令启动一个java程序，会启动一个jvm，即java虚拟机，而java虚拟机中具体执行代码之前就是要加载所需要的类，加载类的工作是由类加载器实现的

## 1.1 加载器层级

jvm启动的时候，首先会由c++程序启动一个引导类加载器，即bootstrap类加载器；

之后由该类加载器加载Launcher类，其中会构建扩展类加载器以及应用类加载器；

构建的类加载器之间是有层级关系的，从逻辑而言从上到下依次是：

- 引导类加载器

  加载jre/lib下面的核心包，如Object String等

- 扩展类加载器

  加载jre/lib/ext下面的扩展包，现在可以理解成插件的形式

- 应用类加载器

  加载java程序启动时候传入的classpath下的包，java中代码中自定义加载器的父加载器就是应用类加载器

## 1.2 类加载过程

### 1.2.1 双亲委派机制

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

### 1.2.2 具体加载过程

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

java语言天然具有跨平台的特性，不同平台的区别体现在不同的jdk版本上，它们能识别同样的class文件，并转化为对应平台的机器码命令。

> jvm组成
>
> - 类装载子系统
>
> - 内存模型
>
>   jvm调优主要是针对这里做的
>
> - 字节码执行引擎

jvm内存模型组成

- jvm栈

  是**线程独有**的

  给线程分配的内存空间，用于存放线程内部的局部变量，保证了线程安全

  每个线程的栈是由一个个栈帧构成，每个栈帧对应一个方法，只有最上层的栈帧是激活状态，这里用栈描述了方法的调用关系，这个栈的容量是有限制的，所以不可能无限的调用，每个栈帧包含了如下信息：

  - 局部变量表 

    基本类型

  - 操作数栈

    执行具体操作的值 

  - 动态链接 指向堆中的地址

  - 返回地址

- 堆

  

- 方法区

- 本地方法区

- 程序计数器

  **线程独有**

  表示当前线程的执行位置，用户线程切换的时候重新进行定位

  