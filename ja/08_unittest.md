# 8. ユニットテスト

このセクションでは、ScalikeJDBC を使ったプログラムのテストの例を示します。

## scalikejdbc-test

ScalaTest と specs2 にそれぞれ同等のサポート機能を提供するサブプロジェクトです。1.4.2 から提供が開始されました。

    val appDependencies = Seq(
      "org.scalikejdbc"   %% "scalikejdbc"      % "3.2.+",
      "org.scalikejdbc"   %% "scalikejdbc-test" % "3.2.+"   % "test",
      "org.scalatest"     %% "scalatest"        % "3.0.+"   % "test"
      "org.specs2"        %% "specs2-core"      % "3.8.9"   % "test"
    )

## 接続情報

ConnectionPool を設定する trait を用意して mixin する方法があります。複数のデータソースを使用する場合にも ConnectionPool.add(...) を使用して同様に設定すれば OK です。

    trait TestDBSettings {

      def loadJDBCSettings() {
        // https://github.com/typesafehub/config
        val config = ConfigFactory.load()
        val url = config.getString("jdbc.url")
        val user = config.getString("jdbc.user")
        val password = config.getString("jdbc.password")
        ConnectionPool.singleton(url, user, password)
      }

      loadJDBCSettings()
    }

    import org.scalatest._

    object MemberSpec extends FlatSpec with Matchers with TestDBSettings {
      behavior of "Member"

      it should "create new record" in {
        val created = Member.create("Alice", None, DateTime.now)
        created should not be(null)
      }
    }

もちろん Web アプリケーションの開発などフレームワーク側で設定を読み込む仕組みがある場合はそれに従うのがスムーズかと思います。

Typesafe Config を使っている場合は

