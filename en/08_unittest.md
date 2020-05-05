# 8. Unit Testing

In this section, we will show you test code samples using ScalikeJDBC's testing support.

## scalikejdbc-test

scalikejdbc-test is a sub project which provides supports for both of ScalaTest and specs2. The feature is supported since ScalikeJDBC version 1.4.2.

    val appDependencies = Seq(
      "org.scalikejdbc"   %% "scalikejdbc"      % "3.2.+",
      "org.scalikejdbc"   %% "scalikejdbc-test" % "3.2.+"   % "test",
      "org.scalatest"     %% "scalatest"        % "3.0.+"   % "test",
      "org.specs2"        %% "specs2-core"      % "3.8.9"   % "test"
    )

## How to configure the database connectivity

Preparing a trait which set up a ConnectionPool and mixing in the trait is a good way to configure. Even if you have multilpe data sources, you can use `ConnectionPool.add(...)`.

    trait TestDBSettings {

      def loadJDBCSettings() {
        // https://github.com/typesafehub/config
        val config = ConfigFactory.load()
        val url = config.getString("jdbc.url")
        val user = config.getString("jdbc.username")
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

Of course, if you would like to use the settings came from some Web frameworks or similar (e.g. Play Framework), it would be smooth to follow the way of them.

If you use Typesafe Config:

[https://github.com/typesafehub/config](https://github.com/typesafehub/config)

You can use scalikejdbc-config.

[https://github.com/scalikejdbc/scalikejdbc/tree/master/scalikejdbc-config](https://github.com/scalikejdbc/scalikejdbc/tree/master/scalikejdbc-config)

Play's configuration uses Typesafe Config library. When the configuration is defined in `application.conf`:

    db.default.url="jdbc:h2:mem:sample1"
    db.default.driver="org.h2.Driver"
    db.default.username="sa"
    db.default.password="secret"

You can easily load the settings while initializing the code.

    import scalikejdbc.config._
    DBs.setup()

To load multiple configurations:

    db.foo.url="jdbc:h2:mem:sample2"
    db.foo.driver="org.h2.Driver"
    db.foo.username="sa"
    db.foo.password="secret"

    db.bar.url="jdbc:h2:mem:sample2"
    db.bar.driver="org.h2.Driver"
    db.bar.username="sa2"
    db.bar.password="secret2"

Call `DBs.setupAll`.

    import scalikejdbc.config._
    DBs.setupAll()


## Automatic Rollback and Fixture Support

ScalikeJDBC provides traits to support automatic roll back after completing tests for both of ScalaTest and specs2.

First, here is a sample for ScalaTest users. Using base traits under `org.scalatest.fixture` package and a scalikejdbc-test's trait together, you can easily use automatic rollback and data fixture per a test case.

If you need only automatic rollback, mixin the AutoRollback trait and accept a DBSession as an argument of each test code  block. Passing the implicit parameter to the method to be tested propagates the same session. Of course, the method must accept a DBSession as an implicit parameter. Doing that eventually enables you using the same transaction and rolling back the transaction after running the test.

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

When connecting the other data sources, override #db() method to switch the data source to connect.

    class MemberSpec extends FlatSpec with Matchers with AutoRollback {

      override def db = NamedDB('db2).toDB

      behavior of "Member"

      ...
    }

When you need a fixture feature, override #fixture(DBSession) method. The rows created by the method should also be rolled back after running tests.

    class MemberSpec extends FlatSpec with Matchers with AutoRollback {

      override def fixture(implicit session: DBSession) {
        SQL("insert into members values (?, ?)").bind(123, "test_user_123").update.apply()
        SQL("insert into members values (?, ?)").bind(234, "test_user_234").update.apply()
        SQL("insert into members values (?, ?)").bind(345, "test_user_345").update.apply()
      }

      behavior of "Member"

      ...
    }

Next, here is a sample using specs2 in specs2's unit style. Unlike ScalaTest, you need to specify `new AutoRollback { ... }` inside each test case's `in` block.

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

Here is the way to connect another data source. Unlike ScalaTest, it's possible to specify per each test case. That might be useful than ScalaTest's one.

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

Lastly, this is a specs2 sample in specs2's acceptance style. The way to customize or configure is basically same as specs2 unit style except defining a case class in a bit irregular style which doesn't have no arg constructor, like `case class xxx() extends AutoRollback  { def yyy() = this { ... } }`.

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

## ConnectionPoolContext

ConnectionPoolContext allows you to dynamically switch the database connection at runtime. You can use it as an implicit parameter.

Let's think you're going to write some tests for the following method.

    object Member {
      def countAll()(implicit session: DBSession = AutoSession
        context: ConnectionPoolContext = NoConnectionPoolContext): Long = {
        sql"select count(1) c from members".map(_.long("c")).single.apply.get
      }
    }

The following test code is a sample which enable using H2's in-memory database instead only in the test case.

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

Note that the target method (the #countAll method in the above case) must accept ConnectionPoolContext as an implicit parameter when you use the feature.

## Code generation by mapper-generator

The mapper-generator introduced in the next section generates the source code from an existing database table. At the same time, the generator also generates test code corresponding to the generated code. Several templates for ScalaTest and specs2 are available. You can specify the favorite one.
