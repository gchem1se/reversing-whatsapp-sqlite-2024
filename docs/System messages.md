System messages are messages that you have not sent or received by any of your peers, but are instead sent to you by WhatsApp's system itself. More often than not these get rendered on the conversation itself, like for messages announcing someone joining or leaving a group, or you blocking a contact.
The (rather annoying) alerts that notify you of the end-to-end encryption of your conversations at the very start of a new chat also fall in this category.

![Pasted image 20241003200709.png](img/Pasted%20image%2020241003200709.png){: .center}

This messages are still stored in the `message` table among all other interactions real users have, but you do find them also referenced in the `message_system` table, where the *type* of that messages gets specified. 
A bunch of additional tables in the database contribute to the complete characterization of these kind of "special" messages.
## Key tables and relations

![Pasted image 20241004024025.png](img/Pasted%20image%2020241004024025.png){: .center}

- `message_system`: a table of just two columns, which builds the relation between each system message and its type, here called *action type*.
	- important columns for this query: `message_row_id`, `action_type`
- `message`: contains all messages, including system's; useful here since some system messages do have text contents and that is stored only here. We know already that system messages have `type = 7` in this table [from our previous analysis](Get%20messages%20from%20a%20conversation.md).
	- we don't need to filter for `type = 7` anyway, we can just user an inner join with `message_system`.
	- important columns for this query: `_id`, `text_data`, `timestamp`, `chat_row_id`
- `jid`: contains a unique string for each entity interacting in your WhatsApp system. We need this table to identify people (or entities) involved in the actions described in the system message (eg. *who* has left the group).
	- important columns for this query: `_id`, `user`
- `message_system_chat_participant`: this table is used for all kind of messages involving a (former) group participant as an actor (eg. someone has left the group, someone has joined it). Only two columns linking the system message to the user.
	- important columns for this query: `message_row_id`, `user_jid_row_id`
- `message_system_number_change`: in the case of a system message announcing that a group participant *has changed its phone number*, this table would link that message to both the old and new *jid* (identifying string, stored in the `jid` table) of that user
	- important columns for this query: `message_row_id`, `old_jid_row_id`, `new_jid_row_id`
- `message_system_block_contact`: links messages announcing that you blocked or unblocked an user to the actual action you took
	- important columns for this query: `message_row_id`, `is_blocked`
- `message_system_value_change`: when someone changes the name/subject of a group, *or* you change the name of a contact of yours, a system message is created in the `messages` table and gets referenced in this table. This table stores the old value of the name that was displayed; `messages` stores the new value for it in its `text_data` column.
	- important columns for this query: `message_row_id`, `old_data`
- `message_system_photo_change`: this table's records actually store plain thumbnails (in JPG format) inside their columns, one for the picture the group used to have as its propic, and one for the newly set one.
	- important columns for this query: `message_row_id`, `old_photo`, `new_photo`
- `message_system_group`: each time someone (yourself included) joins a group (either via an invitation link or because an administrator puts them in) a new system message (respectively, with `action_type` equal to `4` or to `20`) gets created. This table makes it possible to know *if the one who joined was me or not*. It's just two columns.
	- you could think about *not using this table at all* and recover this information (*was it me the one who joined the group or was it someone else?*) from a JOIN between `message_system_group_participant` and `jid`, checking if the jid of the one joining the group is your own. 
		- However, I found out that the `jid` table *does not store your own jid in any different way from any other user's*, so you would have to rely on other JOIN operations to get what your jid is. So it's better to just use the `message_system_group` table.
	- important columns for this query: `message_row_id`, `is_me_joined`
- `message_ephemeral_setting` keeps track of the chat being set as *ephemeral* and of how many seconds the messages will be kept before disappearing. If that field is `0`, the ephemeral setting is been disabled.
	- important columns for this query: `message_row_id`, `setting_duration`
- joining with `AUX_conversation` ([which we created here](Chats%20and%20Groups.md)) lets us filter these messages by chat.

