#
# Given an article name, extract all designated citation types and save as JSON
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

import awk
import strutils, re, osproc, os, parseopt, tables, uri, json
import times except sleep

#
# Given a string return "true" of it's empty (0-length)
#
proc empty*(s: string): bool =

  result = false  
  if len(s) < 1: 
    return true

#
# Send msg to stderr with optional program quit
#
proc stdErr*(s: string, doQuit = "") =

  s >* "/dev/stderr"

  if len(doQuit) > 0:
    if doQuit ~ "(?i)success":
      quit(QuitSuccess)
    elif doQuit ~ "(?i)fail":
      quit(QuitFailure)
    else:
      quit(QuitFailure)

# _____________________________________________________________  Command line parse
#

type
  CLObj* = object
    domain: string
    lang: string
    db: string
    lockfile: string
    target: string

var CL*: CLObj

for poKind, poKey, poVal in getopt():
  case poKind
  of cmdArgument:
    discard
  of cmdLongOption, cmdShortOption:
    case poKey
    of "d":                    # -d=<val>    Domain to process
      CL.domain = poVal
    of "l":                    # -l=<val>    Wikilang (hostname)
      CL.lang = poVal
    of "b":                    # -b=<val>    Database to process
      CL.db = poVal
    of "k":                    # -k=<val>    Lockfile name
      CL.lockfile = poVal
    of "t":                    # -t=<val>    Targets with + sep eg. "book+journal+magazine"
      CL.target = poVal
  of cmdEnd:
    assert(false)

if empty(Cl.lang): stdErr("runbot.nim: No lang given", "QuitFailure")
if empty(Cl.domain): stdErr("runbot.nim: No domain given", "QuitFailure")
if not fileExists(CL.db): stdErr("runbot.nim: Unable to find sourceDB " & CL.db, "QuitFailure")
if empty(CL.lockfile): stdErr("runbot.nim: No lockfile given", "QuitFailure")
if empty(CL.target): stdErr("runbot.nim: No targets given", "QuitFailure")

# _______________________________________________________________________ Globals 
#                                                                         

type
  GXObj* = object
    homedir: string                                         
    db: string
    subdb: string
    key: string
    logfile: string
    targets: seq[string]

var GX*: GXObj

GX.homedir = "/data/project/botwikiawk/xcite/"               # with trailing slash
GX.db = GX.homedir & "db/"
GX.key = CL.lang & "." & CL.domain
GX.logfile =  GX.homedir & "log/" & GX.key & ".syslog"

let cc = awk.split(CL.db, aa, "[.]")                        # File extension eg. ".aa"
if not (aa[cc-1] ~ "^a" and len(aa[cc-1]) == 2):
  stdErr("runbot.nim: Unable to determine subdb", "QuitFailure")
GX.subdb = aa[cc-1]

var DefNonOrdCiteAa, targets = newOrderedTable[string, string]()

# _______________________________________________________________________ External programs
#                                                                         

type       
  ExeObj* = object
    timeout: string
    wget: string
    awk2nim: string

var Exe*: ExeObj

Exe.timeout = "/usr/bin/timeout --foreground"
Exe.wget = "/usr/bin/wget"
Exe.awk2nim = GX.homedir & "awk2nim.awk"


# _______________________________________________________________________ Utils
#                                                                         

#
# Make string safe for shell
#  print shquote("Hello' There")    produces 'Hello'\'' There'
#  echo 'Hello'\'' There'           produces Hello' There
#                 
proc shquote*(s: string): string =

    var safe = s
    gsub("'", "'\\''", safe)
    gsub("’", "'\\’'", safe)         
    "'" & safe & "'"

#
# Count occurances of 'sub' string in 's'
#
proc countsubstring*(s, sub: string): int =

  return count(s, sub)

#
# Convert XML to plain
#
proc convertxml*(str: string): string =

  var
    safe = str

  gsubs("&lt;",   "<",  safe)
  gsubs("&gt;",   ">",  safe)
  gsubs("&quot;", "\"", safe)
  gsubs("&amp;",  "&",  safe)
  gsubs("&#039;", "'",  safe)

  safe

