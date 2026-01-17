// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_task.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SyncTaskAdapter extends TypeAdapter<SyncTask> {
  @override
  final int typeId = 10;

  @override
  SyncTask read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SyncTask(
      id: fields[0] as String,
      resourceType: fields[1] as ResourceType,
      operation: fields[2] as SyncOperation,
      resourceId: fields[3] as String,
      payload: (fields[4] as Map).cast<String, dynamic>(),
      status: fields[5] as SyncStatus,
      priority: fields[6] as int,
      retryCount: fields[7] as int,
      maxRetries: fields[8] as int,
      createdAt: fields[9] as DateTime,
      lastAttemptAt: fields[10] as DateTime?,
      error: fields[11] as String?,
      conflictData: (fields[12] as Map?)?.cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, SyncTask obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.resourceType)
      ..writeByte(2)
      ..write(obj.operation)
      ..writeByte(3)
      ..write(obj.resourceId)
      ..writeByte(4)
      ..write(obj.payload)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.priority)
      ..writeByte(7)
      ..write(obj.retryCount)
      ..writeByte(8)
      ..write(obj.maxRetries)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.lastAttemptAt)
      ..writeByte(11)
      ..write(obj.error)
      ..writeByte(12)
      ..write(obj.conflictData);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncTaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SyncStatusAdapter extends TypeAdapter<SyncStatus> {
  @override
  final int typeId = 11;

  @override
  SyncStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SyncStatus.pending;
      case 1:
        return SyncStatus.syncing;
      case 2:
        return SyncStatus.completed;
      case 3:
        return SyncStatus.failed;
      case 4:
        return SyncStatus.conflict;
      default:
        return SyncStatus.pending;
    }
  }

  @override
  void write(BinaryWriter writer, SyncStatus obj) {
    switch (obj) {
      case SyncStatus.pending:
        writer.writeByte(0);
        break;
      case SyncStatus.syncing:
        writer.writeByte(1);
        break;
      case SyncStatus.completed:
        writer.writeByte(2);
        break;
      case SyncStatus.failed:
        writer.writeByte(3);
        break;
      case SyncStatus.conflict:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SyncOperationAdapter extends TypeAdapter<SyncOperation> {
  @override
  final int typeId = 12;

  @override
  SyncOperation read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SyncOperation.create;
      case 1:
        return SyncOperation.update;
      case 2:
        return SyncOperation.delete;
      default:
        return SyncOperation.create;
    }
  }

  @override
  void write(BinaryWriter writer, SyncOperation obj) {
    switch (obj) {
      case SyncOperation.create:
        writer.writeByte(0);
        break;
      case SyncOperation.update:
        writer.writeByte(1);
        break;
      case SyncOperation.delete:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncOperationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ResourceTypeAdapter extends TypeAdapter<ResourceType> {
  @override
  final int typeId = 13;

  @override
  ResourceType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ResourceType.schedule;
      case 1:
        return ResourceType.dailyTask;
      case 2:
        return ResourceType.conversation;
      default:
        return ResourceType.schedule;
    }
  }

  @override
  void write(BinaryWriter writer, ResourceType obj) {
    switch (obj) {
      case ResourceType.schedule:
        writer.writeByte(0);
        break;
      case ResourceType.dailyTask:
        writer.writeByte(1);
        break;
      case ResourceType.conversation:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResourceTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
