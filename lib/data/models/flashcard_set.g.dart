// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flashcard_set.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FlashcardSetAdapter extends TypeAdapter<FlashcardSet> {
  @override
  final int typeId = 1;

  @override
  FlashcardSet read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FlashcardSet(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String?,
      cards: (fields[3] as List).cast<Flashcard>(),
      createdAt: fields[4] as DateTime,
      updatedAt: fields[5] as DateTime,
      folderId: fields[6] as String?,
      termLanguage: fields[7] as String?,
      definitionLanguage: fields[8] as String?,
      cardsKnown: fields[9] as int,
      cardsLearning: fields[10] as int,
      lastStudied: fields[11] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, FlashcardSet obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.cards)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.updatedAt)
      ..writeByte(6)
      ..write(obj.folderId)
      ..writeByte(7)
      ..write(obj.termLanguage)
      ..writeByte(8)
      ..write(obj.definitionLanguage)
      ..writeByte(9)
      ..write(obj.cardsKnown)
      ..writeByte(10)
      ..write(obj.cardsLearning)
      ..writeByte(11)
      ..write(obj.lastStudied);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlashcardSetAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
