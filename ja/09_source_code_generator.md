# 9. ソースコード自動生成

mapper-generator は DB からリバースエンジニアリングして、ScalikeJDBC のソースコードを生成する sbt プラグインです。

記述量がそれなりに多くなる傾向のある ScalikeJDBC では非常に重要なツールです。

[https://github.com/seratch/scalikejdbc/tree/master/scalikejdbc-mapper-generator](https://github.com/seratch/scalikejdbc/tree/master/scalikejdbc-mapper-generator)

## 準備

### project/scalikejdbc-gen.sbt

sbt プラグイン設定を記述します。JDBC ドライバーの指定を忘れないようにしてください。

    // JDBC ドライバーの指定を忘れずに
    libraryDependencies += "org.hsqldb" % "hsqldb" % "[2,)"

    addSbtPlugin("com.github.seratch" %% "scalikejdbc-mapper-generator" % "[1.6,)")

### project/scalikejdbc.properties

ファイル名と配置場所は固定です。以下のひな形をコピーして使用してください。

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
    # テンプレート: basic/namedParameters/executable/interpolation/queryDsl
    generator.template=queryDsl
    # テストのテンプレート: specs2unit/specs2acceptance/ScalaTestFlatSpec
    generator.testTemplate=specs2unit
    # 生成するファイルの文字コード
    generator.encoding=UTF-8

### build.sbt

「scalikejdbcSettings」を追記して、scalikejdbc-gen　コマンドを有効にしてください。前後に空行を入れるのを忘れないよう注意してください。

    scalikejdbcSettings


## 使い方

scalikejdbc-gen の使い方はとてもシンプルです。scalikejdbc-gen コマンドに続いて、テーブル名を指定、必要なら生成するクラス名を指定します。

    sbt "scalikejdbc-gen [table-name (class-name)]"

例えば「 operation\_history 」というテーブルがあって「 scalikejdbc-gen operation\_history 」を実行すると「src/main/scala/models/OperationHistory.scala」と「src/test/scala/models/OperationHistorySpec.scala」を生成します。

Ruby の ActiveRecord のようなテーブル命名ルールで「 operation\_histories 」というテーブル名の場合は「scalikejdbc-gen operation\_histories OperationHistory」と指定すると同様のファイル名で生成されます。クラス名を指定しないと「OperationHistories.scala」と「OperationHistoriesSpec.scala」を生成します。

## 実際に生成されるコード

それでは少し長いですが実際に生成されるコード例を示します。テストコードも生成されるので、どのように使うクラスかはすぐにわかると思います。

このようなテーブルに対して

    create table member (
      id int generated always as identity,
      name varchar(30) not null,
      description varchar(1000),
      birthday date,
      created_at timestamp not null,
      primary key(id)
    )

「scalikejdbc-gen member」を実行すると以下のようなコードを生成します。

### src/main/scala/com/example/Member.scala

「generator.template」で「queryDsl」を指定、「generator.packageName」で「com.example」を指定したものです。

    package models

    import scalikejdbc._
    import scalikejdbc.SQLInterpolation._
    import org.joda.time.{LocalDate, DateTime}

    case class Member(
      id: Int,
      name: String,
      description: Option[String] = None,
      birthday: Option[LocalDate] = None,
      createdAt: DateTime) {

      def save()(implicit session: DBSession = Member.autoSession): Member = Member.save(this)(session)

      def destroy()(implicit session: DBSession = Member.autoSession): Unit = Member.destroy(this)(session)

    }


    object Member extends SQLSyntaxSupport[Member] {

      override val tableName = "MEMBER"

      override val columns = Seq("ID", "NAME", "DESCRIPTION", "BIRTHDAY", "CREATED_AT")

      def apply(m: ResultName[Member])(rs: WrappedResultSet): Member = new Member(
        id = rs.int(m.id),
        name = rs.string(m.name),
        description = rs.stringOpt(m.description),
        birthday = rs.dateOpt(m.birthday).map(_.toLocalDate),
        createdAt = rs.timestamp(m.createdAt).toDateTime
      )

      val m = Member.syntax("m")

      val autoSession = AutoSession

      def find(id: Int)(implicit session: DBSession = autoSession): Option[Member] = {
        withSQL {
          select.from(Member as m).where.eq(m.id, id)
        }.map(Member(m.resultName)).single.apply()
      }

      def findAll()(implicit session: DBSession = autoSession): List[Member] = {
        withSQL(select.from(Member as m)).map(Member(m.resultName)).list.apply()
      }

      def countAll()(implicit session: DBSession = autoSession): Long = {
        withSQL(select(sqls"count(1)").from(Member as m)).map(rs => rs.long(1)).single.apply().get
      }

      def findAllBy(where: SQLSyntax)(implicit session: DBSession = autoSession): List[Member] = {
        withSQL {
          select.from(Member as m).where.append(sqls"${where}")
        }.map(Member(m.resultName)).list.apply()
      }

      def countBy(where: SQLSyntax)(implicit session: DBSession = autoSession): Long = {
        withSQL {
          select(sqls"count(1)").from(Member as m).where.append(sqls"${where}")
        }.map(_.long(1)).single.apply().get
      }

      def create(
        name: String,
        description: Option[String] = None,
        birthday: Option[LocalDate] = None,
        createdAt: DateTime)(implicit session: DBSession = autoSession): Member = {
        val generatedKey = withSQL {
          insert.into(Member).columns(
            column.name,
            column.description,
            column.birthday,
            column.createdAt
          ).values(
            name,
            description,
            birthday,
            createdAt
          )
        }.updateAndReturnGeneratedKey.apply()

        Member(
          id = generatedKey.toInt,
          name = name,
          description = description,
          birthday = birthday,
          createdAt = createdAt)
      }

      def save(m: Member)(implicit session: DBSession = autoSession): Member = {
        withSQL {
          update(Member as m).set(
            m.id -> m.id,
            m.name -> m.name,
            m.description -> m.description,
            m.birthday -> m.birthday,
            m.createdAt -> m.createdAt
          ).where.eq(m.id, m.id)
        }.update.apply()
        m
      }

      def destroy(m: Member)(implicit session: DBSession = autoSession): Unit = {
        withSQL { delete.from(Member).where.eq(column.id, m.id) }.update.apply()
      }

    }

### src/test/scala/com/example/MemberSpec.scala

「generator.testTemplate」に「specs2unit」を指定したものです。この例以外にも Specs2 の acceptance スタイルや ScalaTest のコードも生成可能です。

    package models

    import scalikejdbc.specs2.mutable.AutoRollback
    import org.specs2.mutable._
    import org.joda.time._
    import scalikejdbc.SQLInterpolation._

    class MemberSpec extends Specification {

      "Member" should {
        "find by primary keys" in new AutoRollback {
          val maybeFound = Member.find(123)
          maybeFound.isDefined should beTrue
        }
        "find all records" in new AutoRollback {
          val allResults = Member.findAll()
          allResults.size should be_>(0)
        }
        "count all records" in new AutoRollback {
          val count = Member.countAll()
          count should be_>(0L)
        }
        "find by where clauses" in new AutoRollback {
          val results = Member.findAllBy(sqls.eq(m.id, 123))
          results.size should be_>(0)
        }
        "count by where clauses" in new AutoRollback {
          val count = Member.countBy(sqls.eq(m.id, 123))
          count should be_>(0L)
        }
        "create new record" in new AutoRollback {
          val created = Member.create(name = "MyString", createdAt = DateTime.now)
          created should not beNull
        }
        "save a record" in new AutoRollback {
          val entity = Member.findAll().head
          val updated = Member.save(entity)
          updated should not equalTo(entity)
        }
        "destroy a record" in new AutoRollback {
          val entity = Member.findAll().head
          Member.destroy(entity)
          val shouldBeNone = Member.find(123)
          shouldBeNone.isDefined should beFalse
        }
      }

    }

