#!/usr/bin/awk -bE

#
# Parse citation templates from Wikipedia on a regular basis and save to dump files
#   /data/project/botwikiawk/www/static/xcite/
#

# The MIT License (MIT)
#
# Copyright (c) 2020 by User:GreenC (at en.wikipedia.org)
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
@include "json.awk"
@include "trans.awk"

BEGIN {

  IGNORECASE=1

  delete G
  Optind = Opterr = 1
  while ((C = getopt(ARGC, ARGV, "l:d:")) != -1) {
      opts++       
      if(C == "d")                 #  -d <domain>    Domain name eg. wikipedia.org"
        G["domain"] = Optarg
      if(C == "l")                 #  -l <lang>      Wiki language code. 
        G["lang"] = Optarg
  }

  if(empty(G["domain"]) || empty(G["lang"]) ) {
    print "xcite -l <lang> -d <domain.org> "
    exit
  }

  # CS1|2 citation templates to create dumps for
  # \n separated list without leading "cite" in template name 
  # eg. "book\njournal" will create dumps for {{cite book}} and {{cite journal}}
  # Citations must have localizations and regexs defined in trans.awk and trans2nim.awk

  G["target"] = "book\njournal\nnews\nmagazine"

  delete P
  P["db"]  = Home "db/"             # article name database files
  P["log"] = Home "log/"          
  P["www"] = "/data/project/botwikiawk/www/static/xcite/"
  P["key"] = G["lang"] "." G["domain"]
  P["email"] = ""                   # add email for warning messages

  G["apiURL"] = "https://" P["key"] "/w/api.php?"
  G["maxlag"] = 5

  G["namespace"] = 0      # namespace for citation template backlinks

  G["memalloc"] = "50M"   # Unix sort memory allocation

  G["slots"] = 6          # number of concurrent runbot's - valid 1 to 26. Update neq() for more
                          # Toolforge accounts are assigned a default max of 15 slots
                          # The more slots the faster it will complete
                          # 6 slots will finish enwiki in about 12-20 hours

  delete R
  loadtrans(G["lang"], G["domain"]) # load R[] with localizations from trans.awk

  checkrestart()
  main()
  removefile2(P["db"] P["key"] ".xcite.lock")

}

#
# Check if xcite restarted .. clear files and start over
#
function checkrestart() {

  if(checkexists(P["db"] P["key"] ".xcite.lock")) {
    removefile2(P["db"] P["key"] ".xcite.lock")

    if(checkexists(P["db"] P["key"] ".index.prev.db"))
      sys2var(Exe["mv"] " " P["db"] P["key"] ".index.prev.db " P["db"] P["key"] ".index.db")
    else if(checkexists(P["db"] P["key"] ".index.prev.db.gz"))
      sys2var(Exe["mv"] " " P["db"] P["key"] ".index.prev.db.gz " P["db"] P["key"] ".index.db.gz")

    sys2var(Exe["mailx"] " -s " shquote("NOTIFY: " BotName "(" Hostname "." Domain ") xcite restarted - LOGIN AND CLEAR DATA!") " " P["email"] " < /dev/null")

    exit

  }

}

