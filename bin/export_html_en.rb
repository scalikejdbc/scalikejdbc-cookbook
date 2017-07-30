#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'redcarpet'

HEADER = <<HEAD
<html>
<head>
<title>ScalikeJDBC Cookbook</title>
<meta name="Author" content="Kazuhiro Sera">
<meta name="DC.date.publication" content="2017-07">
<meta name="DC.rights" content="2017 Kazuhiro Sera">
<link rel="stylesheet" href="styles/epub.css" type="text/css" class="horizontal" title="Horizontal Layout" />
</head>
<body>
HEAD

def munge(html)
  html.gsub /<h1>/, '<h1 class="chapter">'
end

markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, :autolink => true, :space_after_headers => true)
STDOUT.write HEADER
STDOUT.write munge(markdown.render(ARGF.readlines.join ''))
STDOUT.write "</body></html>\n"

