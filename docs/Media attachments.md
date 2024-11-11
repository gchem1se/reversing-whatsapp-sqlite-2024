Let's recall where the media files get saved in our device and how the directories are structured:

```
(user data folder)
|
+--- WhatsApp
	 |
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

Each media attachment gets saved in a particular directory according to its *type*, but these directories do not identify the chat the attachment was sent to. Moreover, medias have filenames like `IMG-20210806-WA0001.jpeg` - so filenames contain the date they were sent, but no information about who sent them and to which conversation.

That means we cannot directly recover the association between a media file and its sender, or even between a media file and the conversation it was sent to, just by looking at the filename or into its metadata. Luckily, this piece of information can be recovered easily from the `msgstore`.

`message_media` is the key table for getting further information on attachments, especially in the case of *media* (images, videos, GIFs, voice notes and so on). The same table contains also files shared "as documents", so any kind of file you can share in a WhatsApp conversation.
##### Other kinds of attachments
As you probably know, WhatsApp also supports some attachments that are not really connected to sharing physical files. You can, for example, share a static location or a dynamic location, or share a phone number as a "contact attachment".
These can actually be considered "special types of messages". Data about them can be found in the `message` table itself o sometimes contained in specialized tables, like `message_location`. Polls are another special kind of message. 
All of these have to be discussed separately. As an example, refer to [Locations](Locations.md). 
## Key tables and relations
- `message_media`: this table contains information about media attachments, like voice notes, images, videos etc. This table also contains data about the files themselves, like their MIME type and size (in bytes). The most crucial information for us, however, is just the file path, which enables us to associate the file as we pulled from our device.
- `message`, to get information about special kinds of messages, like 
- `AUX_message_type` could come in handy.
----

{: .center}
## Query
```SQL
```

----

We have now covered most of what we need to read WhatsApp's SQLite database and extract our chat history, but there are a few more things we can discuss about, like messages you didn't receive from your peers, but from [WhatsApp's system itself](System%20messages.md).