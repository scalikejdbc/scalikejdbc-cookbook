# 9. ソースコード自動生成

　mapper-generator は DB からリバースエンジニアリングして、ScalikeJDBC のソースコードを生成する sbt プラグインです。

　記述量がそれなりに多くなる傾向のある ScalikeJDBC では非常に重要なツールです。

　https://github.com/seratch/scalikejdbc/tree/master/scalikejdbc-mapper-generator

## 準備

### project/scalikejdbc-gen.sbt

　sbt プラグイン設定を記述します。JDBC ドライバーの指定を忘れないようにしてください。

```
// JDBC ドライバーの指定を忘れずに
libraryDependencies += "org.hsqldb" % "hsqldb" % "[2,)"

addSbtPlugin("com.github.seratch" %% "scalikejdbc-mapper-generator" % "[1.4,)")
```

### project/scalikejdbc.properties

　ファイル名と配置場所は固定です。以下のひな形をコピーして使用してください。

```
# JDBC 接続設定
jdbc.driver=org.hsqldb.jdbc.JDBCDriver
jdbc.url=jdbc:hsqldb:file:db/test
jdbc.username=sa
jdbc.password=
jdbc.schema=

# 生成するクラスを配置するパッケージ
generator.packageName=models

# ソースコードの改行コード: LF/CRLF
geneartor.lineBreak=LF

# テンプレート: placeHolderSQL/anormSQL/executableSQL
generator.template=executableSQL

# テストのテンプレート: specs2unit/specs2acceptance/ScalaTestFlatSpec
generator.testTemplate=specs2unit

# 生成するファイルの文字コード
generator.encoding=UTF-8
```

### build.sbt

　「scalikejdbcSettings」を追記して、scalikejdbc-gen　コマンドを有効にしてください。前後に空行を入れるのを忘れないよう注意してください。

```
scalikejdbcSettings
```


## 使い方

　scalikejdbc-gen の使い方はとてもシンプルです。scalikejdbc-gen コマンドに続いて、テーブル名を指定、必要なら生成するクラス名を指定します。

```
sbt "scalikejdbc-gen [table-name (class-name)]"
```

　例えば「operation_history」というテーブルがあって「scalikejdbc-gen operation_history」を実行すると「src/main/scala/models/OperationHistory.scala」と「src/test/scala/models/OperationHistorySpec.scala」を生成します。

　Ruby on Rails のようなテーブル命名ルールで「operation_histories」というテーブル名の場合は「scalikejdbc-gen operation_history OperationHistory」と指定すると同様のファイル名で生成されます。クラス名を指定しないと「OperationHistories.scala」と「OperationHistoriesSpec.scala」を生成します。

## 実際に生成されるコード

　それでは少し長いですが実際に生成されるコード例を示します。テストコードも生成されるので、どのように使うクラスかはすぐにわかると思います。

　このようなテーブルに対して

```
create table member (
  id int generated always as identity,
  name varchar(30) not null,
  description varchar(1000),
  birthday date,
  created_at timestamp not null,
  primary key(id)
)
```

「scalikejdbc-gen member」を実行すると以下のようなコードを生成します。

### src/main/scala/com/example/Member.scala

　「generator.template」で「executableSQL」を指定、「generator.packageName」で「com.example」を指定したものです。

