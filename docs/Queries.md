## Auxiliaries
```SQL
CREATE VIEW IF NOT EXISTS AUX_conversation AS 
SELECT
	chat._id AS id,
	chat.hidden AS is_hidden,
	jid._id AS recipient_jid_row_id,
	jid.raw_string AS recipient_jid,
	COALESCE(chat.subject, jid.user) AS displayed_name,
	jid.type AS is_group
FROM
	chat JOIN jid ON chat.jid_row_id = jid._id
WHERE jid.type = 0 OR jid.type = 1; -- discarding values of unknown meaning 

CREATE TABLE IF NOT EXISTS AUX_message_type (
	id INTEGER PRIMARY KEY,
	meaning TEXT NOT NULL
);
INSERT OR IGNORE INTO AUX_message_type (id, meaning) VALUES (0, 'text');
INSERT OR IGNORE INTO AUX_message_type (id, meaning) VALUES (1, 'img');
INSERT OR IGNORE INTO AUX_message_type (id, meaning) VALUES (2, 'audio_or_voice_note');
INSERT OR IGNORE INTO AUX_message_type (id, meaning) VALUES (3, 'video');
INSERT OR IGNORE INTO AUX_message_type (id, meaning) VALUES (4, 'contact');
INSERT OR IGNORE INTO AUX_message_type (id, meaning) VALUES (5, 'location_static');
INSERT OR IGNORE INTO AUX_message_type (id, meaning) VALUES (7, 'system_message');
INSERT OR IGNORE INTO AUX_message_type (id, meaning) VALUES (9, 'document');
INSERT OR IGNORE INTO AUX_message_type (id, meaning) VALUES (13, 'gif');
INSERT OR IGNORE INTO AUX_message_type (id, meaning) VALUES (14, 'more_than_one_contact');
INSERT OR IGNORE INTO AUX_message_type (id, meaning) VALUES (15, 'voice_note'); -- duplicate?
INSERT OR IGNORE INTO AUX_message_type (id, meaning) VALUES (20, 'sticker');
INSERT OR IGNORE INTO AUX_message_type (id, meaning) VALUES (42, 'view_once_image');
INSERT OR IGNORE INTO AUX_message_type (id, meaning) VALUES (43, 'view_once_video');
INSERT OR IGNORE INTO AUX_message_type (id, meaning) VALUES (66, 'poll');
INSERT OR IGNORE INTO AUX_message_type (id, meaning) VALUES (90, '1to1_voice_call');

CREATE TABLE IF NOT EXISTS AUX_message_status (
	id INTEGER PRIMARY KEY,
	meaning TEXT NOT NULL
);
INSERT OR IGNORE INTO AUX_message_status (id, meaning) VALUES (0, 'sent_by_them');
INSERT OR IGNORE INTO AUX_message_status (id, meaning) VALUES (13, 'read');
INSERT OR IGNORE INTO AUX_message_status (id, meaning) VALUES (5, 'received');
INSERT OR IGNORE INTO AUX_message_status (id, meaning) VALUES (4, 'sent');
INSERT OR IGNORE INTO AUX_message_status (id, meaning) VALUES (8, 'played');

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

## User messages

Parameters: `chat_name`.

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
WHERE chat_info.displayed_name = <chat_name>;
```

## System messages

Parameters: `chat_name`.

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
	chat_info.displayed_name = <chat_name>;
```