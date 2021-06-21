part of transloadit;

/// Abstract class representation of options included in Assembly/Template.
class Options {
  /// An instance of the Transloadit class.
  late TransloaditClient client;

  /// Storage of files to be uploaded. Each file is stored with a key corresponding to its field name when it is being uploaded.
  late Map<String, XFile> files;

  /// Params to send along with the assembly. Please see https://transloadit.com/docs/api-docs/#21-create-a-new-assembly for available options.
  Map<String, dynamic>? _options;

  /// Temporary storage of steps, later converted to options.
  late Map<String, dynamic> steps;

  Options({Map<String, dynamic>? options}) {
    options = options ?? {};
    steps = {};
  }

  /// Adds a step to the Assembly/Template
  void addStep(String name, String robot, Map<String, dynamic> options) {
    options["robot"] = robot;
    steps[name] = options;
  }

  /// Removes a step from the Assembly/Template
  void removeStep(String name) {
    steps.remove(name);
  }

  /// Returns the Assembly/Template options in a Transloadit-ready format.
  Map<String, dynamic> get options {
    final _optionsCopy = _options ?? {};
    _optionsCopy["steps"] = steps;
    return _optionsCopy;
  }
}