> [!Warning] Other tables
> I am aware that these are not the only tables called `message_system_<something>` and therefore that even more information could technically be extracted. I just don't grasp the meaning of many of them still. Moreover, I find the list above to be quite exhaustive in helping specifying system messages.
### Auxiliary tables
Just as we did for other messages, we can simplify our queries by manually adding a static table to the database, containing only associations between the identifying integers for action types and their actual meaning.
```SQL
CREATE TABLE IF NOT EXISTS AUX_system_action_type (
	id INTEGER PRIMARY KEY,
	meaning TEXT NOT NULL
);

INSERT OR IGNORE INTO AUX_system_action_type(id, meaning) VALUES(1, "group_changed_subject");
INSERT OR IGNORE INTO AUX_system_action_type(id, meaning) VALUES(4, "group_someone_joined");
INSERT OR IGNORE INTO AUX_system_action_type(id, meaning) VALUES(5, "group_someone_left");
INSERT OR IGNORE INTO AUX_system_action_type(id, meaning) VALUES(6, "group_changed_photo");
INSERT OR IGNORE INTO AUX_system_action_type(id, meaning) VALUES(10, "group_someone_changed_number");
INSERT OR IGNORE INTO AUX_system_action_type(id, meaning) VALUES(11, "group_someone_created_group");
INSERT OR IGNORE INTO AUX_system_action_type(id, meaning) VALUES(12, "group_someone_has_been_added");
INSERT OR IGNORE INTO AUX_system_action_type(id, meaning) VALUES(14, "group_someone_has_been_removed");
INSERT OR IGNORE INTO AUX_system_action_type(id, meaning) VALUES(15, "group_you_became_administrator");
INSERT OR IGNORE INTO AUX_system_action_type(id, meaning) VALUES(20, "group_someone_joined_via_invitation");
INSERT OR IGNORE INTO AUX_system_action_type(id, meaning) VALUES(27, "group_changed_description");
INSERT OR IGNORE INTO AUX_system_action_type(id, meaning) VALUES(46, "business_announcement");
INSERT OR IGNORE INTO AUX_system_action_type(id, meaning) VALUES(58, "blocked_contact");
INSERT OR IGNORE INTO AUX_system_action_type(id, meaning) VALUES(59, "ephemeral");
INSERT OR IGNORE INTO AUX_system_action_type(id, meaning) VALUES(67, "cryptography_init");
```

----
## Query

```SQL
SELECT 
	msys.message_row_id AS id,
	COALESCE(
		atype.meaning, 
		"unknown: " || cast(msys.action_type AS text)
	) AS type,	
	message.timestamp AS timestamp,
	message.text_data AS text_contents,
	msys_block.is_blocked AS is_blocked,
	CASE
		WHEN msys_value.old_data IS NOT NULL
		THEN message.text_data
		ELSE NULL
	END AS new_chat_name,
	msys_value.old_data AS old_chat_name,
	msys_group.is_me_joined AS is_me_joined,
	msys_ph.old_photo AS old_chat_propic,
	msys_ph.new_photo AS new_chat_propic,
	old_jid.user AS old_actor_phone,
	new_jid.user AS new_actor_phone,
	participant_jid.user AS actor_phone,
	meph.setting_duration AS ephemeral_duration
FROM 
	message_system msys
	
	JOIN message
		ON msys.message_row_id = message._id
	JOIN AUX_conversation chat_info
		ON chat_info.id = message.chat_row_id
	
	LEFT OUTER JOIN AUX_system_action_type atype -- to account for missing ones
		ON atype.id = msys.action_type
	
	LEFT OUTER JOIN message_system_block_contact msys_block
		ON msys.message_row_id = msys_block.message_row_id	
	
	LEFT OUTER JOIN message_system_value_change msys_value
		ON msys.message_row_id = msys_block.message_row_id	
	
	LEFT OUTER JOIN message_system_group msys_group
		ON msys.message_row_id = msys_group.message_row_id	
	
	LEFT OUTER JOIN message_system_photo_change msys_ph
		ON msys.message_row_id = msys_ph.message_row_id	

	LEFT OUTER JOIN message_system_number_change msys_phone
		ON msys.message_row_id = msys_phone.message_row_id	
	LEFT OUTER JOIN jid old_jid
		ON old_jid._id = msys_phone.old_jid_row_id
	LEFT OUTER JOIN jid new_jid
		ON new_jid._id = msys_phone.new_jid_row_id

	LEFT OUTER JOIN message_system_chat_participant msys_cp
		ON msys.message_row_id = msys_cp.message_row_id
	LEFT OUTER JOIN jid participant_jid
		ON participant_jid._id = msys_cp.user_jid_row_id

	LEFT OUTER JOIN message_ephemeral_setting meph
		ON msys.message_row_id = meph.message_row_id

WHERE 
	chat_info.displayed_name = <name>;
```

----------------

You should now have a full understanding of how things are stored in WhatsApp's SQLite, so you can go run your personal queries or start building your own viewer. [I have created my own, check it out!](https://github.com/gchem1se/rechat)

