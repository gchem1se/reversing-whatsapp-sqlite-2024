> [!warning] In a rush?
>*If you only care about what queries you have to run to extract your data, you can just refer to the [Queries](Queries.md) page, where you will find a bunch of. Also, if you are in such a rush, why not just use [my tool](https://github.com/gchem1se/rechat)?*

## Axioms 
- Since this project only aims to empower the user to recover their own messages and nothing more than that, I will frequently skip analyzing files, directories or SQL tables I don't find to be useful.
- This has been an individual project of mine for a year almost; I am basing this knowledge on different versions of WhatsApp and my own personal understanding of what the developers' choices were. So do expect something to not work as intended, or me openly saying I don't still have a clue of how something works.
- I will not analyze tables nor files that are clearly related to interactions with WhatsApp Business accounts or in-app payments.
- An instance of WhatsApp's application on an Android phone will mainly use two directories as storage for its data, one being protected by being access-restricted to normal system users because of Android's filesystem policies, and the other one fully accessible.
	- From now on we will refer to directory `/sdcard/Android/media/com.whatsapp` as *the user data folder* (fully accessible by any system user) and to directory `/sdcard/Android/data/com.whatsapp` as *the application data folder* (accessible only by privileged users).
- From now on we will rely on the user having the possibility of decrypting its own local files, that is, on the user knowing what his decryption key is. Moreover, I will consider the user to have enabled the *end-to-end encryption* of the backup in WhatsApp's settings menu, that leads to all encrypted files having a `.crypt15` extension. Refer to [How to get your decryption key](How%20to%20get%20your%20decryption%20key.md) for more details on that.
- Most of the files we are going to analyze are SQLite database files. 
	- If you're not familiar with this DBMS or with SQL in general, I highly suggest you to get yourself a background before jumping into this. Moreover, I'll sometimes prefer showing you relations between tables and attributes by means of DBML diagrams instead of writing them down verbosely.
	- To inspect these files and run queries on them I personally used [DB Browser for SQLite](https://sqlitebrowser.org/), although I had all sorts of random crashes trying opening bigger databases from older backups (we're talking millions of messages). I ultimately moved to a VSCode extension called [SQLite Viewer](https://marketplace.visualstudio.com/items?itemName=qwtel.sqlite-viewer) by [Florian Klampfer](https://marketplace.visualstudio.com/publishers/qwtel) that worked much better, even if I had to tweak some setting beforehand. 
## WhatsApp's directory structure on an Android device
Exploring the *user data folder* we are presented with this file structure:

```
WhatsApp
|
+--- Backups/
	 |
	 +--- avatar-password.bkup.crypt15
	 +--- backup_settings.json.crypt15
	 +--- chatsettingsbackup.db.crypt15
	 +--- commerce_backup.db.crypt15
	 +--- stickers.db.crypt15
	 +--- wa.db.crypt15
+--- Databases/
	 |
	 +--- msgstore.db.crypt15
	 +--- msgstore-<date>.db.crypt15
	 +--- msgstore-increment-<incremental number>.db.crypt15
	 +--- msgstore-increment-<incremental number>-<date>.db.crypt15
+--- Media/
	 |
	 +--- WallPaper/
	 +--- WhatsApp Animated Gifs/
	 +--- WhatsApp Audio/
	 +--- WhatsApp Backup Excluded Stickers/
	 +--- WhatsApp Documents/
	 +--- WhatsApp Images/
	 +--- WhatsApp Sticker Packs/
	 +--- WhatsApp Stickers/
	 +--- WhatsApp Video/
	 +--- WhatsApp Video Notes/
	 +--- WhatsApp Voice Notes/
```

Some of these files are particularly useful to us. Let's analyze them:

- Files in the `Databases/` folder that *do not include a date in their filename* are files that got created in occasion of the *lastly occurred triggering* of the backup routine. Each time a new backup is process is launched, older files get renamed automatically to have appended their creation date.
- Messages you exchanged, as well as messages you received from WhatsApp's system (like messages about people joining or leaving groups you are a member of) are stored in `Databases/msgstore-...` files.
	- ==`msgstore.db.cryptXX` is the main file you'd want to download on your PC for inspection. After decryption, it reveals itself to be a SQLite database storing all of your chat history.==
	- even if they have `.db` extension, `-increment-` files are decrypted to `.zip` files, containing several `.json` files (that account for different modifications the database had since last backup was issued), apart from the `messages.bin` file, that actually contains data about messages exchanged in the day. I am not sure on what the encoding of this file is, but some information can be recovered by running `strings` on it.
		- ![Pasted image 20240930200812.png](img/Pasted%20image%2020240930200812.png){: .center}
	- Even if they can surely be of some interest, proceeding with the actual analysis of our data we will discard the `-increment-` files to only work with the `msgstore` file,  which contains the majority of the information we are interested in. Recovering the fragmented information from these files can be hard and lead to minimal additional results. [Launching a backup manually](Launching%20a%20backup%20manually.md) will get you a `msgstore` file containing all the messages you exchanged until that moment anyway.

> [!note] On the creation of `increment` files
> I'm not that sure about when `Databases/msgstore-increment...` are created, since they do not substitute `msgstore` files, which are bigger in size and still gets created every day if you enabled the daily backup routine. 
> - My best guess is that several `-increment-` files are created during periods between the triggering of backup creation routines. 
> 	- For example, having set you backup routine to "Daily", you will find that during the day several of these files pop up in the folder, until the backup routine eventually gets launched (normally at 2:00 AM). 
> 	- When the time comes, information about what happened during the day will probably be reconstructed merging all of these `-increment-` files together and made into a new `msgstore` file, using the one from the previous day as baseline.

- Getting into most of the files that are present in the `Backups/` folder is out of the scope of this project, so let's spend some words only on two of them in particular:
	- `stickers.db.crypt15` does not contain information about the stickers other people sent to you, but about your own sticker packs. 
		- after decryption, it's a `.zip` file containing:
			- `.png` files for your sticker packs cover images, with sticker pack names as filenames
			- `.webp` files with alphanumerical (that seem base64 encoded, but actually decode to gibberish) filenames which are your actual stickers (including animated stickers)
			- a SQLite database named `sticker.db`, containing useful information such as frequently used stickers, starred stickers and the belongings of each file to a specific stickers pack. 
				- Check out [Recovering your sticker packs](Recovering%20your%20sticker%20packs.md) to see what the database contains in more details.
	- `wa.db.crypt15`: this is a file of particular interest to us because it contains information about your *contacts*. In particular, a table contained in this SQLite database contains the associations between the IDs of every user you chatted with their *names, as they are recorded in your phone contacts application*. It also contains their status phrases, some tables about *blocked* contacts, some statistics (like the total count of messages exchanged with that user/group) and so on.
		- However, there's a major problem to that: although this was the case some years ago, from a specific release of WhatsApp on, (we could date this with enough confidence in 2022: check out [this conversation about the issue](https://github.com/KnugiHK/WhatsApp-Chat-Exporter/issues/63#issuecomment-2310816596)) *this file contains all empty tables*, and it seems like these information is not getting a local backup anymore. *The encrypted file gets created anyway, but contents are stripped out beforehand.*
		- We can still recover information about the contacts we chatted with by using the `msgstore` file, along with any other file that links phone numbers with names: for instance, the *CSV export* of your own *Google Contacts* application. Check out [Recovering contacts from wa.db](Recovering%20contacts%20from%20wa.db.md) to know more about that.

----

We will now move on to [the actual analysis of the msgstore file](Chats%20and%20Groups.md), which will get us to the core part of this project: recovering messages and their attachments, and associating them with the conversation they belong to, as well as to the sender.