function main(  i,a,command,fn,json,k,c1,c2,lines,db,wc,filesz) {

  print "1" > P["db"] P["key"] ".xcite.lock"
  close(P["db"] P["key"] ".xcite.lock")

  # Cycle old index.db file to .prev.index.db
  if(checkexists(P["db"] P["key"] ".index.db"))
    sys2var(Exe["mv"] " " P["db"] P["key"] ".index.db " P["db"] P["key"] ".index.prev.db")
  if(checkexists(P["db"] P["key"] ".index.db.gz"))
    sys2var(Exe["mv"] " " P["db"] P["key"] ".index.db.gz " P["db"] P["key"] ".index.prev.db.gz")

  # Create new index.db containing backlinks for cite book, journal etc..
  for(i = 1; i <= splitn(G["target"], a, i); i++) 
    backlinks("Template:" R[a[i] "tlname"], P["db"] P["key"] ".index.db")
  
  # Sort and uniq
  sys2var(Exe["sort"] " --temporary-directory=" P["db"] " --buffer-size=" G["memalloc"] " --parallel=1 " P["db"] P["key"] ".index.db | " Exe["uniq"] " > " P["db"] P["key"] ".index.db.sort")
  sys2var(Exe["mv"] " " P["db"] P["key"] ".index.db.sort " P["db"] P["key"] ".index.db")

  # Sanity check current run is not smaller than last run
  if(checkexists(P["db"] P["key"] ".index.db") && checkexists(P["db"] P["key"] ".index.prev.db") ) {
    c1 = int(splitx(sys2var(Exe["wc"] " -l " P["db"] P["key"] ".index.db"), " ", 1))
    c2 = int(splitx(sys2var(Exe["wc"] " -l " P["db"] P["key"] ".index.prev.db"), " ", 1)) - 1000
    if(c1 < c2) {
      parallelWrite(curtime() " Aborting. " P["db"] P["key"] ".index.db (" c1 ") is smaller than " P["db"] P["key"] ".index.prev.db (" c2 ")", P["log"] P["key"] ".syslog", Engine)
      if(checkexists(P["db"] P["key"] ".index.prev.db"))
        sys2var(Exe["mv"] " " P["db"] P["key"] ".index.prev.db " P["db"] P["key"] ".index.db")
      else if(checkexists(P["db"] P["key"] ".index.prev.db.gz"))
        sys2var(Exe["mv"] " " P["db"] P["key"] ".index.prev.db.gz " P["db"] P["key"] ".index.db.gz")
      removefile2(P["db"] P["key"] ".xcite.lock")
      exit
    }
  }

  if(checkexists(P["db"] P["key"] ".index.db")) {

    # Determines how many lines per file. This will maintain sort order (eg. split -l <lines>) but sort is clobbered by runbot so is not needed
    # (wc .db / 6) + 1
    # lines = int(splitx( int(strip(splitx(sys2var(Exe["wc"] " -l " P["db"] P["key"] ".index.db"), " ", 1))) / 6, ".", 1) + 1)

    # Split into x slots chunks - round-robbin to keep files same length - sort order clobbered
    # split --number=r/6 index.db index.db.
    sys2var(Exe["split"] " --number=r/" G["slots"] " " P["db"] P["key"] ".index.db " P["db"] P["key"] ".index.db.")

    # Run the bot on each page saving to .db files
    execbot(P["db"] P["key"] ".index.db")

    # Combine split db's into book.db etc..
    for(k = 1; k <= splitn(G["target"], a, k); k++) {
      for(i = 1; i <= G["slots"]; i++) { 
        if(checkexists(P["db"] P["key"] "." a[k] ".db." neq(i))) {
          db[a[k]] = db[a[k]] " " P["db"] P["key"] "." a[k] ".db." neq(i)
        }
      }
    }
    for(k in db) {
      sys2var(Exe["cat"] " " db[k] " > " P["db"] P["key"] "." k ".db")
    }

    # Remove split index's
    for(i = 1; i <= G["slots"]; i++) 
      removefile2(P["db"] P["key"] ".index.db." neq(i))

    # Remove split db's
    for(k = 1; k <= splitn(G["target"], a, k); k++) {
      for(i = 1; i <= G["slots"]; i++) 
        removefile2(P["db"] P["key"] "." a[k] ".db." neq(i))
    }

    # backup master.db
    if(checkexists(P["db"] "master.db") && checkexists(P["db"] "masterbak") )
      sys2var(Exe["cp"] " " P["db"] "master.db " P["db"] "masterbak/master.db." date8() )

    # Move log file
    if(checkexists(P["log"] ".syslog")) {
      sys2var(Exe["mv"] " " P["log"] ".syslog " P["log"] "." date8() ".syslog")
      parallelWrite(P["key"] " syslog " date8(), P["log"] "log.txt", Engine)  
    }

    # Move .db to www and gzip and log
    for(k = 1; k <= splitn(G["target"], a, k); k++) {
      fn = P["db"] P["key"] "." a[k] ".db"
      json = P["www"] P["key"] "." a[k] "." date8() ".json"
      if(checkexists(fn)) {
        sys2var(Exe["mv"] " " fn " " json)
        wc = splitx(sys2var(Exe["wc"] " -l " json), " ", 1)
        sys2var(Exe["gzip"] " -f " json)
        filesz = splitx(int(filesize(json ".gz")) / 1000000, ".", 1) + 1 # whole number rounded up
        parallelWrite(P["key"] " " a[k] " " date8() " " wc " " filesz, P["db"] "master.db", Engine)
      }
    }
    sys2var(Exe["gzip"] " -f " P["db"] P["key"] ".index.db")
  }

  cyclejson() # keep a maximum of 3 json cycles delete the rest
  cyclelogs() # keep a maximum of 20 log cycles delete the rest

  removefile2(P["db"] P["key"] ".xcite.lock")

}