#
# Sleep X seconds (module:os)
#
proc sleep*(sec: int): bool {.discardable.} =

  result = false
  var
    t: int
  t = sec * 1000
  os.sleep(t)


#
# Today's date in ymd ie. 20180901
#
proc todaysdateymd(): string =
  format(parse(getDateStr(), "yyyy-MM-dd"), "yyyyMMdd")

#
# Log (append) a line in a database                
#
#  If you need more than 2 columns (ie. name|msg) then format msg with separators in the string itself.
#
proc sendlog*(database, name, msg: string): bool {.discardable.} =         

  result = false
  var
    safen = name
    safem = msg
    sep = "----"

  if(len(safem) > 0):
    safen & sep & todaysdateymd() & sep & safem >> database
  else:
    safen >> database

#
# Run a shell-command
#
proc runshellBasic(command: string): string =

  var
    output = ""
    errC = 0

  (output, errC) = execCmdEx(command)
  return output

#
# Get a web page via wget 
#
proc http2var(url: string): string =

  var
    command, output = ""
    errC = 0

  command = Exe.timeout & " 40s " & Exe.wget & " --no-cookies --ignore-length --no-check-certificate --tries=3 --timeout=60 --waitretry=6 --retry-connrefused -q -O- " & shquote(url) 
  (output, errC) = execCmdEx(command)
  return output

#
# See libutils.nim for instructions
#
template psplit*(sourceText, regEx: string, sym: untyped, statements: untyped) {.dirty.} =

      when not compiles(sym):
        type
          symObj = object
            c: int
            ok: int
            i: int
            field: seq[string]
            sep: seq[string]
        var sym: symObj
      else:
        sym.c = 0
        sym.ok = 0
        sym.i = 0
        sym.field = newSeq[string](0)
        sym.sep = newSeq[string](0)

      sym.c = patsplit(sourceText, sym.field, regEx, sym.sep)
      if sym.c > 0:
        for i in 0 .. sym.c - 1:
          sym.i = i
          statements
        if sym.ok > 0:
          sourceText = unpatsplit(sym.field, sym.sep)

# _______________________________________________________________________ Encode wiki
#                                                                         
#
# Encode wiki 
#
proc encodeWik(article: string): string =

  var
    article = article
    GXcite2 = ""
    r = -1
    debug = false

  # Empty the table from previous run
  clear(DefNonOrdCiteAa)

  # Build regex
  for k in GX.targets:
    GXcite2 = GXcite2 & strip(targets[k]) & "|"
  GXcite2 = strip(GXcite2)
  sub("[|]$", "", GXcite2)

  for k in 0..9: # Check for up to 10 embedded templates in a cite template (including 2-layer deep)

    psplit(article, GXcite2, p):

      if debug: echo "fieldi (a) = " & p.field[i]

      if countsubstring(p.field[i], "{{") == 1: # no more embedded
        continue

      if debug: echo "fieldi (b) = " & p.field[i]

      var open1, open2, embed = false
      inc(r)

      let cc = awk.split(p.field[i], a, "")
      for ii in 0..cc-1:

        if a[ii] == "{" and open1 == true and open2 == true:
          a[ii] = "_HIDEO_"
          embed = true

        if a[ii] == "}" and embed:
          a[ii] = "_HIDEC_"

        if a[ii] == "{" and open1 == true and open2 == false:
          open2 = true

        if a[ii] == "{" and open1 == false and open2 == false:
          open1 = true

      var newtl = join(a)
      gsub("_HIDEO__HIDEO_", "_HIDESETO_", newtl)
      gsub("_HIDEC__HIDEC_", "_HIDESETC_", newtl)
      gsub("_HIDEO_", "{", newtl)
      gsub("_HIDEC_", "}", newtl)
      if newtl ~ "_HIDESETO_" and newtl ~ "_HIDESETC_":
        if awk.match(newtl, "_HIDESETO_.*$", inner) > 0:
          if newtl ~ "^[{][{][^{]+[{]": continue # safety checks
          if inner !~ "_HIDESETC_": continue
          let codename = "DefNonOrdCiteAa1." & $r & "z"
          if countsubstring(inner, "_HIDESETO_") == 2:  # embedded within embedded
            subs("_HIDESETO_", "{{", inner)
            if awk.match(inner, "_HIDESETO_.*$", inner2) > 0:
              gsubs(inner2, codename, newtl)
              gsub("_HIDESETO_", "{{", inner2)
              gsub("_HIDESETC_", "}}", inner2)
              gsub("_HIDESETO_", "{{", newtl)
              gsub("_HIDESETC_", "}}", newtl)
              DefNonOrdCiteAa[codename] = inner2
              p.field[i] = newtl
              inc(p.ok)
          else:     
            gsubs(inner, codename, newtl)
            gsub("_HIDESETO_", "{{", inner)
            gsub("_HIDESETC_", "}}", inner)
            gsub("_HIDESETO_", "{{", newtl)
            gsub("_HIDESETC_", "}}", newtl)
            DefNonOrdCiteAa[codename] = inner
            p.field[i] = newtl
            inc(p.ok)

  return article

