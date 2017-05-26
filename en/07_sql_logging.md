# 7. SQL Logging

ScalikeJDBc provides a feature to print an SQL statement and its response time. Since the logging feature also prints its stack trace, you can easily understand what method (and what class) a query was issued.

By default, the library prints all the SQL statements in DEBUG logging level and prints the ones which spent longer time than the library's threshold in WARN logging level.

The logging feature supports the slf4j API. Set up needed implementation or configuration in the slf4j's way.

## Configuration

You can configure LoggingSQLAndTimeSettings in GlobalSettings.

    import scalikejdbc._
    GlobalSettings.loggingSQLAndTime = LoggingSQLAndTimeSettings(
      enabled = true,
      logLevel = 'DEBUG,
      warningEnabled = true,
      warningThresholdMillis = 1000L,
      warningLogLevel = 'WARN
    )

## Specifying an implementation of SLF4J

Specify an implementation which is compatible with slf4j-api. Here is a sample which shows you how to use logback.

First, add the logback library to libraryDependencies.

    libraryDependencies += "ch.qos.logback" % "logback-classic" % "1.2.+"

Next, put logback.xml under the classpath root directory like `src/main/resources`

    <configuration>
      <appender name="STDOUT" class="ch.qos.logback.core.ConsoleAppender">
        <encoder>
          <pattern>%d{HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg%n</pattern>
        </encoder>
      </appender>
      <root level="info">
        <appender-ref ref="STDOUT" />
      </root>
    </configuration>

## Output Sample

The library prints as below. In the case, you can see the query was issued inside `models.User.findByEmail(...)`.

    [debug] s.StatementExecutor$$anon$1 - SQL execution completed

      [Executed SQL]
       select * from user where email = 'guillaume@sample.com'; (0 ms)

      [Stack Trace]
        ...
        models.User$.findByEmail(User.scala:26)
        controllers.Projects$$anonfun$index$1$$anonfun$apply$1$$anonfun$apply$2.apply(Projects.scala:20)
        controllers.Projects$$anonfun$index$1$$anonfun$apply$1$$anonfun$apply$2.apply(Projects.scala:19)
        controllers.Secured$$anonfun$IsAuthenticated$3$$anonfun$apply$3.apply(Application.scala:88)
        controllers.Secured$$anonfun$IsAuthenticated$3$$anonfun$apply$3.apply(Application.scala:88)
        play.api.mvc.Action$$anon$1.apply(Action.scala:170)
        play.api.mvc.Security$$anonfun$Authenticated$1.apply(Security.scala:55)
        play.api.mvc.Security$$anonfun$Authenticated$1.apply(Security.scala:53)
        play.api.mvc.Action$$anon$1.apply(Action.scala:170)
        play.core.ActionInvoker$$anonfun$receive$1$$anonfun$6.apply(Invoker.scala:126)
        play.core.ActionInvoker$$anonfun$receive$1$$anonfun$6.apply(Invoker.scala:126)
        play.utils.Threads$.withContextClassLoader(Threads.scala:17)
        play.core.ActionInvoker$$anonfun$receive$1.apply(Invoker.scala:125)
        play.core.ActionInvoker$$anonfun$receive$1.apply(Invoker.scala:115)
        akka.actor.Actor$class.apply(Actor.scala:318)
        ...

I beleive it doesn't matter in most cases, the printed SQL queries are built by ScalikeJDBC library and that is different from an actual one issued to the database server.

## Single Line Mode

If you don't need the stack trace part, you can set `GlobalSettings.loggingSQLAndTime.singleLineMode` as true.

    GlobalSettings.loggingSQLAndTime = new LoggingSQLAndTimeSettings(
      enabled = true,
      singleLineMode = true,
      logLevel = 'DEBUG
    )

Here is a sample output:

    2013-05-26 16:23:08,072 DEBUG [pool-4-thread-4] s.StatementExecutor$$anon$1 [Log.scala:81] [SQL Execution] select * from user where email = 'guillaume@sample.com'; (0 ms)
