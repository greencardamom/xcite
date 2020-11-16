#!/usr/bin/awk -bE

#
# Parse citation templates from Wikipedia on a regular basis and save to dump files
#   /data/project/botwikiawk/www/static/xcite/
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

# set bot name before @includes
BEGIN {
  BotName = "xcite"
}

@include "botwiki.awk"
@include "library.awk"
@include "json.awk"
@include "trans.awk"

# _____________________________________ Times 

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


# _____________________________________ Backlinks (-b) 

#
# MediaWiki API:Backlinks
#  https://www.mediawiki.org/wiki/API:Backlinks
#
function backlinks(entity, file,      url, blinks) {

        url = P["apiURL"] "action=query&list=embeddedin&eititle=" urlencodeawk(entity) "&einamespace=" urlencodeawk(G["namespace"]) "&continue=&eilimit=500&format=json&formatversion=2&maxlag=" G["maxlag"]
        return getbacklinks(url, entity, "eicontinue", file)

}

function getbacklinks(url, entity, method, file,      jsonin, jsonout, continuecode, ie) {

        # Try 50 times..
        for(ie = 1; ie <= 50; ie++) {
          if(ie == 50) 
            return 0
          jsonin = http2var(url)
          if (apierror(jsonin, "json") > 0) {
              sleep(15, "unix")
              continue
          }
          else
            break
        }

        print json2var(jsonin) >> file
        close(file)
        continuecode = getcontinue(jsonin, method)

        while ( continuecode ) {
            if ( method == "eicontinue" )
                url = P["apiURL"] "action=query&list=embeddedin&eititle=" urlencodeawk(entity) "&einamespace=" urlencodeawk(G["namespace"]) "&eilimit=500&continue=" urlencodeawk("-||") "&eicontinue=" urlencodeawk(continuecode) "&format=json&formatversion=2&maxlag=" G["maxlag"]

            # Try 50 times..
            for(ie = 1; ie <= 50; ie++) {
              if(ie == 50) 
                return 0
              jsonin = http2var(url)
              if (apierror(jsonin, "json") > 0) {
                  sleep(15, "unix")
                  continue
              }
              else
                break
            }

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

        return 0

}

# _____________________________________ Application

#
# numbers to letters (generated by split)
#  eg. 1="aa", 26="az", 27="ba", etc..
#
function neq(i,  n) {
    n=97
    i--
    return sprintf("%c%c", int(n+i/26), n+i%26)
}

#
# Cycle through master.db backwards and after the fourth entry remove the files
#  Create www/log.txt sorted newest to oldest 
#
function cyclejson(  c,line,i,a,w,filename,filetype) {

  if(checkexists(G["www"] "log.txt")) 
    removefile2(G["www"] "log.txt")

  c = split(readfile(P["db"] "master.db"), line, "\n")
  for(i = c; i >= 1; i--) {
    if(!empty(line[i])) {
      split(line[i], a, " ")
      filename = a[1] "." a[2] "." a[3] ".json.gz"
      filetype = a[1] "." a[2] ".json.gz"
      w[filetype]++
      if(w[filetype] > 4) {
        if(checkexists(G["www"] filename)) {
          removefile2(G["www"] filename)
        }
      }
      else 
        print line[i] >> G["www"] "log.txt"
    }
  }
  close(G["www"] "log.txt")

}

#
# Cycle through log/log.txt backwards and after the 20th entry remove the files .syslog and .embedded
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


#
# Spawn concurrent bots into the Grid
#
function execbot(ip,  n,command,i,dbout,dblock,newtarg,alldone,curtime,latetime) {

    delete dblock

    for(i = 1; i <= G["slots"]; i++) {

      n = neq(i)
      dbout = ip "." n
      dblock[n]["done"] = 0
      dblock[n]["lock"] = dbout ".lock"
      
      newtarg = G["target"]
      gsub(/\n/, "+", newtarg)

      # Create lock here instead of by runbot.nim
      print "1" > dblock[n]["lock"]
      close(dblock[n]["lock"])

      # Spawn bot onto the grid
      command = "/usr/bin/jsub -once -continuous -quiet -N xcite-" n "-" G["lang"] " -l mem_free=100M,h_vmem=100M -e /data/project/botwikiawk/xcite/stdioer/" G["lang"] "wiki.stderr -o /data/project/botwikiawk/xcite/stdioer/" G["lang"] "wiki.stdout -v \"AWKPATH=.:/data/project/botwikiawk/BotWikiAwk/lib\" -v \"PATH=/sbin:/bin:/usr/sbin:/usr/local/bin:/usr/bin:/data/project/botwikiawk/BotWikiAwk/bin\" -wd /data/project/botwikiawk/xcite /data/project/botwikiawk/xcite/runbot -l=" G["lang"] " -d=" G["domain"] " -b=" shquote(dbout) " -h=" shquote(Home) " -k=" shquote(dblock[n]["lock"]) " -t=" shquote(newtarg) 
      sys2var(command)

    }

    # Monitor when bots are finished

    curtime = sys2var(Exe["date"] " +\"%s\"")
    latetime = curtime + (G["hours"] * (60 * 60))    # how many seconds from now it will abort running

    while(1) {

      sleep(300, "unix")                       # Check every 5 minutes..

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

      # Break while loop when all done
      if(alldone == 1) 
        break

      # Exceeded time limit
      curtime = sys2var(Exe["date"] " +\"%s\"")
      if(int(curtime) >= int(latetime) ) {
        sys2var(Exe["mailx"] " -s " shquote("NOTIFY: " BotName "(" Hostname "." Domain ") xcite time exceeded - LOGIN NOW AND CLEAR DATA OR RISK DATA DAMAGE") " " G["email"] " < /dev/null")
        exit
      }

    }

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

    sys2var(Exe["mailx"] " -s " shquote("NOTIFY: " BotName "(" Hostname "." Domain ") xcite restarted - LOGIN NOW AND CLEAR DATA OR RISK DATA DAMAGE") " " G["email"] " < /dev/null")

    exit

  }

}

