xCite
===================
by User:GreenC (en.wikipedia.org)

November 2020

MIT License

Info
========
xCite extracts complete corpus of templates from Wikipedia and saves them in dump files.

[Full Documentation](https://tools-static.wmflabs.org/botwikiawk/xcite/doc.html)

Dependencies 
========
* [Nim](https://nim-lang.org/install_unix.html)
* GNU Awk 4.1+
* [BotWikiAwk](https://github.com/greencardamom/BotWikiAwk) (version Jan 2019 +)
* A Toolforge account

Installation
========

1. Install BotWikiAwk following setup instructions. 

2. Install Nim

3. Clone xcite. For example:

	git clone https://github.com/greencardamom/xcite

4. Edit ~/BotWikiAwk/lib/botwiki.awk

	A. Set local URLs in section #1 and #2 

	B. Create a new 'case' entry in section #3, adjust the Home bot path created in step 2:

		case "xcite":                                                # Custom bot paths
			Home = "/data/project/projectname/xcite/"            # path ends in "/"
			Agent = UserPage " (ask me about " BotName ")"
			Engine = 3
			break

	C. Add dependencies statements in dependencies section:

		# xcite.awk
		Exe["gzip"] = "/bin/gzip"
		Exe["gunzip"] = "/bin/gunzip"
		Exe["sort"] = "/usr/bin/sort"
		Exe["uniq"] = "/usr/bin/uniq"
		Exe["comm"] = "/usr/bin/comm"
		Exe["wc"] = "/usr/bin/wc"
		Exe["split"] = "/usr/bin/split"

5. Configure paths and any other hard coded strings:

	In BEGIN{} section of xcite.awk
	In BEGIN{} section of makehtml.awk
	In "globals" section of runbot.nim

6. Copy doc.html to the www directory defined in step 5

6. Compile runbot.nim

	./l  (fast compile during development)
	./lx (for release version)

Running
========

1. Test run

	A. Example for enwiki
		/usr/bin/jsub -once -continuous -quiet -N xcite-enwiki -l mem_free=100M,h_vmem=100M -e /data/project/botwikiawk/xcite/stdioer/enwiki.stderr -o /data/project/botwikiawk/xcite/stdioer/enwiki.stdout -v "AWKPATH=.:/data/project/botwikiawk/BotWikiAwk/lib" -v "PATH=/sbin:/bin:/usr/sbin:/usr/local/bin:/usr/bin:/data/project/botwikiawk/BotWikiAwk/bin" -wd /data/project/botwikiawk/xcite /data/project/botwikiawk/xcite/xcite.awk -l en -d wikipedia.org

	B. Example for trwiki
		/usr/bin/jsub -once -continuous -quiet -N xcite-trwiki -l mem_free=100M,h_vmem=100M -e /data/project/botwikiawk/xcite/stdioer/trwiki.stderr -o /data/project/botwikiawk/xcite/stdioer/trwiki.stdout -v "AWKPATH=.:/data/project/botwikiawk/BotWikiAwk/lib" -v "PATH=/sbin:/bin:/usr/sbin:/usr/local/bin:/usr/bin:/data/project/botwikiawk/BotWikiAwk/bin" -wd /data/project/botwikiawk/xcite /data/project/botwikiawk/xcite/xcite.awk -l tr -d wikipedia.org

	Monitor if any problems in ~/log and ~/stdiorer .. watch db's being built in ~/db

2. Add jsub commands to cron

	For planning purposes, Enwiki will take 8-12hrs with 6 slots allocated (Toolforge allows up to 15 slots concurrent by default). Trwiki takes under an hour with 6 slots.

3. Add makehtml.awk to cron