# 5. 4 種類の SQL テンプレート

　ScalikeJDBC では以下の 4 種類の SQL テンプレートをサポートしています。

## JDBC の SQL テンプレート　

　JDBC の通常のテンプレートです。プレースホルダは「?」で表現され、バインド変数は #bind(...) で順序通り渡されます。

```
val now = DateTime.now
SQL("""
  insert into members (id, name, memo, created_at, updated_at) 
  values (?, ?, ?, ?, ?)
  """)
  .bind(123, "Alice", None, now, now)
```

## 名前付き SQL テンプレート

　名前付きプレースホルダを「{name}」の名前付きの形式で指定し、バインド変数は #bindByName(...) で (Symbol -> Any) を順不同で指定します。これは Play! Framework で提供されている Anorm という DB アクセスライブラリと同様の仕様です。

```
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
```

## 実行可能な SQL テンプレート

　名前付きプレースホルダを「/＊'name＊/dummy_value」の形式で指定し、バインド変数は #bindByName(...) で (Symbol -> Any) を順不同で指定します。この SQL テンプレートがそのまま SQL として実行可能であるという利点があります。

　バインド変数の名前を SQL コメント内に Scala のシンボルリテラルで指定し、そのすぐ後にダミー値を添えます。日本で 2 Way SQL と呼ばれるものから着想して実装したものですが、2 Way SQL が備える条件分岐のシンタックスなどはサポートしていません。

```
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
```


## SQL インターポレーション

　Scala 2.10.0 から使えるようになった SIP-11 String Interpolation による新しい SQL テンプレートです。

　1.4.3 時点では Scala 2.9.x サポート継続のために拡張機能として別の jar になっています。sbt の設定に以下を追加してください。読者が既に Scala 2.10.0 以降を使用している場合は scalaVersion の指定は不要です。

```
scalaVersion := "2.10.0"

libraryDependencies += "com.github.seratch" %% "scalikejdbc-interpolation" % "[1.4,)",
```

　「${expression}」でパラメータとして式を埋め込みます。

```
val now = DateTime.now
SQL("""
  insert into members (id, name, memo, created_at, updated_at) values (
    ${123}, ${"Alice"}, ${None}, ${now}, ${now})
```

　注意点としては Scala 2.10.0 時点で String Interpolation は Scala の Tuple が 22 までしかない問題の影響を受けてしまいます。つまり、埋め込む式が 23 個以上の場合は使うことができません。今後の Scala の改善によって解決することが期待されます。


　以上、計 4 種類の SQL テンプレートをサポートしていますが、基本的には用途に分けて使い分けていただくのがよいかと思います。

　筆者としては Scala 2.10 以降であれば SQL インターポレーション、Scala 2.9 であれば名前付きの SQL テンプレートをベースに利用されるのが良いのではないかと思います。


