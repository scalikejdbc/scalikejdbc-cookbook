# 2. クイックツアー

## SQL を実行するサンプル

sbt プロジェクトが準備できたので、早速 ScalikeJDBC で SQL を実行してみましょう。この例では [H2 Database](http://www.h2database.com/) を利用します。

以下のコード例をコピーして sbt console 上で実行してみてください。なお、本書の内容はすべて GitHub のプロジェクトで公開されていますので併せてご参照ください。

[https://github.com/scalikejdbc/scalikejdbc-cookbook](https://github.com/scalikejdbc/scalikejdbc-cookbook)

### コネクションプールの初期化

まずは JDBC ドライバーのロードとコネクションプールの初期化です。

    import scalikejdbc._
    Class.forName("org.h2.Driver")
    ConnectionPool.singleton("jdbc:h2:mem:scalikejdbc","user","pass")

### DDL の実行

まだテーブルがないので以下を実行して members テーブルを作ります。例外が発生しなければテーブル作成に成功しています。

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

### implicit session の意味

ここで「{ implicit session => }」という表記が出てきました。しかも、この session という値はどこにも使われていないように見えるので Scala に慣れていない方は不思議に思われるかもしれません。これについて簡単に説明します。

まず DB.autoCommit［A］(...) は「(DBSession) => A」という型の関数を引数にとるメソッドです。通常はこのようにして呼び出します。

    DB autoCommit { session =>
    }

さらにこの session に implicit をつけると、このブロックの中で implicit val 宣言された暗黙のパラメータ（implicit parameter）と同様の意味になります。つまり、

    DB autoCommit { implicit session =>
    }

は、以下と同義です。

    DB autoCommit { session =>
     implicit val _session: DBSession = session
    }

では、なぜ session が暗黙のパラメータである必要があるかというと DB ブロックの中にあった SQL("...").execute.apply() の apply メソッドが暗黙のパラメータとして DBSession 型を期待するためです。

例えば、以下のように implicit なしで SQL 実行部分を呼び出すとコンパイルエラーが発生します。

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

この apply() メソッドは、実際に SQL を発行して副作用を発生させるメソッドです。そのために DB とのコネクションやセッション状態が必要になるので DBSession 型を暗黙のパラメータとして受け取るようになっています。

Scala の暗黙のパラメータは、カリー化されたメソッドの最後のパラメータリストに implicit 宣言された引数として受け取るものです。この例での最後の apply() メソッドの定義は以下のようなシグネチャになっています。

    def apply()(implicit session: DBSession): Boolean

ちなみに暗黙のパラメータとしての値の名前はそのスコープ内でユニークであれば何でもよく、もっと短く「implicit s => 」のように表記しても問題ありません。本書でもこれ以降は「{ implicit s => }」と表記する場合があります。


### DML の実行

先ほどの create table で例外が発生していなければ、正常にテーブルが作成されているはずです。members テーブルに対して select 文を発行してみましょう。

    val members: List[Map[String, Any]] = DB readOnly { implicit session =>
      SQL("select * from members").map(rs => rs.toMap).list.apply()
    }
    // => members: List[Map[String,Any]] = List()

まだデータがないので空の List が返ってきました。

では、適当に 2 件ほどデータを insert してみましょう。なお、SQL から始まる部分は apply() を呼び出すまでは実際に SQL を発行することはありませんので、以下のように値として何度でも再利用することができます。

    import org.joda.time._
    DB localTx { implicit session =>
      val insertSql = SQL("insert into members (name, birthday, created_at) values (?, ?, ?)")
      val createdAt = DateTime.now
    
      insertSql.bind("Alice", Option(new LocalDate("1980-01-01")), createdAt).update.apply()
      insertSql.bind("Bob", None, createdAt).update.apply()
    }


　ちなみに ScalikeJDBC では上記のような JDBC の通常のテンプレートだけでなく、バインド変数を {name} の形式で埋め込む名前付き SQL テンプレートと、

    SQL("insert into members (name, birthday, created_at) values ({name}, {birthday}, {createdAt})")
      .bindByName('name -> name, 'birthday -> None, 'createdAt -> createdAt)
      .update.apply()

バインド変数名を SQL コメント内に記述してダミー値を添える形式のそのまま実行可能な SQL テンプレートも使用することができます。

    SQL("""
      insert into members (name, birthday, created_at) values (
        /*'name*/'Alice', 
        /*'birthday*/'1980-01-01', 
        /*'createdAt*/current_timestamp
      )
      """)
      .bindByName('name -> name, 'birthday -> None, 'createdAt -> createdAt)
      .update.apply()

これらの詳細は SQL テンプレートに関するセクションで詳しく説明します。

さて、再びサンプルに戻り、もう一度、同じ select 文を発行してみましょう。

    val members: List[Map[String, Any]] = DB readOnly { implicit session =>
      SQL("select * from members").map(_.toMap).list.apply()
    }
    // => members: List[Map[String,Any]] = List(Map(ID -> 1, NAME -> Alice, BIRTHDAY -> 1980-01-01, CREATED_AT -> 2012-12-31 00:02:09.247), Map(ID -> 2, NAME -> Bob, CREATED_AT -> 2012-12-31 00:02:09.247))

想定通り insert した 2 件が返ってきました。先の insert 処理がうまくいったことがわかります。

ここまでの select の例では Map[String, Any] として結果を取得していましたが Member というクラスにマッピングするように書き換えてみます。

ScalikeJDBC では ResultSet からマッピングするクラスに特殊な設定は不要です。単に case class または通常の class として定義するだけで OK です（逆に言えば O/R マッパーのような機能は持っていないということです）。

また、NOT NULL でないカラムは Option 型として定義し、日付やタイムスタンプ型には [Joda Time](http://joda-time.sourceforge.net/) の DateTime、LocalDate を使うことを推奨します。以下のサンプルでその具体例を示します。

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
      createdAt = rs.timestamp("created_at").toDateTime
    )
    
    val members: List[Member] = DB readOnly { implicit session =>
      SQL("select * from members limit 10").map(allColumns).list.apply()
    }
    // => members: List[Member] = List(Member(1,Alice,None,Some(1980-01-01),2012-12-31T00:02:09.247+09:00), Member(2,Bob,None,None,2012-12-31T00:02:09.247+09:00))

### SQL インターポレーション（Scala 2.10）

Scala 2.10.0 から [String Interpolation (SIP-11)](http://docs.scala-lang.org/sips/pending/string-interpolation.html) が導入され、文字列に「${ ... }」で囲んだ式を埋め込むことができるようになりました。

ScalikeJDBC も Scala 2.10 以降では、この機能を活用した「SQL インターポレーション」という拡張機能を提供しています。

1.6.7 時点では Scala 2.9 のサポートを考慮して本体とは別の拡張機能という扱いにしていますが、Scala 2.9 のサポートの考慮が必要でないと判断できるタイミングで本体にマージする方針です。

SQL インターポレーションは scalikejdbc-interpolation という別の jar で提供されていますので忘れずに libraryDependency に追加するようにしてください。

　早速 SQL インターポレーションを使ってみましょう。これまでこのように書いていたものが

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

このように書けるようになります。#bindByName でバインド引数を名前指定していた箇所が不要になり、非常にシンプルになりました。

    import scalikejdbc.SQLInterpolation._

    def create(name: String, birthday: Option[LocalTime])(implicit session: DBSesion): Member = {
      val id = sql"insert into members (name, birthday) values (${name}, ${birthday})"
        .updateAndReturnGeneratedKey.apply()
      Member(id, name, birthday)
    }
    
    def find(id: Long)(implicit session: DBSesion): Option[Member] = {
      sql"select id, name, birthday from members where id = ${id}"
        .map { rs => Member(rs.long("id"), rs.string("name"), rs.timestampOpt("birthday").map(_.toDateTime) }
        .single.apply()
    }


非常に強力なので Scala 2.10 以降ではこちらのスタイルの方を推奨します。なお、本書ではこれ以降の章では基本的に SQL インターポレーションによるコード例を示します。

### QueryDSL

さらに 1.6.0 から新しく QueryDSL という機能が実装されました。これはタイプセーフな SQL ビルダーです。上記の SQL インターポレーションのオブジェクトを生成します。

    import scalikejdbc._, SQLInterpolation._
    
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
          .map { rs => Member(
            id       = rs.long(m.resultName.id), 
            name     = rs.string(m.resultName.name),
            birthday = rs.timestampOpt(m.resultName.birthday).map(_.toDateTime)) 
          }.single.apply()
      }
    }

パッと見では、記述量が増えているように見えますが、文字列を SQL の実行部分で文字列を指定する部分がほとんどなくなりました。

これにより、複雑な join クエリなども DRY に対応できるようになります。ある程度の規模のアプリケーションを開発する場合、QueryDSL を使う方が開発効率は良くなります。

## まとめ

以上、駆け足ですが ScalikeJDBC のクイックツアーでした。まだ説明しきれていない点もありますが ScalikeJDBC の使い方についてイメージを持っていただけたのではないでしょうか。

ScalikeJDBC は暗黙のルールや記号による記述が少なく、初見で何をやっているかわかりやすいという特徴があります。また、使いこなすために覚えることも多くありません。前提知識として必要なのは Scala と JDBC の基礎知識くらいです。

ここではまず ScalikeJDBC で SQL を実行するサンプルを示しました。次のセクション以降で一つ一つの機能についてより詳細な説明をしていきます。


