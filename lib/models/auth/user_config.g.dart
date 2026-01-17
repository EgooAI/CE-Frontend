// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_config.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserConfigAdapter extends TypeAdapter<UserConfig> {
  @override
  final int typeId = 3;

  @override
  UserConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserConfig(
      dailyScheduleDisplayInCalendar: fields[0] as bool,
      use24HourFormat: fields[1] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, UserConfig obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.dailyScheduleDisplayInCalendar)
      ..writeByte(1)
      ..write(obj.use24HourFormat);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserConfigAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