proc decodeWik*(s: string): string =
  result = strip(s)
  if contains(s, "DefNonOrdCiteAa"):
    for i in DefNonOrdCiteAa.keys:          # 1-layer deep
        subs(i, DefNonOrdCiteAa[i], result)
    if contains(result, "DefNonOrdCiteAa"): # 2-layer deep
      for i in DefNonOrdCiteAa.keys:         
        subs(i, DefNonOrdCiteAa[i], result)

#
# Code helper
#
template getwikisource_helper() =

  if empty(webagent): # undo shquote() if using Nim
    gsub("(^'|'$)", "", webcommand)

  for i in 0..3:
    if i == 3:  # try Special:Export if action=raw not working in some cases
      webcommand = "https://" & hostname & "." & domain & "/wiki/Special:Export/" & uri.encodeUrl(strip(namewiki))
      if empty(webagent): 
        gsub("(^'|'$)", "", webcommand)
      for j in 0..3:
        if j == 3:
          if not empty(logfile):
            sendlog(logfile, namewiki, "Unable to retrieve wikitext in getwikisource(1)")
          return
        if not empty(webagent):
          f = http2var(webcommand)
        else:
          f = http2var(webcommand)
        if len(f) < 10:                                            
          sleep(2)
        else:
          if f !~ "(?i)[#][ ]*redirect[ ]*[[]":
            if awk.split(f, b, "(?i)([<][ ]*text xml[^>]*[>]|[<][ ]*[/][ ]*text)") > 1:
              f = convertxml(b[1])
              if len(f) < 10:
                if not empty(logfile):
                  sendlog(logfile, namewiki, "Unable to retrieve wikitext in getwikisource(2)")
                return
              break
            else:
              if not empty(logfile):
                sendlog(logfile, namewiki, "Unable to retrieve wikitext in getwikisource(3)")
              return
          else:
            break

    if not empty(webagent):
      f = http2var(webcommand)
    else:
      f = http2var(webcommand)
    if len(f) < 10:                                            
      sleep(2)
    else:
      break

#
# getwikisource - download plain wikisource. Use wget for networking
#    
# . default: follows "#redirect [[new name]]" at en.wikipedia.org
# . optional: redir = "follow/dontfollow"              
# . optional: hostname = "en" or "commons" etc
# . optional: domain = "wikipedia.org" or "wikimedia.org" etc
# . optional: logfile = full path/filename of logfile for errors (unable to retrieve wikitext)
#
# . Returns a tuple. If result[0] = "REDIRECT" then r[1] is the redirect location. Otherwise r[0] is the article wikisource

