// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flashcard.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FlashcardAdapter extends TypeAdapter<Flashcard> {
  @override
  final int typeId = 0;

  @override
  Flashcard read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Flashcard(
      id: fields[0] as String,
      term: fields[1] as String,
      definition: fields[2] as String,
      termLanguage: fields[3] as String?,
      definitionLanguage: fields[4] as String?,
      imageUrl: fields[5] as String?,
      timesCorrect: fields[6] as int,
      timesIncorrect: fields[7] as int,
      lastStudied: fields[8] as DateTime?,
      isStarred: fields[9] as bool,
      easinessFactor: fields[10] as double,
      interval: fields[11] as int,
      repetitions: fields[12] as int,
      nextReviewDate: fields[13] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Flashcard obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.term)
      ..writeByte(2)
      ..write(obj.definition)
      ..writeByte(3)
      ..write(obj.termLanguage)
      ..writeByte(4)
      ..write(obj.definitionLanguage)
      ..writeByte(5)
      ..write(obj.imageUrl)
      ..writeByte(6)
      ..write(obj.timesCorrect)
      ..writeByte(7)
      ..write(obj.timesIncorrect)
      ..writeByte(8)
      ..write(obj.lastStudied)
      ..writeByte(9)
      ..write(obj.isStarred)
      ..writeByte(10)
      ..write(obj.easinessFactor)
      ..writeByte(11)
      ..write(obj.interval)
      ..writeByte(12)
      ..write(obj.repetitions)
      ..writeByte(13)
      ..write(obj.nextReviewDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlashcardAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
