PRAGMA journal_mode = WAL;

-- MonkeyButler Versioning

CREATE TABLE schema_migrations (
  version INTEGER UNIQUE NOT NULL
);

INSERT INTO schema_migrations(version) VALUES (1402070000);

-- Streams & Events

CREATE TABLE streams (
  database_identifier INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  stream_id BLOB UNIQUE,
  latest_sequence INTEGER NOT NULL DEFAULT 0,
  client_sequence INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE stream_members (
  stream_database_identifier INTEGER NOT NULL,
  member_id BLOB NOT NULL,
  PRIMARY KEY(stream_database_identifier, member_id),
  FOREIGN KEY(stream_database_identifier) REFERENCES streams(database_identifier) ON DELETE CASCADE
);

CREATE TABLE events (
  database_identifier INTEGER PRIMARY KEY AUTOINCREMENT,
  TYPE INTEGER NOT NULL,
  ttl INTEGER,
  creator_id BLOB,
  server_sequence INTEGER,
  server_timestamp INTEGER,
  preceeding_server_sequence INTEGER,
  client_sequence INTEGER NOT NULL,
  subtype INTEGER,
  external_content_id BLOB,
  member_id BLOB,
  message_event_server_sequence INTEGER,
  stream_database_identifier INTEGER NOT NULL,
  UNIQUE(stream_database_identifier, server_sequence),
  FOREIGN KEY(stream_database_identifier) REFERENCES streams(database_identifier) ON DELETE CASCADE
);

CREATE TABLE event_metadata (
  event_database_identifier INTEGER NOT NULL,
  KEY TEXT NOT NULL,
  VALUE BLOB NOT NULL,
  FOREIGN KEY(event_database_identifier) REFERENCES events(database_identifier) ON DELETE CASCADE,
  PRIMARY KEY(event_database_identifier, KEY)
);

CREATE TABLE event_content_parts (
  event_content_part_id INTEGER NOT NULL,
  event_database_identifier INTEGER NOT NULL,
  TYPE TEXT NOT NULL,
  VALUE BLOB,
  FOREIGN KEY(event_database_identifier) REFERENCES events(database_identifier) ON DELETE CASCADE,
  PRIMARY KEY(event_content_part_id, event_database_identifier)
);

CREATE TABLE unprocessed_events (
  database_identifier INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  event_database_identifier INTEGER NOT NULL UNIQUE,
  created_at DATETIME NOT NULL,
  FOREIGN KEY(event_database_identifier) REFERENCES events(database_identifier) ON DELETE CASCADE
);

CREATE TRIGGER queue_events_for_processing AFTER INSERT ON events
WHEN NEW.server_sequence IS NOT NULL
BEGIN
    INSERT INTO unprocessed_events(event_database_identifier, created_at) VALUES(NEW.database_identifier, datetime('now'));
END;

-- Conversations & Messages

CREATE TABLE conversations (
  database_identifier INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  stream_database_identifier INTEGER UNIQUE,
  FOREIGN KEY(stream_database_identifier) REFERENCES streams(database_identifier) ON DELETE CASCADE
);

CREATE TABLE conversation_participants (
  database_identifier INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  conversation_database_identifier INTEGER NOT NULL,
  stream_member_database_identifier INTEGER,
  member_id BLOB NOT NULL,
  created_at DATETIME NOT NULL,
  deleted_at DATETIME,
  seq INTEGER,
  event_database_identifier INTEGER UNIQUE,
  UNIQUE(conversation_database_identifier, member_id),
  FOREIGN KEY(conversation_database_identifier) REFERENCES conversations(database_identifier) ON DELETE CASCADE,
  FOREIGN KEY(event_database_identifier) REFERENCES events(database_identifier) ON DELETE CASCADE
);

CREATE TABLE messages (
  database_identifier INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  sent_at DATETIME,
  created_at DATETIME NOT NULL,
  deleted_at DATETIME,
  received_at DATETIME,
  user_id BLOB NOT NULL,
  seq INTEGER,
  conversation_database_identifier INTEGER NOT NULL,
  event_database_identifier INTEGER UNIQUE,
  UNIQUE(conversation_database_identifier, seq),
  FOREIGN KEY(conversation_database_identifier) REFERENCES conversations(database_identifier) ON DELETE CASCADE,
  FOREIGN KEY(event_database_identifier) REFERENCES events(database_identifier) ON DELETE CASCADE
);

-- provides ordering. message ids are stored in here in order

CREATE TABLE message_index (
  conversation_database_identifier INTEGER NOT NULL,
  message_database_identifier INTEGER UNIQUE NOT NULL,
  FOREIGN KEY(message_database_identifier) REFERENCES messages(database_identifier) ON DELETE CASCADE
)

CREATE TABLE message_parts (
  database_identifier INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  message_database_identifier INTEGER NOT NULL,
  mime_type STRING NOT NULL,
  content BLOB,
  url STRING,
  FOREIGN KEY(message_database_identifier) REFERENCES messages(database_identifier) ON DELETE CASCADE
);

-- key_type: 0 for user info, 1 for metadata

CREATE TABLE keyed_values (
  database_identifier INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  object_type STRING NOT NULL,
  object_id INTEGER NOT NULL,
  key_type INTEGER NOT NULL,
  KEY STRING NOT NULL,
  VALUE BLOB NOT NULL,
  deleted_at DATETIME,
  seq INTEGER
);

CREATE TABLE message_recipient_status (
  database_identifier INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  message_database_identifier INTEGER NOT NULL,
  user_id STRING NOT NULL,
  STATUS INTEGER NOT NULL,
  seq INTEGER,
  FOREIGN KEY(message_database_identifier) REFERENCES messages(database_identifier) ON DELETE CASCADE
);

-- Valid change types enum: INSERT=0, UPDATE=1, DELETE=2

CREATE TABLE syncable_changes (
  change_identifier INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  TABLE_NAME TEXT NOT NULL,
  row_identifier INTEGER NOT NULL,
  change_type INTEGER NOT NULL,
  column_name TEXT
);

-- Conversation Triggers
--   Note: WHEN clauses differentiate between incoming and outgoing changes
--         by ensuring NEW.stream_database_identifier (or seq, etc.) is NULL

CREATE TRIGGER track_inserts_of_conversations AFTER INSERT ON conversations
WHEN NEW.stream_database_identifier IS NULL
BEGIN
    INSERT INTO syncable_changes(TABLE_NAME, row_identifier, change_type, column_name) VALUES ('conversations', NEW.database_identifier, 0, NULL);
END;

-- Conversation Participants Triggers

CREATE TRIGGER track_inserts_of_conversation_participants AFTER INSERT ON conversation_participants
WHEN NEW.stream_member_database_identifier IS NULL
BEGIN
    INSERT INTO syncable_changes(TABLE_NAME, row_identifier, change_type, column_name) VALUES ('conversation_participants', NEW.database_identifier, 0, NULL);
END;

CREATE TRIGGER track_deletes_of_conversation_participants AFTER UPDATE OF deleted_at ON conversation_participants
WHEN NEW.seq IS NULL AND ((NEW.deleted_at NOT NULL AND OLD.deleted_at IS NULL) OR (NEW.deleted_at IS NULL AND OLD.deleted_at NOT NULL) OR (NEW.deleted_at != OLD.deleted_at))
BEGIN
    INSERT INTO syncable_changes(TABLE_NAME, row_identifier, change_type, column_name) VALUES ('conversation_participants', NEW.database_identifier, 2, NULL);
END;

-- Messages Triggers

CREATE TRIGGER track_inserts_of_messages AFTER INSERT ON messages
WHEN NEW.seq IS NULL
BEGIN
    INSERT INTO syncable_changes(TABLE_NAME, row_identifier, change_type, column_name) VALUES ('messages', NEW.database_identifier, 0, NULL);
END;

CREATE TRIGGER track_deletes_of_messages AFTER UPDATE OF deleted_at ON messages
WHEN NEW.seq IS NULL AND ((NEW.deleted_at NOT NULL AND OLD.deleted_at IS NULL) OR (NEW.deleted_at IS NULL AND OLD.deleted_at NOT NULL) OR (NEW.deleted_at != OLD.deleted_at))
BEGIN
    INSERT INTO syncable_changes(TABLE_NAME, row_identifier, change_type, column_name) VALUES ('messages', NEW.database_identifier, 2, NULL);
END;

CREATE TRIGGER track_inserts_of_keyed_values AFTER INSERT ON keyed_values
WHEN NEW.seq IS NULL
BEGIN
    INSERT INTO syncable_changes(TABLE_NAME, row_identifier, change_type, column_name) VALUES ('keyed_values', NEW.database_identifier, 0, NULL);
END;

-- Keyed Value Triggers

CREATE TRIGGER track_updates_of_keyed_values AFTER UPDATE OF VALUE ON keyed_values
WHEN ((NEW.VALUE NOT NULL AND OLD.VALUE IS NULL) OR (NEW.VALUE IS NULL AND OLD.VALUE NOT NULL) OR (NEW.VALUE != OLD.VALUE))
BEGIN
    INSERT INTO syncable_changes(TABLE_NAME, row_identifier, change_type, column_name) VALUES ('value', NEW.database_identifier, 1, NULL);
END;

CREATE TRIGGER track_deletes_of_keyed_values AFTER UPDATE OF deleted_at ON keyed_values
WHEN ((NEW.deleted_at NOT NULL AND OLD.deleted_at IS NULL) OR (NEW.deleted_at IS NULL AND OLD.deleted_at NOT NULL) OR (NEW.deleted_at != OLD.deleted_at))
BEGIN
    INSERT INTO syncable_changes(TABLE_NAME, row_identifier, change_type, column_name) VALUES ('keyed_values', NEW.database_identifier, 2, NULL);
END;
