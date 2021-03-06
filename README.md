xCite
===================
by User:GreenC (en.wikipedia.org)

November 2020

MIT License

Info
========
xCite extracts complete corpus of templates from Wikipedia and saves in dump files.

[Web interface](https://tools-static.wmflabs.org/botwikiawk/xcite/xcite.html)

[Documentation](https://tools-static.wmflabs.org/botwikiawk/xcite/doc.html)

Dependencies 
========
* [Nim](https://nim-lang.org/install_unix.html)
* GNU Awk 4.1+
* [BotWikiAwk](https://github.com/greencardamom/BotWikiAwk) (version Jan 2019 +)
* A Toolforge account

Installation
========

1. Create a project on Toolforge and install BotWikiAwk following setup instructions. 

2. Install Nim

3. Clone xcite. For example:

	git clone https://github.com/greencardamom/xcite

4. Edit ~/BotWikiAwk/lib/botwiki.awk

	A. Set local URLs in section #1 and #2 

	B. Create a new 'case' entry in section #3, adjust the Home bot path created in step 3:

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

5. Configure static strings:

		Edit section "_defaults" in xcite.awk and makehtml.awk

6. Copy doc.html to the public www directory defined in step 5

7. Compile runbot.nim

		./c  (fast compile during development)
		./cx (optimized for production)

Running
========

0. Command-line arguments

		-l <lang> The hostname of the Wiki site eg. "en" or "commons"
		-d <domain> The domain name of the Wiki site eg. "wikipedia.org" or "wikimedia.org"
		-h <hours> Number of hours before xcite.awk self-aborts. Set to less than the number of hours in the cron cycle, but long enough to complete a run. It is a safety measure to stop the currently running instance before the next cron starts. For example if cron is on a 48 hour cycle, set to 40 hours which gives you 8 hours to respond to abort email warnings.

1. Test run

	A. Example for enwiki

		/usr/bin/jsub -once -continuous -quiet -N xcite-enwiki -l mem_free=100M,h_vmem=100M -e /data/project/botwikiawk/xcite/stdioer/enwiki.stderr -o /data/project/botwikiawk/xcite/stdioer/enwiki.stdout -v "AWKPATH=.:/data/project/botwikiawk/BotWikiAwk/lib" -v "PATH=/sbin:/bin:/usr/sbin:/usr/local/bin:/usr/bin:/data/project/botwikiawk/BotWikiAwk/bin" -wd /data/project/botwikiawk/xcite /data/project/botwikiawk/xcite/xcite.awk -l en -d wikipedia.org -h 48

	B. Example for trwiki

		/usr/bin/jsub -once -continuous -quiet -N xcite-trwiki -l mem_free=100M,h_vmem=100M -e /data/project/botwikiawk/xcite/stdioer/trwiki.stderr -o /data/project/botwikiawk/xcite/stdioer/trwiki.stdout -v "AWKPATH=.:/data/project/botwikiawk/BotWikiAwk/lib" -v "PATH=/sbin:/bin:/usr/sbin:/usr/local/bin:/usr/bin:/data/project/botwikiawk/BotWikiAwk/bin" -wd /data/project/botwikiawk/xcite /data/project/botwikiawk/xcite/xcite.awk -l tr -d wikipedia.org -h 2

	Monitor if any problems in ~/log and ~/stdiorer .. watch db's being built in ~/db

	When done, run "./makehtml.awk" to generate the HTML page.

2. Add jsub commands to cron

	Example for enwiki once a week at 1am (note custom paths need to be changed)

		00 1 7,14,21,28 * * /usr/bin/jsub -once -continuous -quiet -N xcite-enwiki -l mem_free=100M,h_vmem=100M -e /data/project/botwikiawk/xcite/stdioer/enwiki.stderr -o /data/project/botwikiawk/xcite/stdioer/enwiki.stdout -v "AWKPATH=.:/data/project/botwikiawk/BotWikiAwk/lib" -v "PATH=/sbin:/bin:/usr/sbin:/usr/local/bin:/usr/bin:/data/project/botwikiawk/BotWikiAwk/bin" -wd /data/project/botwikiawk/xcite /data/project/botwikiawk/xcite/xcite.awk -l en -d wikipedia.org -h 48

	For planning purposes, Enwiki takes 12-20 hrs with 6 slots allocated. Trwiki is under 30 minutes with 6 slots.

3. Add makehtml.awk to cron

	Run makehtml.awk after xcite.awk completes; or, on a regular schedule such as once an hour.
