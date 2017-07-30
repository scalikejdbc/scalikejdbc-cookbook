# 13. Future with You

We started the ScalikeJDBC project in November 2011. Many companies and projects use the library now, but we understand there is still some rooms to improve. 
We take backward compatibility and stability for existing users seriously. Meanwhile, we will follow Scala language's evolution and make the library edge.

As you know, ScalikeJDBC is an open source software project. Not only core maintainers but all developers who are interested in ScalieJDBC can make the library better than ever.

Let me tell us about a portion of infomration you should know when you contribute to the library.


## License

Apache License, Version 2.0

[http://www.apache.org/licenses/LICENSE-2.0.html](http://www.apache.org/licenses/LICENSE-2.0.html)


## Versioning Policy

The ScalikeJDBC's versioning policy is:

"3.{major version}.{minor version}"

We basically don't apply drastic changes, but major version upgrade contains some breaking changes.
For instance, removal of classes and methods already marked as deprecated beforehand, changes on method signatures. When we need to introduce breaking changes, we must announce them in advance and provide release candidate versions.
The binary compatibility is not guaranteed among major versions.

About minor versions, we adds only bug fixes and minor/internal changes. You can upgrade more safely than major upgrades.

We changed the top level version for:

- 1.x to 2.x: Dropping Scala 2.9, supporting Java 8
- 2.x to 3.x: Dropping Java 7 support

When we will have similar major changes in the future, bumping the top level to 4.x.

https://github.com/scalikejdbc/scalikejdbc/blob/develop/notes/2.0.0.markdown

The past versions (1.x, 2.x) are still maintained for security fixes and critical bug fixes. Even if we release 4.x, we will keep maintaining 3.x by bringing important backports for a while.

## How to Contribute

ScalikeJDBC is hosted on [GitHub](http://github.com/scalikejdbc/scalikejdbc) . Reporting bugs on the issues, sending patches on pull requests are always welcome.

If you find mistakes or some rooms to improve on this cookbook, please let us know (or provide patches).

[https://github.com/scalikejdbc/scalikejdbc-cookbook](https://github.com/scalikejdbc/scalikejdbc-cookbook)


## Sincere Gratitude

Thank you for taking time to read this cookbook. We hope ScalikeJDBC allows you to implement database access in Scala smoothly!

