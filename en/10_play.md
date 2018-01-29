# 10. Play Framework Integration

[Play! Framework](http://www.playframework.com/)  is originally a Java Web framework heavily insired by Ruby on Rails. Since version 2.0, the framework was rewritten in Scala and became an Akka-based framework.

As of May 2017, the latest version of Play Framework is 2.5.14.

[http://www.playframework.com/](http://www.playframework.com/)

Furthermore, Play 2 is a part of Lightbend Reactive Platform (formerly know as Typesafe Stack). Lightbend (formerly Typesafe) offically develops and supports it.

[https://www.lightbend.com/platform](https://www.lightbend.com/platform)


## Relationship between ScalikeJDBC and Play

The relationship with Play is strong. ScalikeJDBC's API which starts with `SQL("...")` is highly inspired by the concept of Anorm, a database library provided by Play project. As you know, in the real world, many Web service projects in Scala are built with Play. Thankfully, some of them use ScalikeJDBC.


## Using ScalikeJDBC in Play apps

Play is a pluggable framework. ScalikeJDBC project provides a Play module to smoothly integrate the library to Play apps.

[https://github.com/scalikejdbc/scalikejdbc-play-support](https://github.com/scalikejdbc/scalikejdbc-play-support)

### project/Build.scala

Play Framework has H2 database dependency out-of-the-box. If you go with H2, you don't need to add JDBC drivers. Otherwise, having JDBC drivers in libraryDependencies is necessary.

    lazy val root = (project in file("."))
      .enablePlugins(PlayScala)
      .enablePlugins(SbtWeb)
      .settings(
        libraryDependencies = Seq(
          "org.scalikejdbc" %% "scalikejdbc"                  % "3.2.+",
          "org.scalikejdbc" %% "scalikejdbc-config"           % "3.2.+",
          "org.scalikejdbc" %% "scalikejdbc-play-initializer" % "2.6.0-scalikejdbc-3.2"
        )
      )

### conf/application.conf

Add the `scalikejdbc.PlayModule`.

    play.modules.enabled += "scalikejdbc.PlayModule"

You can use the standard configuration of Play apps. Only the attributes for ConnectionPool are ScalikeJDBC specific.

    # DB to connect
    db.default.driver=org.h2.Driver
    db.default.url="jdbc:h2:mem:play"
    db.default.user="sa"
    db.default.password="sa"

    # Extra configuration, ScalikeJDBC specific
    db.default.poolInitialSize=10
    db.default.poolMaxSize=10
    db.default.poolValidationQuery=

For non-default ones, specify the name like `another` in the following sample:

    # NamedDB('another)
    db.another.driver=org.h2.Driver
    db.another.url="jdbc:h2:mem:play"
    db.another.user="sa"
    db.another.password="sa"

    # Extra configuration, ScalikeJDBC specific
    db.another.poolInitialSize=10
    db.another.poolMaxSize=10
    db.another.poolValidationQuery=

ScalikeJDBC's global configurations:

    # グローバル設定
    scalikejdbc.global.loggingSQLAndTime.enabled=true
    scalikejdbc.global.loggingSQLAndTime.logLevel=debug
    scalikejdbc.global.loggingSQLAndTime.warningEnabled=true
    scalikejdbc.global.loggingSQLAndTime.warningThresholdMillis=1000
    scalikejdbc.global.loggingSQLAndTime.warningLogLevel=warn

### Invoking your Play app

Simply invoke by `sbt run` commannd. If the configuration has some problems, an exception will be thrown when connecting to the database for the first time.

## scalikejdbc-play-fixture

The module provides a fixture feature for testing with Play apps.

[https://github.com/scalikejdbc/scalikejdbc-play-support/tree/2.5/scalikejdbc-play-fixture](https://github.com/scalikejdbc/scalikejdbc-play-support/tree/2.5/scalikejdbc-play-fixture)

### conf/application.conf

Don't forget loading the `scalikejdbc.PlayFixtureModule` after `scalikejdbc.PlayModule`.

    play.modules.enabled += "scalikejdbc.PlayModule"
    play.modules.enabled += "scalikejdbc.PlayFixtureModule"
    db.default.fixtures.test= ["project.sql", "project_member.sql"]

### conf/db/fixtures/default/project.sql

Express the statements to create or delete fixture data as below:

    # --- !Ups
    insert into project (id, name, folder) values (1, 'Play 2.0', 'Play framework');
    insert into project (id, name, folder) values (2, 'Play 1.2.4', 'Play framework');
    insert into project (id, name, folder) values (3, 'Website', 'Play framework');
    alter sequence project_seq restart with 10;

    # --- !Downs
    alter sequence project_seq restart with 1;
    delete from project;