function neq(i,  n) {
      if(i == 1)      n = "aa"
      else if(i == 2) n = "ab"
      else if(i == 3) n = "ac"
      else if(i == 4) n = "ad"
      else if(i == 5) n = "ae"
      else if(i == 6) n = "af"
      else if(i == 7) n = "ag"
      else if(i == 8) n = "ah"
      else if(i == 9) n = "ai"
      else if(i == 10) n = "aj"
      else if(i == 11) n = "ak"
      else if(i == 12) n = "al"
      else if(i == 13) n = "am"
      else if(i == 14) n = "an"
      else if(i == 15) n = "ao"
      else if(i == 16) n = "ap"
      else if(i == 17) n = "aq"
      else if(i == 18) n = "ar"
      else if(i == 19) n = "as"
      else if(i == 20) n = "at"
      else if(i == 21) n = "au"
      else if(i == 22) n = "av"
      else if(i == 23) n = "aw"
      else if(i == 24) n = "ax"
      else if(i == 25) n = "ay"
      else if(i == 26) n = "az"
      else            n = "zz"
      return n
}
function execbot(ip,  n,command,i,dbout,dblock,newtarg,alldone) {

    delete dblock

    for(i = 1; i <= G["slots"]; i++) {

      n = neq(i)
      dbout = ip "." n
      dblock[n]["done"] = 0
      dblock[n]["lock"] = dbout ".lock"
      
      newtarg = G["target"]
      gsub(/\n/, "+", newtarg)

      command = "/usr/bin/jsub -once -continuous -quiet -N xcite-" n "-" G["lang"] " -l mem_free=100M,h_vmem=100M -e /data/project/botwikiawk/xcite/stdioer/" G["lang"] "wiki.stderr -o /data/project/botwikiawk/xcite/stdioer/" G["lang"] "wiki.stdout -v \"AWKPATH=.:/data/project/botwikiawk/BotWikiAwk/lib\" -v \"PATH=/sbin:/bin:/usr/sbin:/usr/local/bin:/usr/bin:/data/project/botwikiawk/BotWikiAwk/bin\" -wd /data/project/botwikiawk/xcite /data/project/botwikiawk/xcite/runbot -l=" G["lang"] " -d=" G["domain"] " -b=" shquote(dbout) " -k=" shquote(dblock[n]["lock"]) " -t=" shquote(newtarg) 
      sys2var(command)
    }

    while(1) {

      sleep(300, "unix")

      # Check for each .lock file existence
      for(i = 1; i <= G["slots"]; i++) {
        if(dblock[neq(i)]["done"] != 1) {
          if(!checkexists(dblock[neq(i)]["lock"]) ) 
            dblock[neq(i)]["done"] = 1
        }
      }

      # Check if all .lock gone ie. all done
      alldone = 1
      for(i = 1; i <= G["slots"]; i++) {
        if(dblock[neq(i)]["done"] != 1) 
          alldone = 0
      }

      # Break while loop if all done
      if(alldone == 1) 
        break
    }

}

