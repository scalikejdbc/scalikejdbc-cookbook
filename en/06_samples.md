# 6. Common Code Samples

In this section, we will show you some common code samples using ScalikeJDBC.

## Select

### Primary Key Search

Retrieving zero or one row is expected when issuing a primary key search query. In the case, it should be natural that we are able to fetch the result as an Option value. ScalikeJDBC provides #single method which returns an Option value. If the rows are more than one, the method throws an exception to represent the situation is unexpected.

    val id = 12345
    val * = (rs: WrappedResultSet) => Member(rs.long("id"), rs.string("name"))
    val member: Option[Member] = DB readOnly { implicit s =>
      sql"select * from members where id = ${id}".map(*).single.apply()
    }

### Count

When you fetch count from a query, you need to call #single method and extract the actual value from the returned Option value by calling Some#get().

    val count: Long = DB readOnly { implicit s =>
      sql"select count(1) from members".map(_.long(1)).single.apply().get()
    }

### Retrieving Multiple Rows

When you get multiple rows from a query, use #list method.

    val members: List[Member] = DB readOnly { implicit s =>
      sql"select * from members limit 10".map(*).list.apply()
    }

For retrieving only the first row from a query result, use #first. Since the result can be empty, the returned value is an Option value.

    val members: Option[Member] = DB readOnly { implicit s =>
      sql"select * from members where group = ${"Engineers"}".map(*).first.apply()
    }

### Working with Huge Result Set

Use #foreach method when you need to avoid the whole result set for a huge result data corresponding to a query and work with each row of them.

    DB readOnly { implicit s =>
      sql"select * from members".foreach { rs =>
        output.write(rs.long("id") + "," + rs.string("name") + "\n")
      }
    }

### in Clause

An SQL object can accept a Seq value in SQLInterpolation.

    val members = DB readOnly { implicit s =>
      val memberIds = List(1, 2, 3)
      sql"select * from members where id in (${memberIds})".map(*).list.apply()
    }

In the former template styles, the library doesn't support in clause in a natural way. If you need to use the legacy ones, build SQL queries as below.

    val members = DB readOnly { implicit s =>
      val * = (rs: WrappedResultSet) => Member(rs.long("id"), rs.string("name"))
      val memberIds = List(1, 2, 3)
      val query = "select * from members where id in (%s)".format(memberIds.map(_ => "?").mkString(","))
      SQL(query).bind(memberIds: _*).map(*).list.apply()
    }

### Join Queries

Writing join queries while using raw SQL statements is hard.

If you already have such existing queries, you might need to respect them.
However, when you start writing new ones, we highly recommend you to use more maintainable way.

In the previous section, we introduced SQLSyntaxSupport. Consider using the feature when you write many join queries.

### Use Java SE8's Date Time API (JSR-310) instead of Joda Time

ScalikeJDBC 2.x continues supporting Java SE 7 users. Thus, scalikejdbc-jsr310, an optional module, is available for users that would like to use JSR-310 APIs. You need to add a new library dependency as below.

    libraryDependencies += "org.scalikejdbc" %% "scalikejdbc-jsr310" % "2.2.+"

You can use the module as below. Just importing `scalikejdbc.jsr310._`.

    import scalikejdbc._, jsr310._
    import java.time._

    case class Group(id: Long, name: Option[String], createdAt: ZonedDateTime)
    object Group extends SQLSyntaxSupport[Group] {
      def apply(g: SyntaxProvider[Group])(rs: WrappedResultSet): Group = apply(g.resultName)(rs)
      def apply(g: ResultName[Group])(rs: WrappedResultSet): Group = Group(rs.get(g.id), rs.get(g.name), rs.get(g.createdAt))
    }

Since version 3.0.0, ScalikeJDBC supports Java SE 8 or higher. `scalikejdbc-jsr310` has been merged into the core library. The APIs are backward-compatible. No need to have `scalikejdbc-jsr310` module and importing `scalikejdbc.jsr310._`.

    import scalikejdbc._
    import java.time._

    case class Group(id: Long, name: Option[String], createdAt: ZonedDateTime)
    object Group extends SQLSyntaxSupport[Group] {
      def apply(g: SyntaxProvider[Group])(rs: WrappedResultSet): Group = apply(g.resultName)(rs)
      def apply(g: ResultName[Group])(rs: WrappedResultSet): Group = Group(rs.get(g.id), rs.get(g.name), rs.get(g.createdAt))
    }

## Insert

ScalikeJDBC embraces Option values as bind parameters in SQL statements to deal with nullable values. ScalikeJDBC highly recommends using Joda Time's DateTime/LocalDate, and the standard Date Time API in Java SE 8 instead of the types under java.sql.\* package. You can use the values in the types as bind parameters.

    DB autoCommit { implicit s =>
      val (name, memo, createdAt) = ("Alice", Some("Wonderland"), org.joda.DateTime.now)
      sql"insert into members values (${name}, ${memo}, ${createdAt})"
        .update.apply()
    }

If a type is not supported by the library, the value as a java.lang.Object value will be passed to the JDBC driver. If that's not ok for you, you can fix the situation by using ParameterBinder.

    val bytes = Array[Byte](1,2,3, ...)
    val in = ByteArrayInputStream(bytes)
    val bin = ParameterBinder(
      value = in,
      binder = (stmt, idx) => stmt.setBinaryStream(idx, in, bytes.length)
    )
    sql"insert into table (bin) values (${bin})".update.apply()

### Retrieving auto-increment id value

To fetch auto-increment PK value, use #updateAndReturnGeneratedKey. The auto-increment PK value is returned as a Long value.

    val id = DB localTx { implicit s =>
      val (name, createdAt) = ("Alice", org.joda.DateTime.now)
      sql"insert into members values (${name}, ${createdAt})"
        .updateAndReturnGeneratedKey.apply()
    }
    val createdMember = Member(id = id, name = name, createdAt = createdAt)

## Update

Same as the Insert code, use #update.

    val (name, newName) = ("Bob", "Bobby")
    DB localTx { implicit s =>
      sql"update members set name = ${newName} where name = ${name}"
        .update.apply()
    }

## Delete

Same as the Insert code, use #update.

    val id = 1234
    DB localTx { implicit s =>
      sql"delete from members where id = ${id}".update.apply()
    }

## Batch

For a batch operations, use #batch, #batchByName with a list of a set of bind parameters corresponding to the statement. When you are working on above a certain number of rows, using batch APIs should improve the performance of the code. We recommend you using the APIs for bulk updates.

`batch` is a method to pass a list of `Seq[Any]` value corresponding to an SQL template.

    val params: Seq[Seq[Any]] = (1 to 1000).map(i => Seq(i, "user_" + i))
    SQL("insert into members values (?, ?)").batch(params: _*).apply()

`batchByName` is a method to pass a list of `Seq[(Symbol, Any)]` value corresponding to an SQL template.

    val params: Seq[Seq[(Symbol, Any)]] = (1 to 1000).map(i => Seq('id -> i, 'name -> "user_" + i))
    SQL("insert into members values ({id}, {name})").batchByName(params: _*).apply()
