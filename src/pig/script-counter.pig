/*
 * Copyright 2011 Internet Archive
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you
 * may not use this file except in compliance with the License. You
 * may obtain a copy of the License at
 *
 *  http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 * implied. See the License for the specific language governing
 * permissions and limitations under the License.
 */

--
-- Sample Pig script which demonstrates how to count the number characters
-- in different Unicode scripts, then total them across pages and scripts.
--

REGISTER build/bacon-*.jar;

-- Default tokenizing delimiter.  Note the double-escaping of the \ character.
-- Delmit/tokenize on all non-alphabetic characters.
%default DELIM '[\\\\P{L}]+';

%default INPUT 'test/script_counter.txt';

DEFINE tokenize      org.archive.bacon.Tokenize();
DEFINE strlen        org.archive.bacon.StringLength();
DEFINE script_tag    org.archive.bacon.ScriptTagger();

pages = LOAD '$INPUT' AS (url:chararray,digest:chararray,words:chararray);

pages = FOREACH pages GENERATE TOTUPLE(url,digest) AS id, tokenize( words, '$DELIM' ) AS tokens;

-- Tag the tokens with their Unicode script, splitting multi-script
-- tokens into more tokens as needed.
pages = FOREACH pages GENERATE id, script_tag(tokens) AS tags;

-- Omit pages with no tags.
pages = FILTER pages BY tags is not null;

-- Calculate the length of all the tokens on each page.
pages = FOREACH pages GENERATE id, strlen(tags.token) AS pagelen, tags;

-- Flatten out the tags and measure the size of each token.
pages = FOREACH pages GENERATE id, pagelen, FLATTEN(tags) AS (token:chararray,script:chararray);
pages = FOREACH pages GENERATE id, pagelen, strlen(token) AS tokenlen:long, script;

-- Group the pages.
pages = GROUP pages BY (id,pagelen,script);

pages = FOREACH pages GENERATE group.id      AS id,
                               group.pagelen AS pagelen,
                               group.script  AS script,
                               (long)SUM(pages.tokenlen) AS scriptlen:long;

-- We dump the pages here and get output of the following:
--
--  ((http://example.com/2,sha1:23456),304,LATIN,189)
--  ((http://example.com/2,sha1:23456),304,ARABIC,115)
--
-- Where the 304 is the page length in characters and 189 is the # of
-- character in LATIN.
DUMP pages;

-- Group by script, and total the number of pages in that script,
--  the total lengths of all the pages the script appears on,
--  and the total length of all the tokens in that script.
script_counts = GROUP pages BY script;
script_counts = FOREACH script_counts GENERATE group AS script, SIZE(pages) AS numpages, SUM(pages.scriptlen) AS scriptlen, SUM(pages.pagelen) AS totallen ;

DUMP script_counts;

