// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schedule.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ScheduleAdapter extends TypeAdapter<Schedule> {
  @override
  final int typeId = 0;

  @override
  Schedule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Schedule(
      id: fields[0] as String,
      userId: fields[1] as String,
      title: fields[2] as String,
      description: fields[3] as String?,
      startTime: fields[4] as DateTime,
      endTime: fields[5] as DateTime?,
      allDay: fields[6] as bool,
      location: fields[7] as String?,
      status: fields[8] as String,
      type: fields[9] as String?,
      priority: fields[10] as String?,
      recurrence: fields[11] as String?,
      participants: fields[12] as String?,
      notes: fields[13] as String?,
      attachments: fields[14] as String?,
      daomengId: fields[15] as String?,
      remindBefore: fields[16] as int?,
      reminders: (fields[17] as List?)?.cast<dynamic>(),
      parentId: fields[18] as String?,
      iterationIndex: fields[19] as int?,
      createdAt: fields[20] as DateTime?,
      updatedAt: fields[21] as DateTime?,
      isDaily: fields[22] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Schedule obj) {
    writer
      ..writeByte(23)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.startTime)
      ..writeByte(5)
      ..write(obj.endTime)
      ..writeByte(6)
      ..write(obj.allDay)
      ..writeByte(7)
      ..write(obj.location)
      ..writeByte(8)
      ..write(obj.status)
      ..writeByte(9)
      ..write(obj.type)
      ..writeByte(10)
      ..write(obj.priority)
      ..writeByte(11)
      ..write(obj.recurrence)
      ..writeByte(12)
      ..write(obj.participants)
      ..writeByte(13)
      ..write(obj.notes)
      ..writeByte(14)
      ..write(obj.attachments)
      ..writeByte(15)
      ..write(obj.daomengId)
      ..writeByte(16)
      ..write(obj.remindBefore)
      ..writeByte(17)
      ..write(obj.reminders)
      ..writeByte(18)
      ..write(obj.parentId)
      ..writeByte(19)
      ..write(obj.iterationIndex)
      ..writeByte(20)
      ..write(obj.createdAt)
      ..writeByte(21)
      ..write(obj.updatedAt)
      ..writeByte(22)
      ..write(obj.isDaily);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