#
# Cycle through master.db backwards and after the third entry remove the files
#  Create www/log.txt sorted newest to oldest 
#
function cyclejson(  c,line,i,a,w,filename,filetype) {

  if(checkexists(P["www"] "log.txt")) 
    removefile2(P["www"] "log.txt")

  c = split(readfile(P["db"] "master.db"), line, "\n")
  for(i = c; i >= 1; i--) {
    if(!empty(line[i])) {
      split(line[i], a, " ")
      filename = a[1] "." a[2] "." a[3] ".json.gz"
      filetype = a[1] "." a[2] ".json.gz"
      w[filetype]++
      if(w[filetype] > 3) {
        if(checkexists(P["www"] filename)) {
          removefile2(P["www"] filename)
        }
      }
      else 
        print line[i] >> P["www"] "log.txt"
    }
  }
  close(P["www"] "log.txt")

}

#
# Cycle through log.txt backwards and after the 20th entry remove the files
#
function cyclelogs(  c,line,i,a,w,filename,filetype) {

  c = split(readfile(P["log"] "log.txt"), line, "\n")
  for(i = c; i >= 1; i--) {
    if(!empty(line[i])) {
      split(line[i], a, " ")
      filename = a[1] "." a[2] "." a[3]
      filetype = a[1] "." a[2] 
      w[filetype]++
      if(w[filetype] > 20) {
        if(checkexists(P["log"] filename)) {
          removefile2(P["log"] filename)
        }
      }
    }
  }
}



# ___ Backlinks (-b) 

#
# MediaWiki API:Backlinks
#  https://www.mediawiki.org/wiki/API:Backlinks
#
function backlinks(entity, file,      url, blinks) {

        url = G["apiURL"] "action=query&list=embeddedin&eititle=" urlencodeawk(entity) "&einamespace=" urlencodeawk(G["namespace"]) "&continue=&eilimit=500&format=json&formatversion=2&maxlag=" G["maxlag"]
        getbacklinks(url, entity, "eicontinue", file)

}

function getbacklinks(url, entity, method, file,      jsonin, jsonout, continuecode) {


        jsonin = http2var(url)
        if (apierror(jsonin, "json") > 0)
            return 0
        print json2var(jsonin) >> file
        close(file)
        continuecode = getcontinue(jsonin, method)

        while ( continuecode ) {
            if ( method == "eicontinue" )
                url = G["apiURL"] "action=query&list=embeddedin&eititle=" urlencodeawk(entity) "&einamespace=" urlencodeawk(G["namespace"]) "&eilimit=500&continue=" urlencodeawk("-||") "&eicontinue=" urlencodeawk(continuecode) "&format=json&formatversion=2&maxlag=" G["maxlag"]
            jsonin = http2var(url)
            print json2var(jsonin) >> file
            close(file)
            continuecode = getcontinue(jsonin, method)
        }
        return 1
}

#
# json2var - given raw json extract field "title" and convert to \n seperated string
#
function json2var(json,  jsona,arr) {
    if (query_json(json, jsona) >= 0) {
        splitja(jsona, arr, 3, "title")
        return join(arr, 1, length(arr), "\n")
    }
}

#
# Parse continue code from JSON input                
#
function getcontinue(jsonin, method,    jsona,id) {

        if( query_json(jsonin, jsona) >= 0) {
          id = jsona["continue", method]
          if(!empty(id))
            return id
        }      
        return 0
}

#
# Basic check of API results for error
#
function apierror(input, type,   pre, code) {

        pre = "API error: "

        if (length(input) < 5) {
            stdErr(pre "Received no response.")
            return 1
        }

        if (type == "json") {
            if (match(input, /"error"[:]{"code"[:]"[^\"]*","info"[:]"[^\"]*"/, code) > 0) {
                stdErr(pre code[0])
                return 1
            }
        }
}

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

