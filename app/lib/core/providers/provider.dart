import '../capabilities/capability.dart';

abstract class Provider {
  String get id;
  String get name;
  bool get available;

  Set<CapabilityType> get capabilities;
  HardwareRequirements get hardwareRequirements;
}
