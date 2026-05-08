import 'participant_model.dart';

class ManagedParticipantModel {
  const ManagedParticipantModel({
    required this.participant,
    required this.checkedIn,
  });

  final ParticipantModel participant;
  final bool checkedIn;

  factory ManagedParticipantModel.fromJson(Map<String, dynamic> json) {
    return ManagedParticipantModel(
      participant: ParticipantModel.fromJson(
        json['participant'] as Map<String, dynamic>,
      ),
      checkedIn: json['checkedIn'] as bool? ?? false,
    );
  }
}

