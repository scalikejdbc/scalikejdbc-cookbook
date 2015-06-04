# 3. Connection settings and management

## Using and configuring a connection pool

To use a connection pool, pass a set of JDBC settings to an object called `ConnectionPool`. `Class.forName(String)` needs to be called because the JDBC driver is not loaded automatically.

    import scalikejdbc._
    Class.forName("org.h2.Driver")
    ConnectionPool.singleton("jdbc:h2:mem:db", "username", "password")

This is all you need for the DB connection configuration. Once the above has been run, you can connect to the DB:

    val names: List[String] = DB readOnly { implicit session =>
      sql"select name from members".map(rs => rs.string("name")).list.apply()
    }

The reason why the connection settings are applied here is because the `DB.readOnly` internally behaves like this:

    val names: List[String] = using(DB(ConnectionPool.borrow())) { db => 
      db.readOnly { implicit session => 
        sql"select name from members".map(rs => rs.string("name")).list.apply()
      }
    }

As you can see, `DB.readOnly` can save you from writing such a verbose code every time.

## Connecting multiple data sources

Below is an example of how to cope with the needs for connecting multiple data sources from a single application using ScalikeJDBC. The name of a data source must be specified in the first argument of the `add` method, whose type is actually `Any` but it is highly recommended to use a `Symbol`.

    ConnectionPool.add('db1, "jdbc:xxx:db1", "user", "pass")
    ConnectionPool.add('db2, "jdbc:xxx:db2", "user", "pass")

To use them, write as `NamedDB ('db1) readOnly {implicit session =>}` instead of `DB readOnly {implicit session =>}`.

    NamedDB('db1) readOnly { implicit session =>
      // ...
    }
    
    NamedDB('db2) readOnly { implicit session =>
      // ...
    }

The data source created by the `ConnectionPool.singleton(...)` method earlier has the name `'default`. This name can not be used for other data sources.


## Optional settings

Settings other than JDBC url, user name and password are customizable using the `ConnectionPoolSettings`.

    ConnectionPool.singleton("jdbc:h2:mem:db", "", "", 
      new ConnectionPoolSettings(initialSize = 20, maxSize = 50))

Here are the list of those settings:

<table>
<tr>
<td>Key</td><td>Content</td>
</tr>
<tr>
<td>initialSize</td><td>Minimum number of connections to be pooled</td>
</tr>
<tr>
<td>maxSize</td><td>Maximum number of connections to be pooled</td>
</tr>
<tr>
<td>validationQuery</td><td>SQL query to check to be connected</td>
</tr>
</table>


## Using a connection pool other than Commons DBCP

The `ConnectionPool` method chooses [Commons DBCP](http://commons.apache.org/dbcp/) as the default implementation of the connection pool. Implementations that version 2.2.0 of ScalikeJDBC offers are: commons-dbcp, commons-dbcp2 and BoneCP.

If you prefer other connection pool implementations, you can do so like this:

    class MyConnectionPoolFactory extends ConnectionPoolFactory {
      def apply(url: String, user: String, password: String, settings: ConnectionPoolSettings) = {
        new MyConnectionPool(url, user, password)
      }
    }
    
    ConnectionPool.add('xxxx, url, user, password)(new MyConnectionPoolFactory)

You can also register the connection pool to be used through `DataSource`. The following is an example of using HikariCP.


http://brettwooldridge.github.io/HikariCP/

    val dataSource: DataSource = {
      val ds = new HikariDataSource()
      ds.setDataSourceClassName(dataSourceClassName)
      ds.addDataSourceProperty("url", url)
      ds.addDataSourceProperty("user", user)
      ds.addDataSourceProperty("password", password)
      ds
    }
    ConnectionPool.singleton(new DataSourceConnectionPool(dataSource))

## A thread-local connection

You can reuse an instance of the DB class, which holds `java.sql.Connection`, as a thread local value. As long as you use a single DB instance, the same connection will be reused.

    def init() = {
      val newDB = ThreadLocalDB.create(conn)
      newDB.begin()
    }
    // after `init` is called
    def action() = {
      val db = ThreadLocalDB.load()
      db readOnly { implicit session =>
        // ...
      }
    }
    def finalize() = {
      try { ThreadLocalDB.load().close() } catch { case e: Exception => }
    }

That's it for the connection management. We will explain in the next section for transaction management.