```
package com.example

import scalikejdbc._
import org.joda.time.{ LocalDate, DateTime }

case class Member(
    id: Int,
    name: String,
    memberGroupId: Option[Int] = None,
    description: Option[String] = None,
    birthday: Option[LocalDate] = None,
    createdAt: DateTime) {

  def save()(implicit session: DBSession = Member.autoSession): Member = Member.update(this)(session)

  def destroy()(implicit session: DBSession = Member.autoSession): Unit = Member.delete(this)(session)

}

object Member {

  val tableName = "MEMBER"

  object columnNames {
    val id = "ID"
    val name = "NAME"
    val memberGroupId = "MEMBER_GROUP_ID"
    val description = "DESCRIPTION"
    val birthday = "BIRTHDAY"
    val createdAt = "CREATED_AT"
    val all = Seq(id, name, memberGroupId, description, birthday, createdAt)
  }

  val * = {
    import columnNames._
    (rs: WrappedResultSet) => Member(
      id = rs.int(id),
      name = rs.string(name),
      memberGroupId = rs.intOpt(memberGroupId),
      description = rs.stringOpt(description),
      birthday = rs.dateOpt(birthday).map(_.toLocalDate),
      createdAt = rs.timestamp(createdAt).toDateTime)
  }

  object joinedColumnNames {
    val delimiter = "__ON__"
    def as(name: String) = name + delimiter + tableName
    val id = as(columnNames.id)
    val name = as(columnNames.name)
    val memberGroupId = as(columnNames.memberGroupId)
    val description = as(columnNames.description)
    val birthday = as(columnNames.birthday)
    val createdAt = as(columnNames.createdAt)
    val all = Seq(id, name, memberGroupId, description, birthday, createdAt)
    val inSQL = columnNames.all.map(name => tableName + "." + name + " AS " + as(name)).mkString(", ")
  }

  val joined = {
    import joinedColumnNames._
    (rs: WrappedResultSet) => Member(
      id = rs.int(id),
      name = rs.string(name),
      memberGroupId = rs.intOpt(memberGroupId),
      description = rs.stringOpt(description),
      birthday = rs.dateOpt(birthday).map(_.toLocalDate),
      createdAt = rs.timestamp(createdAt).toDateTime)
  }

  val autoSession = AutoSession

  def find(id: Int)(implicit session: DBSession = autoSession): Option[Member] = {
    SQL("""SELECT * FROM MEMBER WHERE ID = /*'id*/1""")
      .bindByName('id -> id).map(*).single.apply()
  }

  def findAll()(implicit session: DBSession = autoSession): List[Member] = {
    SQL("""SELECT * FROM MEMBER""").map(*).list.apply()
  }

  def countAll()(implicit session: DBSession = autoSession): Long = {
    SQL("""SELECT COUNT(1) FROM MEMBER""").map(rs => rs.long(1)).single.apply().get
  }

  def findBy(where: String, params: (Symbol, Any)*)(implicit session: DBSession = autoSession): List[Member] = {
    SQL("""SELECT * FROM MEMBER WHERE """ + where)
      .bindByName(params: _*).map(*).list.apply()
  }

  def countBy(where: String, params: (Symbol, Any)*)(implicit session: DBSession = autoSession): Long = {
    SQL("""SELECT count(1) FROM MEMBER WHERE """ + where)
      .bindByName(params: _*).map(rs => rs.long(1)).single.apply().get
  }

  def create(
    name: String,
    memberGroupId: Option[Int] = None,
    description: Option[String] = None,
    birthday: Option[LocalDate] = None,
    createdAt: DateTime)(implicit session: DBSession = autoSession): Member = {
    val generatedKey = SQL("""
      INSERT INTO MEMBER (
        NAME,
        MEMBER_GROUP_ID,
        DESCRIPTION,
        BIRTHDAY,
        CREATED_AT
      ) VALUES (
        /*'name*/'abc',
        /*'memberGroupId*/1,
        /*'description*/'abc',
        /*'birthday*/'1958-09-06',
        /*'createdAt*/'1958-09-06 12:00:00'
      )
      """)
      .bindByName(
        'name -> name,
        'memberGroupId -> memberGroupId,
        'description -> description,
        'birthday -> birthday,
        'createdAt -> createdAt
      ).updateAndReturnGeneratedKey.apply()

    Member(
      id = generatedKey.toInt,
      name = name,
      memberGroupId = memberGroupId,
      description = description,
      birthday = birthday,
      createdAt = createdAt)
  }

  def update(m: Member)(implicit session: DBSession = autoSession): Member = {
    SQL("""
      UPDATE 
        MEMBER
      SET 
        ID = /*'id*/1,
        NAME = /*'name*/'abc',
        MEMBER_GROUP_ID = /*'memberGroupId*/1,
        DESCRIPTION = /*'description*/'abc',
        BIRTHDAY = /*'birthday*/'1958-09-06',
        CREATED_AT = /*'createdAt*/'1958-09-06 12:00:00'
      WHERE 
        ID = /*'id*/1
      """)
      .bindByName(
        'id -> m.id,
        'name -> m.name,
        'memberGroupId -> m.memberGroupId,
        'description -> m.description,
        'birthday -> m.birthday,
        'createdAt -> m.createdAt
      ).update.apply()
    m
  }

  def delete(m: Member)(implicit session: DBSession = autoSession): Unit = {
    SQL("""DELETE FROM MEMBER WHERE ID = /*'id*/1""")
      .bindByName('id -> m.id).update.apply()
  }

}
```

### src/test/scala/com/example/MemberSpec.scala

　「generator.testTemplate」に「specs2unit」を指定したものです。

```
package com.example

import org.specs2.mutable._
import org.joda.time._

class MemberSpec extends Specification {

  "Member" should {
    "find by primary keys" in {
      val maybeFound = Member.find(123)
      maybeFound.isDefined should beTrue
    }
    "find all records" in {
      val allResults = Member.findAll()
      allResults.size should be_>(0)
    }
    "count all records" in {
      val count = Member.countAll()
      count should be_>(0L)
    }
    "find by where clauses" in {
      val results = Member.findAllBy("ID = {id}", 'id -> 123)
      results.size should be_>(0)
    }
    "count by where clauses" in {
      val count = Member.countBy("ID = {id}", 'id -> 123)
      count should be_>(0L)
    }
    "create new record" in {
      val created = Member.create(name = "MyString", createdAt = DateTime.now)
      created should not beNull
    }
    "update a record" in {
      val entity = Member.findAll().head
      val updated = Member.update(entity)
      updated should not equalTo (entity)
    }
    "delete a record" in {
      val entity = Member.findAll().head
      Member.delete(entity)
      val shouldBeNone = Member.find(123)
      shouldBeNone.isDefined should beFalse
    }
  }

}

```


