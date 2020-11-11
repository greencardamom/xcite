#!/usr/bin/awk -bE

#
# Export trans.awk regex statements for use by runbot.nim part of the xcite.awk project
#
# trans.awk is shared by multiple programs including arcstat.awk
#

# The MIT License (MIT)
#
# Copyright (c) 2020 by User:GreenC (at en.wikipedia.org)
#
# https://github.com/greencardamom/xcite
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

@include "library.awk"
@include "trans.awk"

BEGIN {

  IGNORECASE=1
  delete G

  Optind = Opterr = 1
  while ((C = getopt(ARGC, ARGV, "d:l:s:")) != -1) {
      opts++
      if(C == "d")                 #  -d <domain>    Domain name eg. wikipedia.org
        G["domain"] = Optarg
      if(C == "l")                 #  -l <lang>      Wiki language code
        G["lang"] = Optarg
      if(C == "s")                 #  -s <service>   Service name eg. book, journal, magazine etc..  
        G["service"] = Optarg
  }

  if(empty(G["domain"]) || empty(G["lang"]) || empty(G["service"]) ) 
    exit

  delete R
  loadtrans(G["lang"], G["domain"]) # load R[] with localizations        

  space = "[\n\t]{0,}[ ]{0,}[\n\t]{0,}[ ]{0,}[\n\t]{0,}"

  if(!empty(R[G["service"] "re"]))
    print "(?i)" gsubs("[[:space:]]*", space , R[G["service"] "re"])

}