proc getwikisource2*(namewiki,redir,domain,hostname,logfile: string): tuple[m: string, z:string] =

  var
    namewiki = namewiki
    webcommand, f, r = ""
    # wget = "timeout 5m wget --no-cookies --ignore-length --no-check-certificate --tries=3 --timeout=60 --waitretry=6 --retry-connrefused -q -O- "
    # curl = "timeout 30s curl -L -s -k "
    webagent = "wget"  # set to wget or curl or blank if http2nim()

  result[0] = ""
  result[1] = ""

  webcommand = "https://" & hostname & "." & domain & "/w/index.php?title=" & uri.encodeUrl(strip(namewiki)) & "&action=raw"
  getwikisource_helper()

  if f ~ "(?i)[#][ ]*redirect[ ]*[[]":
    awk.match(f, "(?i)[#][ ]*redir[^]]*[]]", r)
    if redir ~ "dontfollow":
      result[0] = "REDIRECT"
      result[1] = r
      return

    gsub("(?i)[#][ ]*redir[^[]*[[]", "", r)
    namewiki = strip(awk.substr(r, 1, len(r) - 2))
    webcommand = "https://" & hostname & "." & domain & "/w/index.php?title=" & uri.encodeUrl(namewiki) & "&action=raw"
    getwikisource_helper()

    if f ~ "(?i)[#][ ]*redirect[ ]*[[]":
      awk.match(f, "(?i)[#][ ]*redir[^]]*[]]", r)
      if redir ~ "dontfollow":
        result[0] = "REDIRECT"
        result[1] = r
        return

  if empty(f):
    if not empty(logfile):
      sendlog(logfile, namewiki, "Unable to retrieve wikitext in getwikisource(4)")
    return

  result[0] = strip(f)
  result[1] = ""


# _______________________________________________________________________ Program
#                                                                         

#
# Process each page. It will create files for each book.db.aa, journal.db.aa etc..
#
proc runbot() =

  var 
    c = 0
    f: File
    j: JsonNode
    field = newSeq[string](0)
    ap, fn, re, article, r0, r1, cite = ""

    debug = false
    
  "1" >* CL.lockfile

  if open(f, CL.db):
    while f.readLine(article):
      if not empty(article):
        (r0, r1) = getwikisource2(article, "dontfollow", CL.domain, CL.lang, GX.logfile)
        if debug: echo "Article length = " & $len(r0) 
        if not empty(r0) and r0 != "REDIRECT":
          ap = encodeWik(r0)
          for k in GX.targets:
            fn = GX.db & GX.key & "." & k & ".db." & GX.subdb
            re = targets[k]
            c = patsplit(ap, field, re)  # magic the
            if debug: echo "C = " & $c
            for i in 0..c-1:
              cite = decodeWik(field[i])
              if countsubstring(cite, "{{") != countsubstring(cite, "}}") or cite ~ "DefNonOrdCiteAa":
                # log here if you want. Garbage and some rare difficult edge cases skipped
                sendlog(GX.logfile, article, cite)
                continue
              j = %*
                {
                  "a": article,
                  "c": cite
                }
              $j >> fn
    close(f)

proc main() =

  # Load regex localizations from trans.awk
  # awk2nim.awk -> targets["books"] = "(?i){{cite book|citebook|...}}"
  let c = awk.split(CL.target, a, "[+]")
  if c > 0:
    for i in 0..c-1:
      targets[a[i]] =  strip(runshellBasic(Exe.awk2nim & " -d " & CL.domain & " -l " & CL.lang & " -s " & shquote(a[i]) ))
  else:
    targets[CL.target] = strip(runshellBasic(Exe.awk2nim & " -d " & CL.domain & " -l " & CL.lang & " -s " & shquote(CL.target) ))

  # Generate seq GX.targets["book", "journal"]
  for k in targets.keys:
    if not empty(targets[k]):
      add(GX.targets, k)

  # If respawned by the grid, clobber old data and start over
  if fileExists(CL.lockfile):
    for a in GX.targets:
      let fn = GX.db & GX.key & "." & a & ".db." & GX.subdb
      removeFile(fn)
    removeFile(CL.lockfile)
    stdErr("Error: Toolforge restarting runbot " & GX.db & " at " & todaysdateymd() )

  runbot()

  removeFile(CL.lockfile)

main()
