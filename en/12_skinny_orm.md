# 12. Skinny ORM

Skinny ORM is an O/R mapper which built upon ScalikeJDBC. Skinny ORM is a part of Skinny Framework project, a full stack web development framework started in 2013.

Skinny ORM is highly inspired by Ruby on Rails's ActiveRecord library. As with Rails ActiveRecord, you can use the ORM in applications that don't depend on SKinny Framework.

http://skinny-framework.org/documentation/orm.html

There is no barrier when you'd like to directly use ScalikeJDBC API. Using Skinny ORM should meet both demands, reducing boilerplace code and flexibility.

## Adding the dependency

    libraryDependencies ++= Seq(
      "org.skinny-framework" %% "skinny-orm"      % "2.4.+",
      "com.h2database"       %  "h2"              % "1.4.+",
      "ch.qos.logback"       %  "logback-classic" % "1.2.+"
    )

## SkinnyCRUDMapper

SkinnyCRUDMapper is the most common base trait. The trait provides insert/select/update/delete APIs for a single database table.

Not only SkinnyCRUDMapper but other base traits inherit ScalikeJDBC's SQLSyntaxSUpport trait. If you already know hwo to use SQLSyntaxSupport, you should be able to use the trait without learning extra rules.

    import scalikejdbc._
    import skinny.orm._
    import org.joda.time._

    case class Member(id: Long, name: Option[String], createdAt: DateTime)
    object Member extends SkinnyMapper[Member] {
      override lazy val defaultAlias = createAlias("m")
      override def extract(rs: WrappedResultSet, n: ResultName[Member]): Member = autoConstruct(rs, n)
    }

Now, you can use built-in methods as below:

    // Create
    Member.createWithAttributes('name -> "Alice", 'createdAt -> DateTime.now)
    // Read
    val member: Option[Member] = Member.findById(123)
    val members: Seq[Member] = Member.where('name -> "Alice").apply()
    // Update
    Member.updateById(123).withAttributes('name -> "Bob")
    Member.updateBy(sqls.eq(Member.column.name, "Bob")).withAttributes('name -> "Bob")
    // Delete
    Member.deleteById(123)
    Member.deleteBy(sqls.eq(Member.column.name, "Alice"))

Of course, you can use ScalikeJDBC's APIs as well.

    object Member extends SkinnyMapper[Member] {
      override lazy val defaultAlias = createAlias("m")
      override def extract(rs: WrappedResultSet, n: ResultName[Member]): Member = autoConstruct(rs, n)

      def findByName(name: String): Seq[Member] = {
        val m = defaultAlias
        findAllBy {
          // SQLSyntax を渡すと where 句として使ってくれる
          sqls.eq(m.name, name)
            .and
            .isNotNull(m.createdAt)
        }
      }
    }

Skinny ORM provides various features such as association resolution. See the official website for details.

http://skinny-framework.org/documentation/orm.html
