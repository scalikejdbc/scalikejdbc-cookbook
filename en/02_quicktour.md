# 2. A Quick Tour

## Sample for running SQL

Since we have the sbt project set up, we are ready to run SQL using ScalikeJDBC. In this example I will use the [H2 Database](http://www.h2database.com/).

Try running on the sbt console by copying the following code examples. Please note that the content of this book is available on GitHub, which you can also refer to;

[Https://github.com/scalikejdbc/scalikejdbc-cookbook](https://github.com/scalikejdbc/scalikejdbc-cookbook)

### Initializing a connection pool

Firstly, here is how to load the JDBC driver and initialize a connection pool.

    import scalikejdbc._
    Class.forName("org.h2.Driver")
    ConnectionPool.singleton("jdbc:h2:mem:scalikejdbc","user","pass")

### Executing DDL

We don't have a table yet, so create a `members` table by running the following. If no exception occurs, we have successfully created a table.

    DB autoCommit { implicit session =>
      SQL("""
        create table members (
          id bigint primary key auto_increment,
          name varchar(30) not null,
          description varchar(1000),
          birthday date,
          created_at timestamp not null
        )
      """).execute.apply()
    }

### Meaning of implicit session

Here we saw something like `{implicit session => }`. This might confuse some of you who are not familiar with Scala because the variable `session` does not seem to be used anywhere else. I will briefly explain this.

Firstly, `DB.autoCommit[A](...)` is a method that takes a function of type `(DBSession) => A` as its argument. It's normally called in this manner;

    DB autoCommit { session =>
    }

Secondly, if we add `implicit` to the `session`, it becomes an implicit parameter just like a variable declared as `implicit val` in this scope. That is to say, this piece of code;

    DB autoCommit { implicit session =>
    }

is equivalent to the following;

    DB autoCommit { session =>
     implicit val _session: DBSession = session
    }

So why did `session` have to be an implicit paramter? That's because the `apply` method as in `SQL("...").execute.apply()` we saw in the DB block implicitly expects a `DBSession` type parameter.

Instead, a compile-time error occurs if you call the SQL execution part without the `implicit` like this;

    scala> DB autoCommit { session =>
         |   SQL("""
         |     create table members (
         |       id bigint primary key auto_increment,
         |       name varchar(30) not null,
         |       description varchar(1000),
         |       birthday date,
         |       created_at timestamp not null
         |     )
         |   """).execute.apply()
         | }
    <console>:20: error: could not find implicit value for parameter session: scalikejdbc.DBSession
      """).execute.apply()
                        ^

This `apply()` method is a method to actually issue an SQL and cause side effects. It, therefore, needs a connection and session state of the DB by the `DBSession` type implicit parameter.

Implicit parameters in Scala are passed as the last parameter list of a curried method. The definition of the `apply()` method in this example has a signature such as the following;

    def apply()(implicit session: DBSession): Boolean

By the way, you can name the implicit parameter freely as long as it is unique in its scope, so there is no problem to write it simply as `implicit s =>`. From this point in this book, I may also write as `{implicit s =>}`.


### Executing DML

If no exception occured in the previous `create table`, a table should have been created already. Let's issue a `select` statement to the `members` table.

    val members: List[Map[String, Any]] = DB readOnly { implicit session =>
      SQL("select * from members").map(rs => rs.toMap).list.apply()
    }
    // => members: List[Map[String,Any]] = List()

An empty `List` have been returned because there are still no data.

Now, let's try to insert some records. Since the part that starts with `SQL` does not actually issue the SQL until you call the `apply()`, you can re-use it as many times as you like, such as;

    import org.joda.time._
    DB localTx { implicit session =>
      val insertSql = SQL("insert into members (name, birthday, created_at) values (?, ?, ?)")
      val createdAt = DateTime.now
    
      insertSql.bind("Alice", Option(new LocalDate("1980-01-01")), createdAt).update.apply()
      insertSql.bind("Bob", None, createdAt).update.apply()
    }


By the way, ScalikeJDBC allows you to use not only the normal JDBC template shown above, but also the named SQL template where you embed binding variables as `{name}`;

    SQL("insert into members (name, birthday, created_at) values ({name}, {birthday}, {createdAt})")
      .bindByName('name -> name, 'birthday -> None, 'createdAt -> createdAt)
      .update.apply()

as well as the executable template where you write binding variables in the comments accompanied by dummy values;

    SQL("""
      insert into members (name, birthday, created_at) values (
        /*'name*/'Alice', 
        /*'birthday*/'1980-01-01', 
        /*'createdAt*/current_timestamp
      )
      """)
      .bindByName('name -> name, 'birthday -> None, 'createdAt -> createdAt)
      .update.apply()

This is explained in more detail at the SQL template section in detail.

Let's return to the example and issue the same `select` statement once again.

    val members: List[Map[String, Any]] = DB readOnly { implicit session =>
      SQL("select * from members").map(_.toMap).list.apply()
    }
    // => members: List[Map[String,Any]] = List(Map(ID -> 1, NAME -> Alice, BIRTHDAY -> 1980-01-01, CREATED_AT -> 2012-12-31 00:02:09.247), Map(ID -> 2, NAME -> Bob, CREATED_AT -> 2012-12-31 00:02:09.247))

The two records that was inserted has been returned as expected. You find that the previous `insert` was processed successfully.

Previously in the `select` examples, we obtained our results as `Map[String, Any]`, but let's change it so that the results are mapped to a `Member` class.

ScalikeJDBC doesn't require you to do any special configuration to the class mapped from `ResultSet`. It is OK to simply define it as a `case class` or just as a regular `class`.

It is recommended to define `NOT NULL` columns as `Option` types and use DateTime and LocalDate from [Joda Time](http://www.joda.org/joda-time/) for date and timestamp columns. The Date Time API of Java SE 8 can be used as well, but I will explain it separately. In this sample, I will show you an example of using Joda Time.

    case class Member(
      id: Long, 
      name: String, 
      description: Option[String] = None, 
      birthday: Option[LocalDate] = None, 
      createdAt: DateTime)
    
    val allColumns = (rs: WrappedResultSet) => Member(
      id = rs.long("id"), 
      name = rs.string("name"), 
      description = rs.stringOpt("description"),
      birthday = rs.dateOpt("birthday").map(_.toLocalDate), 
      createdAt = rs.jodaDateTime("created_at")
    )
    
    val members: List[Member] = DB readOnly { implicit session =>
      SQL("select * from members limit 10").map(allColumns).list.apply()
    }
    // => members: List[Member] = List(Member(1,Alice,None,Some(1980-01-01),2012-12-31T00:02:09.247+09:00), Member(2,Bob,None,None,2012-12-31T00:02:09.247+09:00))

### SQL Interpolation

Since [String Interpolation (SIP-11)](http://docs.scala-lang.org/sips/pending/string-interpolation.html) was introduced to Scala 2.10.0, you can embed expressions to strings by `${...}`.

ScalikeJDBC offers an extension called "SQL interpolation" which takes advantage of this feature.

While there is a risk of causing an SQL injection vulnerability in misuse of `SQL("...")`, you don't have a worry of its happening with `sql"..."` because all external inputs become binding variables.

So let's try the SQL interpolation. Instead of writing like this as previously seen;

    def create(name: String, birthday: Option[LocalTime])(implicit session: DBSesion): Member = {
      val id = SQL("insert into members (name, birthday) values ({name}, {birthday})")
        .bindByName('name -> name, 'birthday -> birthday)
        .updateAndReturnGeneratedKey.apply()
      Member(id, name, birthday)
    }

    def find(id: Long)(implicit session: DBSesion): Option[Member] = {
      SQL("select id, name, birthday from members where id = {id}")
        .bindByName('id -> id)
        .map { rs => Member(rs.long("id"), rs.string("name"), rs.timestampOpt("birthday").map(_.toDateTime) }
        .single.apply()
    }

we can write it as below. Notice that it has also become simpler as passing binding variables by `#bindByName` being no longer there.

    def create(name: String, birthday: Option[LocalTime])(implicit session: DBSesion): Member = {
      val id = sql"insert into members (name, birthday) values (${name}, ${birthday})"
        .updateAndReturnGeneratedKey.apply()
      Member(id, name, birthday)
    }
    
    def find(id: Long)(implicit session: DBSesion): Option[Member] = {
      sql"select id, name, birthday from members where id = ${id}"
        .map { rs => 
          new Member(
            id       = rs.long("id"), 
            name     = rs.string("name"), 
            birthday = rs.timestampOpt("birthday").map(_.toDateTime) 
          )
        }
        .single.apply()
    }


In the current ScalikeJDBC, the latter is the more recommended style over the direct use of `SQL("...")`. Subsequent chapters in this book basically shows code examples using SQL interpolation.

### QueryDSL

QueryDSL is a feature that was added in 1.6.0 which also should not be forgotten. This is a type-safe SQL builder. It will create an object of the above SQL interpolation.

    import scalikejdbc._
    
    case class Member(id: Long, name: String, birthday: Option[LocalTime] = None)
    object Member extends SQLSyntaxSupport[Member] {
      override tableName = "members"
      override columnNames = Seq("id", "name", "birthday")
      
      def create(name: String, birthday: Option[LocalTime])(implicit session: DBSesion): Member = {
        val id = withSQL { 
          insert.into(Member).namedValues(
            column.name -> name,
            column.birthday -> birthday
          )
        }.updateAndReturnGeneratedKey.apply()
        Member(id, name, birthday)
      }
      
      def find(id: Long)(implicit session: DBSesion): Option[Member] = {
        val m = Member.syntax("m")
        withSQL { select.from(Member as m).where.eq(m.id, id) }
          .map { rs => 
            new Member(
              // rs.get[Long] can be used with type inference instead of writing rs.long
              id       = rs.get(m.resultName.id), 
              name     = rs.get(m.resultName.name),
              birthday = rs.get(m.resultName.birthday)
            ) 
          }.single.apply()
      }
    }

In a glance, it looks like we have more code, but we have gotten rid of most of the parts where SQL were executed by strings.

As a result, even a complex query, for example using joins, can become more DRY. If you develop a certain scale of applications, QueryDSL will enhance development efficiency.

### Auto Macros

http://scalikejdbc.org/documentation/auto-macros.html

If you go even further, by using scalikejdbc-syntax-support-macro;

    libraryDendencies += "org.scalikejdbc" %% "scalikejdbc-syntax-support-macro" % "2.2.+"

you can write yet more concisely with the `autoConstruct` method as below;

    def extract(rs: WrappedResultSet, m: ResultName[Member]): Member = autoConstruct(rs, rn)
    
    def find(id: Long)(implicit session: DBSesion): Option[Member] = {
      val m = Member.syntax("m")
      withSQL { select.from(Member as m).where.eq(m.id, id) }
        .map(rs => extract(rs, m))
        .single.apply()
    }

This way you can reduce boiler plate code.

## Conclusion

That's it for a quick tour of ScalikeJDBC. I hope you got an image of how to use the library, although there are parts I could not cover.

With its few implicit rules and symbolic descriptions, ScalikeJDBC makes it easy to understand by a first look. Also, it does not require many things to learn in order to master. What is needed as a prerequisite is a basic knowledge of Scala and JDBC.

Here I showed a sample to run SQL with ScalikeJDBC. I will go on with more detailed explanations about each of the features in the following sections.


