#!/usr/bin/awk -bE

#
# Generate HTML for xcite.awk
# https://tools-static.wmflabs.org/botwikiawk/xcite/xcite.html
# /data/project/botwikiawk/www/static/xcite/xcite.html

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

# set bot name before @includes
BEGIN {
  BotName = "xcite"
}

@include "botwiki.awk"
@include "library.awk"

@include "trans.awk"

#
# Return current date-eight (20120101) in UTC
#
function date8() {
  return strftime("%Y%m%d", systime(), 1)
}

#
# Current time
#
function curtime() {
  return strftime("%Y%m%d-%H:%M:%S", systime(), 1)
}

#
# ISO dash. Convert 20101010 -> 2010-10-10
#
function isodash(s) {
  return substr(s, 1, 4) "-" substr(s, 5, 2) "-" substr(s, 7, 2) 
}

#
# Add commas to a number
#
function coma(s) {
  return sprintf("%'d", s)
}

#
# Sorting 4D associative array on third element (date)
#
function reindex(org, new,       o, o2, o3, o4, newndx) {
  delete new
  for(o in org) {
    for(o2 in org[o]) {
      for(o3 in org[o][o2]) {
        newndx = o3
        for(o4 in org[o][o2][o3])
          new[newndx][o][o2][o3][o4] = org[o][o2][o3][o4]
      }
    }
  }
}

#
# Print HTML file
#
function makePage( i,o,o2,o3,o4,Tb,hn,dn) {

  if(checkexists(Home "header.html") && checkexists(Home "footer.html") )
    print readfile(Home "header.html") > P["html"]
  else
    return

  if(checkexists(Home "table1header.html") )
    print readfile(Home "table1header.html") > P["html"]
  else
    return

  print "<tbody>" >> P["html"]  
  print "<center><a href=\"doc.html\">Documentation</a></center>" >> P["html"]

  #    <th><u>#</u></th>
  #    <th><u>A</u><br>Site</th>
  #    <th><u>B</u><br>Language</th>
  #    <th><u>C</u><br>Template</th>
  #    <th><u>D</u><br>Date</th>
  #    <th><u>E</u><br>Number of templates</th>
  #    <th><u>F</u><br>File name</th>
  #    <th><u>G</u><br>File size</th>

  reindex(T, Tb)
  PROCINFO["sorted_in"] = "@ind_num_desc"
  for (o in Tb) {
    for(o2 in Tb[o]) {
 
      # Load translations of template names
      split(o2, hn, /[.]/)
      dn = subs(hn[1] ".", "", o2)
      delete R
      loadtrans(hn[1], dn) # load R[] with localizations from trans.awk

      for(o3 in Tb[o][o2]) {
        for(o4 in Tb[o][o2][o3]) {
          Tb[o][o2][o3][o4]["wc"] 
          Tb[o][o2][o3][o4]["mb"] 
          print "  <tr>" >> P["html"]
          print "      <td>" ++i ".</td>" >> P["html"] 
          print "      <td>" isodash(o4) "</td>" >> P["html"]
          print "      <td>" o2 "</td>" >> P["html"]
          print "      <td>" R["plainlang"] "</td>" >> P["html"]
          print "      <td sorttable_customkey=\"" o3 "\">{{<a href=\"https://" o2 "/wiki/Template:" urlencodeawk(R[o3 "tlname"]) "\">" R[o3 "tlname"] "</a>}}</td>" >> P["html"]
          print "      <td>" coma(Tb[o][o2][o3][o4]["wc"]) "</td>" >> P["html"]
          print "      <td><a href=\"https://tools-static.wmflabs.org/botwikiawk/xcite/" o2 "." o3 "." o4 ".json.gz\">" o2 "." o3 "." o4 ".json.gz"  "</a></td>" >> P["html"]
          print "      <td sorttable_customkey=\"" Tb[o][o2][o3][o4]["mb"] "\">" Tb[o][o2][o3][o4]["mb"] " MB</td>" >> P["html"]
          print "  </tr>" >> P["html"]
        }
      }
    }
  }
  print "</tbody>" >> P["html"]
  print "</table>" >> P["html"]
  print "</center>"  >> P["html"]
  print readfile(Home "footer.html") >> P["html"]

}

#
# Create data array from ~/www/log.txt
#
function makeArrays(  c,line,i,a,w,filename,filetype) {

  if(!checkexists(P["www"] "log.txt")) {
    return 0
  }

  # log.txt format:
  # P["key"] " " <templatename> " " date8() " " wc " " filesize
  # en.wikipedia.org book 20201001 540000 1000.54

  c = split(readfile(P["www"] "log.txt"), line, "\n")
  for(i = c; i >= 1; i--) {
    if(!empty(line[i])) {
      split(line[i], a, " ")
      filename = a[1] "." a[2] "." a[3] ".json.gz"
      filetype = a[1] "." a[2] ".json.gz"
      w[filetype]++
      if(w[filetype] < 4) {
        if(checkexists(P["www"] filename)) {
          T[a[1]][a[2]][a[3]]["wc"] = a[4]    # T["en.wikipedia"]["book"]["20201001"]["wc"]
          T[a[1]][a[2]][a[3]]["mb"] = a[5]    # T["en.wikipedia"]["book"]["20201001"]["mb"] 
          # print "T[" a[1] "][" a[2] "][" a[3] "][\"wc\"] = " a[4]
        }
      }
    }
  }
  
  if(length(T) < 1) 
    return 0

  return 1

}

#
# Main
#
function main() {

  if(!makeArrays()) {
    parallelWrite("makehtml.awk (" curtime() "): Unable to find " P["www"] "log.txt", P["log"] "logmakehtml", Engine)
    stdErr("makehtml.awk (" curtime() "): Unable to find " P["www"] "log.txt", P["log"] "logmakehtml")
    exit
  }
  makePage()

}

#
# BEGIN {}
#
BEGIN {

  # Defaults:
  #
  # email = for reporting critical errors
  # www = directory where HTML is served from. Include trailing slash.
  # html = name of html file to be generated in the www directory
  #

  _defaults = "www       = /data/project/botwikiawk/www/static/xcite/ \
               email     = name@example.com \
               html      = xcite.html \
               version   = 1.0 \
               copyright = 2020 \
               author    = User:GreenC on en.wikipedia.org (https://github.com/greencardamom/xcite)"

  # Populate P[""] with above data
  asplit(P, _defaults, "[ ]*[=][ ]*", "[ ]{9,}")

  IGNORECASE = 1
  delete T
  P["db"]  = Home "db/"             
  P["log"]  = Home "log/"            
  P["html"] = P["www"] P["html"]

  main()

}
