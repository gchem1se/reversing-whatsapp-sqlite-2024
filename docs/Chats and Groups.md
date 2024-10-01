To proceed to a full recovery process and exploration of messages by analyzing the `msgstore` file, we firstly need to understand how to distinguish between *group chats* and *one-to-one conversations*.
## Key tables and relations
- `chat`: this table contains information about the various conversations you had, both groups and one-to-one chats (even hidden ones). In case of a group, it will also contain the group name (or *subject*), while *it won't directly include the phone number* in case of a single conversation, but it will help us to get that information.
	- important columns for this query: `_id`, `jid_row_id`, `subject`, `hidden`
- `jid`: this table contains a record for each *entity* that can act in a WhatsApp system and associates an identificative string called `jid` to each entity.
	- By *entity* I mean users and groups, but users are further specified by their *device*. In fact, if you change your device (or, I believe, just uninstall and re-install WhatsApp at some point) other people's WhatsApp systems will see you as a different *entity* (maybe because your end-to-end encryption key changes). 
	- important columns for this query: `_id`, `user`, `type`, `raw_string`

> [!NOTE] Additional notes
> - the column of `jid` called `raw_string` is a combination of its other columns and is the identificative string for the entity referenced in that record.
> - each `raw_string` is composed as `<user>.<agent>:<device>@<server>`
> 	- if `device` is `0`, then it's just `<user>@<server>`
> 	- `user` is the phone number in case of a 1-to-1 chat, and it's composed as the `<phone number of the group creator>-<timestamp of group creation>` in the case of a group
> 	- I don't know what `agent` is, but it seems to always have value `0` except for those records that have `server` equal to `lid` (I don't know what these are either, but surely *these are neither users or groups*).
> 	- `server` is equal to `g.us` for groups and to `s.whatsapp.net` for single users, but other values do exist that I still don't know how to use: `broadcast`, `newsletter`, `lid`, `lid_me`, `temp`, `status_me`.
> 	- `device` identifies the current device (I believe it's better to talk about the current *app installation*) of the user
> - `type` in `jid` can have many different values, not contiguous, from `0` to `21`. The only thing I came up with is that `0` means *regular user*, `1` means *group*.
> - the `chat` table only references `jid` records that have `device` equal to `0`

---

![Pasted image 20241001001230.png](img/Pasted%20image%2020241001001230.png){: .center}

## Query 
```SQL
CREATE VIEW AUX_conversation AS 
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
```

---

We can now proceed to recover [messages](Get%20messages%20from%20a%20conversation.md)!