#
# Main
#
function main(  i,a,command,fn,json,k,c1,c2,lines,db,wc,filesz) {

  print "1" > P["db"] P["key"] ".xcite.lock"
  close(P["db"] P["key"] ".xcite.lock")

  # Cycle old index.db file to .prev.index.db

  if(checkexists(P["db"] P["key"] ".index.db"))
    sys2var(Exe["mv"] " " P["db"] P["key"] ".index.db " P["db"] P["key"] ".index.prev.db")
  if(checkexists(P["db"] P["key"] ".index.db.gz"))
    sys2var(Exe["mv"] " " P["db"] P["key"] ".index.db.gz " P["db"] P["key"] ".index.prev.db.gz")

  # Create new index.db containing backlinks for cite book, journal etc..
  # Abort on error 

  for(i = 1; i <= splitn(G["target"], a, i); i++) {
    if(backlinks("Template:" R[a[i] "tlname"], P["db"] P["key"] ".index.db") == 0) {
      stdErr("xcite.awk (" curtime() "): backlinks(Template:" R[a[i] "tlname"] "): unable to determine backlinks.")
      sys2var(Exe["mailx"] " -s " shquote("NOTIFY: " BotName "(" Hostname "." Domain ") xcite aborted - backlinks error. Check stderr log.") " " G["email"] " < /dev/null")
      removefile2(P["db"] P["key"] ".index.db")
      if(checkexists(P["db"] P["key"] ".index.prev.db.gz"))
        sys2var(Exe["mv"] " " P["db"] P["key"] ".index.prev.db.gz " P["db"] P["key"] ".index.db.gz")
      removefile2(P["db"] P["key"] ".xcite.lock")
      exit
    }
  }
  
  # Sort and uniq. Keep memory usage under G["memalloc"] MB

  sys2var(Exe["sort"] " --temporary-directory=" P["db"] " --buffer-size=" G["memalloc"] " --parallel=1 " P["db"] P["key"] ".index.db | " Exe["uniq"] " > " P["db"] P["key"] ".index.db.sort")
  sys2var(Exe["mv"] " " P["db"] P["key"] ".index.db.sort " P["db"] P["key"] ".index.db")

  if(checkexists(P["db"] P["key"] ".index.db")) {

    # Split into x-slot chunks - round-robbin to keep files same length - sort order clobbered
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

    # Move log/syslog file
    if(checkexists(P["log"] P["key"] ".syslog")) {
      sys2var(Exe["mv"] " " P["log"] P["key"] ".syslog " P["log"] P["key"] ".syslog." date8())
      parallelWrite(P["key"] " syslog " date8(), P["log"] "log.txt", Engine)  
    }

    # Move log/embedded file
    if(checkexists(P["log"] P["key"] ".embedded")) {
      sys2var(Exe["mv"] " " P["log"] P["key"] ".embedded " P["log"] P["key"] ".embedded." date8())
      parallelWrite(P["key"] " embedded " date8(), P["log"] "log.txt", Engine)  
    }

    # Move .db to www and gzip and log
    for(k = 1; k <= splitn(G["target"], a, k); k++) {
      fn = P["db"] P["key"] "." a[k] ".db"
      json = G["www"] P["key"] "." a[k] "." date8() ".json"
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

#
# BEGIN{}
#
BEGIN {

  # Defaults:
  #
  # www = directory where HTML is served from. Include trailing slash.
  # email = email for reporting critical errors
  # maxlag = WMF API maxlag .. 5 is typical
  # memalloc = maximum memory to allocate to Unix sort
  # namespace = for backlinks eg. 0 means only backlinks that are mainspace 0 articles
  #
  # slots = X
  #   number of concurrent runbot's
  #   Toolforge accounts are assigned a default max of 15 slots
  #   Leave at least 2 slots free from the max eg. no more than 13 in a default Toolforge account
  #   The more slots the faster it will complete.
  #   6 slots will finish enwiki in about 12-20 hours. 12 slots in half that time.
  #
  # target = book\njournal
  #   CS1|2 citation templates to create dumps for
  #   \n separated list without leading "cite" in template name 
  #   eg. "book\njournal" will create dumps for {{cite book}} and {{cite journal}}
  #   Templates must have localizations and regexs defined in trans.awk and trans2nim.awk

  _defaults = "www       = /data/project/botwikiawk/www/static/xcite/ \
               email     = name@example.com \
               slots     = 6 \
               target    = book\njournal\nnews\nmagazine \
               maxlag    = 5 \
               memalloc  = 50M \
               namespace = 0 \
               version   = 1.0 \
               copyright = 2020 \
               author    = User:GreenC on en.wikipedia.org (https://github.com/greencardamom/xcite)"

  # Populate G[""] with above data
  asplit(G, _defaults, "[ ]*[=][ ]*", "[ ]{9,}")

  IGNORECASE=1
  Optind = Opterr = 1
  while ((C = getopt(ARGC, ARGV, "l:d:h:")) != -1) {
      opts++       
      if(C == "d")                 #  -d <domain>    Domain name eg. wikipedia.org"
        G["domain"] = Optarg
      if(C == "l")                 #  -l <lang>      Wiki language code. 
        G["lang"] = Optarg
      if(C == "h")                 #  -h <hours>     Abort running after X hours
        G["hours"] = Optarg
  }

  if(empty(G["domain"]) || empty(G["lang"]) || empty(G["hours"]) ) {
    print "xCite " G["version"] " Copyright " G["copyright"] " " G["author"]
    print "\n\txcite -l <lang> -d <domain.org> -h <hours till abort>\n"
    exit
  }
  if(!checkexists(Home)) {
    stdErr("Unable to find home directory: " Home)
    stdErr("Check config in ~/BotWikiAwk/lib/botwiki.awk")
    exit
  }
  if(!checkexists(G["www"])) {
    stdErr("Unable to find www directory: " G["www"])
    exit
  }

  delete P
  P["db"]  = Home "db/"             # article name database files
  P["log"] = Home "log/"          
  P["key"] = G["lang"] "." G["domain"]
  P["apiURL"] = "https://" P["key"] "/w/api.php?"

  delete R
  loadtrans(G["lang"], G["domain"]) # load R[] with localizations from trans.awk

  checkrestart()
  main()

}
