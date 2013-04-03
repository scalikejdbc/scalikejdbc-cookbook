# 10. Play! Framework との統合

[Play! Framework](http://www.playframework.com/) は元々は Ruby on Rails に強く影響された Java 向けの Web アプリケーションフレームワークでしたが、version 2.0 からは Akka ベースのアーキテクチャに書き直され、Scala での利用を基本とするフレームワークに生まれ変わりました。

2013 年 4 月時点で最新の安定バージョンは 2.1.1 です。

[http://www.playframework.com/](http://www.playframework.com/)

また Play 2.0 からは Typesafe Stack の一部として Typesafe 社が公式にサポートしているプロダクトでもあります。

[http://typesafe.com/stack](http://typesafe.com/stack)


## ScalikeJDBC と Play

ScalikeJDBC の SQL("...") から始まる API は Play が提供する Anorm という DB アクセスライブラリの API コンセプトに影響を受けています。また、Play を使った実案件で ScalikeJDBC が利用された実績が多数あり、Play の関係は強いといえます。


## Play アプリで ScalikeJDBC を使う

Play はプラガブルな構造になっているフレームワークです。ScalikeJDBC も Play プラグインを提供し、スムーズに Play アプリに組み込めるようサポートしています。

[https://github.com/seratch/scalikejdbc/tree/master/scalikejdbc-play-plugin](https://github.com/seratch/scalikejdbc/tree/master/scalikejdbc-play-plugin)

### project/Build.scala

H2 以外の DB を使用する場合は JDBC ドライバーも必要です。

    val appDependencies = Seq(
      "com.github.seratch" %% "scalikejdbc"             % "[1.4,)",
      "com.github.seratch" %% "scalikejdbc-play-plugin" % "[1.4,)"
    )

    val main = PlayProject(appName, appVersion, appDependencies, mainLang = SCALA).settings(
    )

### conf/play.plugins

    10000:scalikejdbc.PlayPlugin

### conf/application.conf

Play の標準の DB プラグインと同じキー名で接続設定を記述することができます。ConnectionPool の設定値は独自のものです。

    # DB で接続する DB
    db.default.driver=org.h2.Driver
    db.default.url="jdbc:h2:mem:play"
    db.default.user="sa"
    db.default.password="sa"

    # ScalikeJDBC 独自の ConnectionPool 設定
    db.default.poolInitialSize=10
    db.default.poolMaxSize=10
    db.default.poolValidationQuery=

　default 以外は以下のように記述します。

    # NamedDB('another) で接続する DB
    db.another.driver=org.h2.Driver
    db.another.url="jdbc:h2:mem:play"
    db.another.user="sa"
    db.another.password="sa"

    # ScalikeJDBC 独自の ConnectionPool 設定
    db.another.poolInitialSize=10
    db.another.poolMaxSize=10
    db.another.poolValidationQuery=

　SQL ロギングなどの ScalikeJDBC 共通設定は以下のように渡します。

    # グローバル設定
    scalikejdbc.global.loggingSQLAndTime.enabled=true
    scalikejdbc.global.loggingSQLAndTime.logLevel=debug
    scalikejdbc.global.loggingSQLAndTime.warningEnabled=true
    scalikejdbc.global.loggingSQLAndTime.warningThresholdMillis=1000
    scalikejdbc.global.loggingSQLAndTime.warningLogLevel=warn

## Play 起動

あとは通常通り play run で起動するだけです。もし設定に問題があれば最初の DB 接続時に例外が発生します。


## PlayFixturePlugin

1.5.2 から Play アプリのテスト用に fixture 機能を提供しています。

[https://github.com/seratch/scalikejdbc/tree/master/scalikejdbc-play-fixture-plugin](https://github.com/seratch/scalikejdbc/tree/master/scalikejdbc-play-fixture-plugin)

実際にどのようにして使用するかの詳細はこちらのサンプルを参照してください。

[https://github.com/seratch/scalikejdbc/blob/master/scalikejdbc-play-plugin/test/zentasks](https://github.com/seratch/scalikejdbc/blob/master/scalikejdbc-play-plugin/test/zentasks)

### conf/play.plugins

必ず PlayPlugin よりも後にロードしてください。

    10000:scalikejdbc.PlayPlugin
    11000:scalikejdbc.PlayFixturePlugin

### conf/application.conf

    db.default.fixtures.test=[ "project.sql", "project_member.sql" ]

### conf/db/fixtures/default/project.sql

fixture データの生成と削除を記述します。

    # --- !Ups
    insert into project (id, name, folder) values (1, 'Play 2.0', 'Play framework');
    insert into project (id, name, folder) values (2, 'Play 1.2.4', 'Play framework');
    insert into project (id, name, folder) values (3, 'Website', 'Play framework');
    alter sequence project_seq restart with 10;

    # --- !Downs
    alter sequence project_seq restart with 1;
    delete from project;
