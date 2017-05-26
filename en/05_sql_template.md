# 5. Four patterns of SQL templates

ScalikeJDBC supports the following four patterns of SQL templates. Although SQL interpolation and QuerySQL are currently recommended, you can choose the others depending on your needs.

## JDBC SQL template

This is the normal JDBC SQL template. Placeholders are expressed as `?` and bind parameters are passed by `#bind(...)` in order.

    val now = DateTime.now
    SQL("""
      insert into members (id, name, memo, created_at, updated_at)
      values (?, ?, ?, ?, ?)
      """)
      .bind(123, "Alice", None, now, now)

## Named SQL template

In this pattern, you specify named placeholders in the form of `{name}` and pass bind parameters as `(Symbol -> Any)` to `#bindByName(...)` with no specific order.

    SQL("""
      insert into members (id, name, memo, created_at, updated_at) 
      values ({id}, {name}, {memo}, {now}, {now})
      """)
      .bindByName(
        'id -> 123,
        'name -> "Alice",
        'memo -> None,
        'now -> DateTime.now
      )

## Executable SQL template

This is just like the named SQL template, but you specify named placeholders as `/*'name*/dummy_value`; a named bind parameter with Scala's symbol literal in an SQL comment immediately followed by a dummy value. The advantage of this pattern is that the SQL template is executable by itself. This was implemented drawing from what is known as 2-Way SQL in Japan, but there is no support for complex syntax like conditional branch.

    SQL("""
      insert into members (id, name, memo, created_at, updated_at) values (
        /*'id*/12345,
        /*'name*/'Alice',
        /*'memo*/'memo',
        /*'now*/'2001-01-02 00:00:00',
        /*'now*/'2001-01-02 00:00:00')
      """)
      .bindByName(
        'id -> 123,
        'name -> "Alice",
        'memo -> None,
        'now -> DateTime.now
      )


## SQL interpolation

SQL interpolation makes use of SIP-11 String Interpolation as of Scala 2.10.

You can embed parameters as `${expression}`.

    val now = DateTime.now
    sql"""
      insert into members (id, name, memo, created_at, updated_at) values
      (${123}, ${"Alice"}, ${None}, ${now}, ${now})
    """.update.apply()

### SQLSyntax and other types

When SQLSyntax type values are passed, such parts are not expanded as bind parameters but directly embedded into the SQL.

In order to avoid SQL injection vulnerability, an SQLSyntax instance can only be created through `sqls"..."`.

Therefore, this statement;

    val ordering: SQLSyntax = if (isDesc) sqls"desc" else sqls"asc" // or SQLSyntax("desc")
    val id: Int = 1234

    val names = sql"select name from member where id = ${id} order by id ${ordering}"
                  .map(rs => rs.long("name")).list.apply()

is expanded as the following SQL.

    select name from member where id = ? order by id desc

Also, `Seq` type is expanded as a comma separated list of values, i.e. this statement;

    val ids = Seq(1, 2, 3)
    val names = sql"select name from member where id in (${ids})"
                  .map(rs => rs.long("name")).list.apply()

is expanded as the following.

    select name from member where id in (?, ?, ?)

This is as much as you need to remember about templating with SQL interpolation.

### SQLSyntaxSupport

SQLSyntaxSupport is a trait that allows you to deal with SQL interpolation involving a join query more efficiently.

Let's look at this example.

    case class Member(id: Long, teamId: Long)
    case class Team(id: Long, name: String)

    val membersWithTeam: List[(Member, Team)] = sql"""
      select m.id as m_id, m.team_id as m_tid, t.id as t_id, t.name as t_name
      from member m inner join team t on m.team_id = t.id
    """
      .map(rs => (Member(rs.long("m_id"), rs.long("m_tid")), Team(rs.long("t_id"), rs.string("t_name"))))
      .list.apply()

