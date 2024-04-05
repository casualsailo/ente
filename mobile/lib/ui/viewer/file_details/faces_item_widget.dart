import "package:flutter/foundation.dart" show kDebugMode;
import "package:flutter/material.dart";
import "package:logging/logging.dart";
import "package:photos/face/db.dart";
import "package:photos/face/model/face.dart";
import "package:photos/face/model/person.dart";
import "package:photos/models/file/file.dart";
import "package:photos/services/machine_learning/face_ml/feedback/cluster_feedback.dart";
import "package:photos/ui/components/buttons/chip_button_widget.dart";
import "package:photos/ui/components/info_item_widget.dart";
import "package:photos/ui/viewer/file_details/face_widget.dart";

class FacesItemWidget extends StatefulWidget {
  final EnteFile file;
  const FacesItemWidget(this.file, {super.key});

  @override
  State<FacesItemWidget> createState() => _FacesItemWidgetState();
}

class _FacesItemWidgetState extends State<FacesItemWidget> {
  bool editMode = false;

  @override
  void initState() {
    super.initState();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return InfoItemWidget(
      key: const ValueKey("Faces"),
      leadingIcon: Icons.face_retouching_natural_outlined,
      subtitleSection: _faceWidgets(context, widget.file, editMode),
      hasChipButtons: true,
      editOnTap: _toggleEditMode,
    );
  }

  void _toggleEditMode() {
    setState(() {
      editMode = !editMode;
    });
  }

  Future<List<Widget>> _faceWidgets(
    BuildContext context,
    EnteFile file,
    bool editMode,
  ) async {
    try {
      if (file.uploadedFileID == null) {
        return [
          const ChipButtonWidget(
            "File not uploaded yet",
            noChips: true,
          ),
        ];
      }

      final List<Face>? faces = await FaceMLDataDB.instance
          .getFacesForGivenFileID(file.uploadedFileID!);
      if (faces == null) {
        return [
          const ChipButtonWidget(
            "Image not analyzed",
            noChips: true,
          ),
        ];
      }

      // Remove faces with low scores and blurry faces
      if (!kDebugMode) {
        faces.removeWhere((face) => (face.isBlurry || face.score < 0.75));
      }

      if (faces.isEmpty) {
        return [
          const ChipButtonWidget(
            "No faces found",
            noChips: true,
          ),
        ];
      }

      // Sort the faces by score in descending order, so that the highest scoring face is first.
      faces.sort((Face a, Face b) => b.score.compareTo(a.score));

      // TODO: add deduplication of faces of same person
      final faceIdsToClusterIds = await FaceMLDataDB.instance
          .getFaceIdsToClusterIds(faces.map((face) => face.faceID));
      final (clusterIDToPerson, _) =
          await FaceMLDataDB.instance.getClusterIdToPerson();

      final lastViewedClusterID = ClusterFeedbackService.lastViewedClusterID;

      final faceWidgets = <FaceWidget>[];
      for (final Face face in faces) {
        final int? clusterID = faceIdsToClusterIds[face.faceID];
        final Person? person = clusterIDToPerson[clusterID];
        final highlight =
            (clusterID == lastViewedClusterID) && (person == null);
        faceWidgets.add(
          FaceWidget(
            file,
            face,
            clusterID: clusterID,
            person: person,
            highlight: highlight,
            editMode: highlight ? editMode : false,
          ),
        );
      }

      return faceWidgets;
    } catch (e, s) {
      Logger("FacesItemWidget").info(e, s);
      return <FaceWidget>[];
    }
  }
}
