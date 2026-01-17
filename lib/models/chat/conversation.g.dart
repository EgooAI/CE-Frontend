// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ConversationAdapter extends TypeAdapter<Conversation> {
  @override
  final int typeId = 4;

  @override
  Conversation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Conversation(
      id: fields[0] as String,
      title: fields[1] as String,
      summary: fields[2] as String?,
      isActive: fields[3] as bool,
      isPinned: fields[4] as bool,
      messageCount: fields[5] as int,
      lastMessageAt: fields[6] as DateTime?,
      createdAt: fields[7] as DateTime,
      updatedAt: fields[8] as DateTime,
      messages: (fields[9] as List?)?.cast<Message>(),
    );
  }

  @override
  void write(BinaryWriter writer, Conversation obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.summary)
      ..writeByte(3)
      ..write(obj.isActive)
      ..writeByte(4)
      ..write(obj.isPinned)
      ..writeByte(5)
      ..write(obj.messageCount)
      ..writeByte(6)
      ..write(obj.lastMessageAt)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt)
      ..writeByte(9)
      ..write(obj.messages);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConversationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MessageAdapter extends TypeAdapter<Message> {
  @override
  final int typeId = 7;

  @override
  Message read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Message(
      id: fields[0] as String,
      role: fields[1] as String,
      content: fields[2] as String,
      attachments: fields[3] as String?,
      metadata: fields[4] as String?,
      conversationId: fields[5] as String,
      createdAt: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Message obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.role)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.attachments)
      ..writeByte(4)
      ..write(obj.metadata)
      ..writeByte(5)
      ..write(obj.conversationId)
      ..writeByte(6)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