To rewrite this by using SQLSyntaxSupport, prepare some definitions;

    case class Member(id: Long, teamId: Long)
    case class Team(id: Long, name: String)

    object Member extends SQLSyntaxSupport[Member] {
      def apply(m: ResultName[Member])(implicit rs: WrappedResultSet): Member = {
        new Member(id = rs.long(m.id), teamId = rs.long(m.teamId))
      }
    }
    object Team extends SQLSyntaxSupport[Team] {
      def apply(t: ResultName[Team])(implicit rs: WrappedResultSet): Team = {
        new Team(id = rs.long(t.id), name = rs.string(t.name))
      }
    }

The query part can then be written as follows;

    val (m, t) = (Member.syntax("m"), Team.syntax("t"))
    val membersWithTeam: List[(Member, Team)] = sql"""
      select ${m.result.*}, ${t.result.*}
      from ${Member.as(m)} inner join ${Team.as(t)} on ${m.teamId} = ${t.id}
    """
      .map(implicit rs => (Member(m.resultName), Team(t.resultName)))
      .list.apply()

`#syntax(String)` returns a SyntaxProvider, which can be cached and reused because they are thread safe. SyntaxProvider is expanded into SQLSyntax with field names of the class passed as the type parameter.

You may find it vaguely similar to JPQL if you know about it. Unlike JPQL, however, there is no custom syntax apart from SQL because the embedded fields are all checked at compile time, and they are just expanded into strings.

These are the only rules to remember.

- `m.teamId` becomes `m.team_id`
- `m.result.teamId` becomes `m.team_id as ti_on_m`
- `m.resultName.teamId` becomes `ti_on_m`

Therefore the above generates the following SQL;

    select m.id as i_on_m, m.team_id as ti_on_m, t.id as i_on_t, t.name as n_on_t
    from member as m inner join team as t on m.team_id = t.id

You might think that the code size has increased with definitions of companion objects, but on the other hand the gains are;

- type safety by getting rid of string manipulation
- mapping defined by the `apply` can be reused for other join queries

I hope you will find it useful once you use this feature.

If you want to avoid writing this boilerplate `apply` method again and again, you can use the scalikejdbc-syntax-support-macro which I mentioned in the Quick Tour.

http://scalikejdbc.org/documentation/auto-macros.html

By default, table names are derived from companion objects (eg. `TeamMember` -> `team_member`) and column names are taken from JDBC's meta data at their first access and cached.

Those can be customized by writing as follows;

    object TeamMember {
      override val tableName = "team_members"
      override val columnNames = Seq("id", "name")
    }

Conversion of field names into snake-case column names is done in the same fashion as table names, which can also be customized;

    case class TeamMember(id: Long, createdAt: DateTime)
    object TeamMember {
      override val columnNames = Seq("id", "name", "created_timestamp")
      override val nameConverters = Map("^createdAt$" -> "created_timestamp")
      // or "At$" -> "_timestamp"
    }


### QueryDSL

QueryDSL is a type safe query builder DSL that can generate `sql"..."` efficiently.

The previous example;

    sql"""
      insert into members (id, name, memo, created_at, updated_at) values
      (${123}, ${"Alice"}, ${None}, ${now}, ${now})
    """.update.apply()

can be rewritten as below (a Member object extending SQLSyntaxSupport needs to be defined);

    object Member extends SQLSyntaxSupport[Member] {

      def insert(id: Long, name: String, memo: Option[String]) = DB.localTx { implicit s =>
        val now = DateTime.now
        withSQL {
          insert.into(Member)
            .columns(column.id, column.name, column.memo, column.createdAt, column.updatedAt)
            .values(id, name, memo, now, now)
        }.update.apply()
      }
    }

    val ordering: SQLSyntax = if (isDesc) sqls"desc" else sqls"asc" // or SQLSyntax("desc")
    val id: Int = 1234

    val m = Member.syntax("m")
    val names = select(m.name).from(Member as m).where.eq(m.id, id).orderBy(m.id).append(ordering)
      .map(rs => rs.long(m.name)).list.apply()

## Summary

You can choose from the four patterns of SQL templates supported by ScalikeJDBC depending on your needs. I, however, recommend using SQL interpolation considering convenience, security and future improvements.
