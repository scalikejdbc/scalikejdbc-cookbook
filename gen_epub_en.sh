#!/bin/bash

base_dir=`dirname $0`
cd ${base_dir}

rm scalikejdbc-cookbook-en.*
./bin/export_html_en.rb en/*.md > scalikejdbc-cookbook-en.html
/Applications/calibre.app/Contents/MacOS/ebook-convert scalikejdbc-cookbook-en.html scalikejdbc-cookbook-en.epub --no-default-epub-cover

