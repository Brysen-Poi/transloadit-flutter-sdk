part of transloadit;

/// Object representation of a new Assembly to be created.
class TransloaditAssembly extends TransloaditOptions {
  /// An instance of the Transloadit class.
  late TransloaditClient client;

  /// Storage of files to be uploaded. Each file is stored with a key corresponding to its field name when it is being uploaded.
  late Map<String, XFile> files;

  /// Params to send along with the assembly. Please see https://transloadit.com/docs/api-docs/#21-create-a-new-assembly for available options.
  Map<String, dynamic>? _options;

  TransloaditAssembly(
      {required TransloaditClient client,
      Map<String, XFile>? files,
      Map<String, dynamic>? options})
      : super(options: options ?? {}) {
    this._options = options ?? {};
    this.client = client;
    this.files = files ?? {};
  }

  /// Add a [file] to be uploaded along with the Assembly.
  void addFile({required File file, String? fieldName}) {
    fieldName = fieldName ?? getFieldName();
    files[fieldName] = XFile(file.path);
  }

  /// Removes a file with the given [fieldName]
  void removeFile({required String fieldName}) {
    files.remove(fieldName);
  }

  /// Removes all files
  void clearFiles() {
    files.clear();
  }

  /// Creates a unique field-name for each file.
  String getFieldName() {
    String name = "file";
    if (!files.containsKey(name)) {
      return name;
    }
    int counter = 1;
    while (files.containsKey("${name}_$counter")) {
      counter++;
    }
    return "${name}_$counter";
  }

  /// Uploads files to the Assembly via the Tus protocol.
  Future<void> tusUpload(String assemblyURL, String tusURL, Duration timeout, {Function(double)? onProgress, Function()? onComplete, Function()? onTimeout}) async {
    Map<String, String> metadata = {"assembly_url": assemblyURL};
    if (files.isNotEmpty) {
      for (var key in files.keys) {
        metadata["fieldname"] = key;
        metadata["filename"] = basename(files[key]?.name ?? '');

        TusClient client = TusClient(
            url: tusURL,
            file:  files[key]!,
            metadata: metadata,
            chunkSize: 200 * 1024,
            cache: TusMemoryCache(),
            timeout: timeout
        );

        client.startUpload(
            onProgress: (int count, int total, http.Response? response) {
              if (onProgress != null) {
                onProgress((count/total * 100));
              }
            },
            onComplete: (http.Response? response) {
              if (onComplete != null) {
                onComplete();
              }
            },
            onTimeout: (){
              if (onTimeout != null) {
                onTimeout();
              }
            }
        );
      }
    }
  }

  /// Creates the Assembly using the options specified.
  /// [onProgress] returns the progress of the file upload
  /// [onComplete] will call when the file is uploaded and the assembly is processing
  Future<TransloaditResponse> createAssembly(Duration timeout, {Function(double)? onProgress, Function()? onComplete, Function()? onTimeout}) async {
    final data = super.options;
    final extraData = {
      "tus_num_expected_upload_files": files.length.toString()
    };

    TransloaditResponse response = await client.request.httpPost(
        service: client.service,
        assemblyPath: "/assemblies",
        params: data,
        extraParams: extraData);

    if (response.data.containsKey("assembly_ssl_url")) {
      await tusUpload(
        response.data["assembly_ssl_url"],
        response.data["tus_url"],
        timeout,
        onTimeout: onTimeout,
        onProgress: onProgress,
        onComplete: onComplete,
      );
    }

    while (!isAssemblyFinished(response)) {
      final url = response.data["assembly_ssl_url"].toString();
      response = await client.getAssembly(assemblyURL: url);
    }

    return response;
  }

  /// Returns whether the assembly has finished, whether successful or not
  bool isAssemblyFinished(TransloaditResponse response) {
    final status = response.data["ok"];
    bool isAborted = status == "REQUEST_ABORTED";
    bool isCancelled = status == "ASSEMBLY_CANCELED";
    bool isCompleted = status == "ASSEMBLY_COMPLETED";
    bool isFailed = response.data["error"] != null;

    if (isFailed) {
      throw Exception(response.data["error"]);
    }

    return isAborted || isCancelled || isCompleted || isFailed;
  }
}
