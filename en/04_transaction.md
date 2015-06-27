# 4. DB blocks and transaction

## Types of DB blocks

There are four types of DB blocks in ScalikeJDBC.

### readOnly

It runs queries in read-only mode. If a non-SELECT statement is issued in this mode, ScalikeJDBC throws a runtime exception.

    val count: Long = DB readOnly { implicit session =>
      sql"select count(1) from members".map(_.long(1)).single.apply().get
    }
    
    // java.sql.SQLException occurs
    DB readOnly { implicit session =>
      sql"update members set name = ${"Alice"} where id = ${1}").update.apply()
    }

For a non-default datasource, it needs to be written as follows:

    val name: Option[String] = NamedDB('legacydb) readOnly { implicit session =>
      sql"select name from members where id = ${"name"}".map(_.string("name")).single.apply()
    }

You can also make a `DBSession` value and use it, although you must explicitly close the resource in that case.

    // Get a read-only session as an implicit DBSession type parameter
    implicit val session: DBSession = DB.readOnlySession
    
    try {
      val names: List[String] = sql"select * from members".map(_.string("name")).list.apply()
    } finally { 
      session.close()
    }

### autoCommit

It runs queries and update operations in auto-commit mode.

    val count = DB autoCommit { implicit session =>
      val updateMembers = SQL("update members set name = ? where id = ?")
    
      updateMembers.bind("Alice", 1).update.apply() // auto-commit
      updateMembers.bind("Bob", 2).update.apply() // auto-commit
    }
    
    NamedDB('yetanother) autoCommit { implicit session =>
      sql"insert into events values (${12345}, ${"Click"}, ${"{'user_id': 345, 'url': 'http://www.example.com/xxx'}"})"
        .update.apply()
    }

Just like `readOnlySession`, there is `autoCommitSession` as well.

    implicit val session: DBSession = DB.autoCommitSession()
    implicit val session: DBSession = NamedDB('yetanother).autoCommitSession()

### localTx

It runs queries and update operations in a single transaction enclosed in the scope of the block. The transaction is automatically rolled back if some exception is thrown from the block.

    val count = DB localTx { implicit session =>
      // start of a transaction
    
      val updateMembers = SQL("update members set name = ? where id = ?")
    
      updateMembers.bind("Alice", 1).update.apply() 
      updateMembers.bind("Bob", 2).update.apply() 
    
      // end of a transaction
    } 
    // rolled back if an exception occurs
    
    NamedDB('yetanother) localTx { implicit session =>
      SQL("insert into events ..").bind(...).update.apply()
    }

Since version 2.2.0, the `TxBoundary` type class allows you to choose transaction boundaries other than through an exception.

    import scalikejdbc._
    import scala.util.Try
    import scalikejdbc.TxBoundary.Try._
   
    // The transaction is rolled back if the Try ends up to be a Failure
    // as well as when an exception is thrown in the localTx block
    val result: Try[Result] = DB localTx { implicit session =>
      Try { doSomeStaff() }
    }

Note that `localTx` cannot be taken out as a `DBSession` because it is a transaction boundary specifier.

### withinTx

It runs queries and update operations within an existing transaction. You are responsible for handling the transaction and manage the datasource by yourself.

    using(DB(ConnectionPool.borrow())) { db =>
      try {
        db.begin() // start of a transaction
    
        val names = DB withinTx { implicit session => 
          // an IllegalStateException is thrown unless a transaction is already started
          sql"select name from members".map(_.string("name")).list.apply()
        }
    
        db.commit() // commit a transaction
      } catch { case e: Exception =>
        db.rollback() // an exception could be thrown
        db.rollbackIfActive() // no exceptions can be thrown
        throw e
      }
    } 

## Transaction management using an automatic session

I will explain how to use the `AutoSession` object and the `NamedAutoSession` class here.

Let's say you have an insert statement such as the following:

    object Member {
      def create(name: String, birthday: Option[LocalDate]): Member = {
        val createdAt = DateTime.now
        val id: Long = DB localTx { implicit session =>
          sql"insert into members (name, birthday, created_at) values (${name}, ${birthday}, ${createdAt})"
            .updateAndReturnGeneratedKey.apply()
        }
        new Member(id = id, name = name, birthday = birthday, createdAt = createdAt)
      }
    }
    
    val alice: Memebr = Member.create("Alice", None)

This will work fine by itself, but the problem is that the transaction is confined in this `create` method.

What that means is that if you write a block like below, the `Member.create` would not be rolled back even when a `NotFoundException` was thrown. This should not be an intended behavior.

    DB localTx { implicit session =>
      val member = Member.create("Alice", None)
      Group.findByName("Japan Scala Users Group") map { group =>
        GroupMember.create(group.id, member.id)
      } orElse {
        throw new NotFoundException
        // Member.create is not rolled back because it's already commit in another transaction
      }
    }

Rewriting the `Member.create` to receive a `DBSession` type as an implicit parameter gets rid of the DB block.

    object Member {
    
      def create(name: String, birthday: Option[LocalDate])(implicit session: DBSession): Member = {
        val createdAt = DateTime.now
        val id: Long = sql"insert into members (name, birthday, created_at) values (${name}, ${birthday}, ${createdAt})"
          .updateAndReturnGeneratedKey.apply()
        new Member(id = id, name = name, birthday = birthday, createdAt = createdAt)
      }
    }

It is now possible to run such methods in a single transaction by implicitly passing a `DBSession` from outside.

    DB localTx { implicit session =>
      val member = Member.create("Alice", None) // handled in the same transaction
      Group.findByName("Japan Scala Users Group") map { group =>
        GroupMember.create(group.id, member.id)
      } orElse {
        throw new NotFoundException
        // Member.create is rolled back
      }
    }

However, we still have a problem. The `Member.create` cannot be called individually any more, but has to be placed within a DB block.

    scala> Member.create("Chris", None)
    <console>:18: error: could not find implicit value for parameter session: scalikejdbc.DBSession
                  Member.create("Chris", None)
                               ^
    
    scala> DB autoCommit { implicit session =>
         |   Member.create("Chris", None)
         | }
    res5: Member = Member(3,Chris,None,None,2012-12-31T11:37:40.349+09:00)

`AutoSession` is a solution to this problem. All you need to do is to further modify the `Member.create` and make `AutoSession` object the default value of the implicit parameter.

    object Member {
    
      def create(name: String, birthday: Option[LocalDate])
        (implicit session: DBSession = AutoSession): Member = {
    
        // same as before
      }
    }

And voilà! You can call the `Member.create` without a DB block.

    scala> Member.create("Chris", None)
    res5: Member = Member(3,Chris,None,None,2012-12-31T11:37:40.349+09:00)

`AutoSession` starts a read-only session for a select statement, and an auto-commit session for update statements. Of course, a `DBSession` passed from outside is used over the `AutoSession` because it's only a default value.

Similarly, `NamedAutoSession(name)` can be used in the case of `NamedDB`.

    def create(name: String)(implicit session: DBSession = NamedAutoSession('another)) = {
      // ...
    }

Mapper-generator, an automatic code generator from a DB which I will explain in a later chapter, generates source code using this `AutoSession`.

That's it for the DB blocks and the transaction management.



