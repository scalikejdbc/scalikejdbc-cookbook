#!/bin/bash

base_dir=`dirname $0`
cd ${base_dir}

rm scalikejdbc-cookbook-ja.*
./bin/export_html_ja.rb ja/*.md > scalikejdbc-cookbook-ja.html
/Applications/calibre.app/Contents/MacOS/ebook-convert scalikejdbc-cookbook-ja.html scalikejdbc-cookbook-ja.epub --no-default-epub-cover