[https://github.com/typesafehub/config](https://github.com/typesafehub/config)

scalikejdbc-config を使うことができます。

[https://github.com/scalikejdbc/scalikejdbc/tree/master/scalikejdbc-config](https://github.com/scalikejdbc/scalikejdbc/tree/master/scalikejdbc-config)

Play の設定は Typesafe Config になっていますが、それ以外のアプリケーションでも例えば application.conf で以下のように設定が書かれている場合

    db.default.url="jdbc:h2:mem:sample1"
    db.default.driver="org.h2.Driver"
    db.default.user="sa"
    db.default.password="secret"

初期化処理で以下のようにして簡単に読み込むことができます。

    import scalikejdbc.config._
    DBs.setup()

複数の設定が指定されていて一括で読み込む場合は

    db.foo.url="jdbc:h2:mem:sample2"
    db.foo.driver="org.h2.Driver"
    db.foo.user="sa"
    db.foo.password="secret"

    db.bar.url="jdbc:h2:mem:sample2"
    db.bar.driver="org.h2.Driver"
    db.bar.user="sa2"
    db.bar.password="secret2"

DBs.setupAll を呼び出します。

    import scalikejdbc.config._
    DBs.setupAll()


## 自動ロールバックとフィクスチャー

ScalikeJDBC では ScalaTest と specs2 に対して、自動ロールバックを簡単に対応させるための trait を提供しています。それぞれについて見ていきましょう。

まずは ScalaTest の例です。ScalaTest では org.scalatest.fixture というパッケージにある基底クラスを使っている場合に自動ロールバックとフィクスチャー機能を使用することができます。

自動ロールバックのみで良い場合は以下のように AutoRollback という trait を mixin して、各テストのパラメータで DBSession を受け取るだけです。この DBSession を暗黙のパラメータにしておけば、テスト対象のメソッド実行にも同じセッションを伝播させることができるので（もちろんテスト対象が DBSession を暗黙のパラメータで受け取る実装であることが前提ですが）、すべて一つのトランザクションで処理され、テスト終了後にすべてロールバックされます。

    import scalikejdbc._
    import scalikejdbc.scalatest.AutoRollback
    import org.scalatest.fixture.FlatSpec
    import org.scalatest._

    class MemberSpec extends FlatSpec with Matchers with AutoRollback {

      behavior of "Member"

      it should "create a new record" in { implicit session =>
        val before = Member.count()
        Member.create(3, "Chris")
        Member.count() should equal(before + 1)
      }
    }

デフォルト以外の DB に接続する場合は #db() というメソッドを override して接続先を差し替えてください。

    class MemberSpec extends FlatSpec with Matchers with AutoRollback {

      override def db = NamedDB('db2).toDB

      behavior of "Member"

      ...
    }

フィクスチャーが必要な場合は #fixture(DBSession) を override してください。ここでつくったデータもテスト終了時にすべてロールバックされます。

    class MemberSpec extends FlatSpec with Matchers with AutoRollback {

      override def fixture(implicit session: DBSession) {
        SQL("insert into members values (?, ?)").bind(123, "test_user_123").update.apply()
        SQL("insert into members values (?, ?)").bind(234, "test_user_234").update.apply()
        SQL("insert into members values (?, ?)").bind(345, "test_user_345").update.apply()
      }

      behavior of "Member"

      ...
    }

続いて unit スタイルの specs2 の例です。ScalaTest とは異なり Spec 全体に mixin するのではなく、各テストケースの in の後に new AutoRollback { ... } のようにして指定します。

    import scalikejdbc._
    import scalikejdbc.specs2.mutable.AutoRollback
    import org.specs2.mutable.Specification

    object MemberSpec extends Specification {

      "Member should create a new record" in new AutoRollback {
        val before = Member.count()
        Member.create(3, "Chris")
        Member.count() must_==(before + 1)
      }
    }

デフォルト以外の DB への接続、フィクスチャーは以下の通りです。各テストケース毎にカスタマイズできるので、この点は ScalaTest よりも便利かもしれません。

    trait AutoRollbackWithFixture extends AutoRollback {

      override def db = NamedDB('db2).toDB

      override def fixture(implicit session: DBSession) {
        SQL("insert into members values (?, ?, ?)").bind(1, "Alice", DateTime.now).update.apply()
        SQL("insert into members values (?, ?, ?)").bind(2, "Bob", DateTime.now).update.apply()
      }
    }

    object MemberSpec extends Specification {
      "Member should ... " in new AutoRollbackWithFixture {
        ...
      }
    }

最後に acceptance スタイルの specs2 の例です。これもカスタマイズの仕方などの要領は unit スタイルと同様ですが case class xxx() extends AutoRollback  { def yyy() = this { ... } } という形式になります。

    import scalikejdbc._
    import scalikejdbc.specs2.AutoRollback
    import org.joda.time.DateTime
    import org.specs2.Specification

    class MemberSpec extends Specification { def is =

      args(sequential = true) ^
      "Member should create a new record" ! autoRollback().create
      end

      case class autoRollback() extends AutoRollback {

        override def db = NamedDB('db2).toDB
        override def fixture(implicit session: DBSession) { ... }

        def create = this {
          val before = Member.count()
          Member.create(3, "Chris")
          Member.count() must_==(before + 1)
        }
      }
    }

## ConnectionPoolContext の紹介

ScalikeJDBC 本体に ConnectionPoolContext という動的に DB の向き先を切り替えることができる機能があります。暗黙のパラメータによって一時的に ConnectionPool の向き先を切り替えることができます。

例えば、以下のメソッドがテスト対象であるとします。

    object Member {
      def countAll()(implicit session: DBSession = AutoSession
        context: ConnectionPoolContext = NoConnectionPoolContext): Long = {
        sql"select count(1) c from members".map(_.long("c")).single.apply.get
      }
    }

　以下の例は、このテストケースだけは共通の DB 接続設定ではなく H2 のメモリ DB を使用するようにしているサンプルです。

    import org.scalatest._
    import org.scalatest.matchers._

    class CPContextWithAutoSessionSpec extends FlatSpec with Matchers with DBSettings {

      behavior of "Member with in-memory DB"

      it should "count all" in {
        Class.forName("org.h2.Driver")
        implicit val context: ConnectionPoolContext = new MultipleConnectionPoolContext(
          ConnectionPoolContext.DEFAULT_NAME -> CommonsConnectionPoolFactory.apply("jdbc:h2:mem:test", "", "")
        )
        // ConnectionPoolContext が有効化されたので
        // これ以降は H2 の memory DB にアクセスする

        DB localTx { implicit session =>
          sql"create table members (id bigint primary key, name varchar(256), created_at timestamp not null);".execute.apply()
          (1 to 1000) foreach { i =>
            SQL("insert into users values (?,?,?)").bind(i, "user%05d".format(i), DateTime.now).update.apply()
          }
        }
        Member.countAll() should equal(1000L)
        // ConnectionPoolContext ここまで
      }
    }

注意点として ConnectionPoolContext を使用するためには、テスト対象のメソッドが暗黙のパラメータとして ConnectionPoolContext を受け取るようになっていなければなりません。そうなっていない場合は暗黙のパラメータに追加する必要があります。


## mapper-generator によるテストの自動生成

次のセクションで詳しく紹介する mapper-generator は、ソースコードの生成時にそれに対応するテストコードも自動生成してくれます。ScalaTest、specs2 からひな形を選択できるので、お好きなテンプレートを指定してください。
