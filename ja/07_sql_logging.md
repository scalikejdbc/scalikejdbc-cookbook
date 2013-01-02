# 7. SQL ロギング

　ScalikeJDBC では実行した SQL とそのレスポンスタイムをログ出力する機能があります。スタックトレースを併せて出力するのでどのクラスのどのメソッドから発行されたものかもすぐにわかるようになっています。

　デフォルトではデバッグレベルですべての SQL を出力、一定値以上の時間がかかった SQL は WARN レベルでログ出力するようになっています。

　このログ出力は SLF4J の API に対応していますので、必要な実装と設定を行ってください。

## 設定

　GlobalSettings に LoggingSQLAndTimeSettings を設定します。設定内容は以下の通りです。

```
import scalikejdbc._
GlobalSettings.loggingSQLAndTime = LoggingSQLAndTimeSettings(
  enabled = true,
  logLevel = 'DEBUG,
  warningEnabled = true,
  warningThresholdMillis = 1000L,
  warningLogLevel = 'WARN
)
```

## SLF4J の実装を設定

　slf4j-api をサポートする実装を指定してください。以下では logback を使用した例を示します。

　まず sbt の設定に依存ライブラリとして logback を追加します。

```
libraryDependencies += "ch.qos.logback" % "logback-classic" % "1.0.7"
```

　次に src/main/resources のようなクラスパスのルートディレクトリに logback.xml というファイル名でログの設定を記述します。

```
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
```

## 出力イメージ

　このようなイメージで出力されます。この場合は models.User.findByEmail(...) というメソッドから発行されていることがわかります。

```
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

```

　あまり問題になるケースはないかとは思いますが、ここに出力された SQL は ScalikeJDBC が SQL テンプレートから組み立てたものなので、実際に JDBC ドライバーから DB に発行されたクエリと全く同じであるとは限りません（見やすくするために不要な空白を除去するなどの処理も入っています）。

