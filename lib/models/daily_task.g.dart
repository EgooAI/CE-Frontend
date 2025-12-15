// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_task.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DailyTaskAdapter extends TypeAdapter<DailyTask> {
  @override
  final int typeId = 1;

  @override
  DailyTask read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyTask(
      id: fields[0] as String,
      userId: fields[1] as String,
      title: fields[2] as String,
      description: fields[3] as String?,
      startTime: fields[4] as DateTime?,
      status: fields[5] as String,
      category: fields[6] as String?,
      color: fields[7] as String?,
      createdAt: fields[8] as DateTime?,
      updatedAt: fields[9] as DateTime?,
      todayCompleted: fields[10] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, DailyTask obj) {
    writer
      ..writeByte(11)
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
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.category)
      ..writeByte(7)
      ..write(obj.color)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.updatedAt)
      ..writeByte(10)
      ..write(obj.todayCompleted);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyTaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DailyTaskLogAdapter extends TypeAdapter<DailyTaskLog> {
  @override
  final int typeId = 5;

  @override
  DailyTaskLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyTaskLog(
      id: fields[0] as String,
      taskId: fields[1] as String,
      userId: fields[2] as String,
      date: fields[3] as DateTime,
      completed: fields[4] as bool,
      note: fields[5] as String?,
      createdAt: fields[6] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, DailyTaskLog obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.taskId)
      ..writeByte(2)
      ..write(obj.userId)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.completed)
      ..writeByte(5)
      ..write(obj.note)
      ..writeByte(6)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyTaskLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DailyTaskStatsAdapter extends TypeAdapter<DailyTaskStats> {
  @override
  final int typeId = 6;

  @override
  DailyTaskStats read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyTaskStats(
      taskId: fields[0] as String,
      title: fields[1] as String,
      monthTotal: fields[2] as int,
      monthCompleted: fields[3] as int,
      completionRate: fields[4] as int,
      consecutiveDays: fields[5] as int,
    );
  }

  @override
  void write(BinaryWriter writer, DailyTaskStats obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.taskId)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.monthTotal)
      ..writeByte(3)
      ..write(obj.monthCompleted)
      ..writeByte(4)
      ..write(obj.completionRate)
      ..writeByte(5)
      ..write(obj.consecutiveDays);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyTaskStatsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
