The `message` table contains all messages that have been received or sent, to every possible chat, including messages that originated from WhatsApp systems ("you blocked this contact" or "John Doe entered the group using the invite link" kind of messages).
Messages can be textual but they can also be any kind of media messages, so we need to be able to correctly distinguish them. Then we could, for example, query messages *from a particular conversation*.
## Key tables and relations

![Pasted image 20241001013122.png](img/Pasted%20image%2020241001013122.png){: .center}

- `message`: this table contains all the data about a message you would think of; the ID of its sender, the ID of the conversation into which the message was exchanged, its type (text, image, video, voice note etc.), its read status (has it been read from the other party, just delivered to them, or just delivered *to the server*), if it is a *starred* message, the timestamps of when it was sent and when it was delivered.
	- important columns for this query: `_id`, `chat_row_id`, `from_me`, `sender_jid_row_id`, `timestamp`, `message_type`, `status`, `text_data`
- `AUX_conversation` view we defined in [Chats and Groups](Chats%20and%20Groups.md)
- `jid` table we already used in [Chats and Groups](Chats%20and%20Groups.md)
	- important columns for this query: `_id`, `user`, `raw_string`
### Auxiliary tables
Since the `message_type` attribute of `message` table is an integer and we do not have meaningful information in the database about the association between each integer and its meaning as message type, I had to rely on my personal backups and check for known occurrences of messages of specific types in my chat history. 
I've done a similar process for other tables as well. These kind of work has really been the central (and most time consuming) part of this reverse-engineering adventure. 

I ended up with enough (probably not all) associations. I think it's better to create a table out of these, as it will simplify future queries:

```SQL
CREATE TABLE AUX_message_type (
	id INTEGER PRIMARY KEY,
	meaning TEXT NOT NULL
);
INSERT INTO AUX_message_type (id, meaning) VALUES (0, 'text');
INSERT INTO AUX_message_type (id, meaning) VALUES (1, 'img');
INSERT INTO AUX_message_type (id, meaning) VALUES (2, 'audio_or_voice_note');
INSERT INTO AUX_message_type (id, meaning) VALUES (3, 'video');
INSERT INTO AUX_message_type (id, meaning) VALUES (4, 'contact');
INSERT INTO AUX_message_type (id, meaning) VALUES (5, 'location_static');
INSERT INTO AUX_message_type (id, meaning) VALUES (7, 'system_message');
INSERT INTO AUX_message_type (id, meaning) VALUES (9, 'document');
INSERT INTO AUX_message_type (id, meaning) VALUES (13, 'gif');
INSERT INTO AUX_message_type (id, meaning) VALUES (14, 'more_than_one_contact');
INSERT INTO AUX_message_type (id, meaning) VALUES (15, 'voice_note'); -- duplicate?
INSERT INTO AUX_message_type (id, meaning) VALUES (20, 'sticker');
INSERT INTO AUX_message_type (id, meaning) VALUES (42, 'view_once_image');
INSERT INTO AUX_message_type (id, meaning) VALUES (43, 'view_once_video');
INSERT INTO AUX_message_type (id, meaning) VALUES (66, 'poll');
INSERT INTO AUX_message_type (id, meaning) VALUES (90, '1to1_voice_call');
```

Same thing applies for the `status` column:

```sql
CREATE TABLE AUX_message_status (
	id INTEGER PRIMARY KEY,
	meaning TEXT NOT NULL
);
INSERT INTO AUX_message_status (id, meaning) VALUES (0, 'sent_by_them');
INSERT INTO AUX_message_status (id, meaning) VALUES (13, 'read');
INSERT INTO AUX_message_status (id, meaning) VALUES (5, 'received');
INSERT INTO AUX_message_status (id, meaning) VALUES (4, 'sent');
INSERT INTO AUX_message_status (id, meaning) VALUES (8, 'played');
```

----
## Query
```SQL
SELECT 
	message._id AS id,
	sender_jid.raw_string AS sender_jid,
	sender_jid.user AS sender_phone,
	message.timestamp AS sent_timestamp,
	message.text_data AS text_contents,
	COALESCE(
		mstatus.meaning, 
		"unknown: " || cast(message.status AS text)
	) AS status, 
	COALESCE(
		mtype.meaning, 
		"unknown: " || cast(message.message_type AS text)
	) AS type,
	message.from_me AS is_from_me
FROM 
	message
	JOIN AUX_conversation chat_info
		ON message.chat_row_id = chat_info.id
	JOIN jid sender_jid
		ON message.sender_jid_row_id = sender_jid._id
	LEFT OUTER JOIN AUX_message_type mtype
		ON message.message_type = mtype.id -- left outer to account for unknowns
	LEFT OUTER JOIN AUX_message_status mstatus
		ON message.status = mstatus.id -- left outer to account for unknowns
WHERE chat_info.displayed_name = <name>;
```

----

Now that we understood how to get messages from a certain conversation, we are so interested in getting information about the [attachments](Media%20attachments.md) that the messages may have.