# 3. Connection settings and management

## Using and configuring a connection pool

To use a connection pool, pass a set of JDBC settings to the object called `ConnectionPool`. Please keep in mind that you have to manually call `Class.forName(String)` because JDBC drivers are not loaded automatically.

    import scalikejdbc._
    Class.forName("org.h2.Driver")
    ConnectionPool.singleton("jdbc:h2:mem:db", "username", "password")

This is all you need for the DB connection configuration. After that, you can connect to the database as described below:

    val names: List[String] = DB readOnly { implicit session =>
      sql"select name from members".map(rs => rs.string("name")).list.apply()
    }

You may wonder how the connection settings are used here. The reason is that the `DB.readOnly` internally behaves like this:

    val names: List[String] = using(DB(ConnectionPool.borrow())) { db => 
      db.readOnly { implicit session => 
        sql"select name from members".map(rs => rs.string("name")).list.apply()
      }
    }

`DB.readOnly` is provided for conciseness instead.

## Connecting multiple data sources

When you need to work with multiple data sources, use the `add` method as below. The first argument is where you specify the data source name, whose type is actually `Any` but using a `Symbol` value is conventionally preferred.

    ConnectionPool.add('db1, "jdbc:xxx:db1", "user", "pass")
    ConnectionPool.add('db2, "jdbc:xxx:db2", "user", "pass")

To use them, write as `NamedDB ('db1) readOnly {implicit session =>}` instead of `DB readOnly {implicit session =>}`.

    NamedDB('db1) readOnly { implicit session =>
      // ...
    }
    
    NamedDB('db2) readOnly { implicit session =>
      // ...
    }

The data source created by the `ConnectionPool.singleton(...)` method is named as `'default`. You can not use the same name for other data sources.


## Additional pool settings

Settings other than JDBC url, user name and password are customizable using the `ConnectionPoolSettings`.

    ConnectionPool.singleton("jdbc:h2:mem:db", "", "", 
      new ConnectionPoolSettings(initialSize = 20, maxSize = 50))

Here is the list of the settings:

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
<td>validationQuery</td><td>SQL query to validate connections</td>
</tr>
</table>


## Using a connection pool other than Commons DBCP

`ConnectionPool` uses [Commons DBCP](http://commons.apache.org/dbcp/) as the default implementation of its connection pool. Implementations that version 2.2.0 of ScalikeJDBC offers are: commons-dbcp, commons-dbcp2 and BoneCP.

If you prefer other connection pool implementations, you can do so like this:

    class MyConnectionPoolFactory extends ConnectionPoolFactory {
      def apply(url: String, user: String, password: String, settings: ConnectionPoolSettings) = {
        new MyConnectionPool(url, user, password)
      }
    }
    
    ConnectionPool.add('xxxx, url, user, password)(new MyConnectionPoolFactory)

Furthermore, it's also possible to register connection pools that internally use `DataSource`. The following example shows you how to setup with HikariCP.


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

That's it for the connection management. I will explain transaction management in the next section.



